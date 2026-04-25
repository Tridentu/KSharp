%{
 #include <stdio.h>
 #include <stdlib.h>
 #include <string.h>
 #include <iostream>
 #include <fstream>
 #include <set>
 #include <map>
 #include <regex>
 #include "src/KSharpContext.h"
 #include <inja/inja.hpp>
 #include <stdexcept>
 #include <nlohmann/json.hpp>
 std::vector<KSharpClass> fileClasses;
 std::vector<KSharpEnum> fileEnums;
 std::vector<KSharpInterface> fileInterfaces;
 std::set<std::string> ksharp_imports;
 KSharpClass parsedClass;
 int capture_mode = 0;
 void yyerror(const char* s);
 int yylex();
 std::vector<KSharpParameter> temp_params;
 std::string currentNamespaceId;
 std::map<std::string, std::string> symbolTable;
 std::map<std::string, std::string> dynamicTypeMap;
 KSharpProperty currentProp;
 KSharpEnum currentEnum;
 KSharpInterface currentInterface;
 extern std::string projectName;
 std::string outputDir;
 int isStatic_flag = 0;
 int isAbstract_flag = 0;
 int isOverride_flag = 0;
 int isVirtual_flag = 0;
 bool hasEntryPoint = false;
std::set<std::string> ksharp_active_namespaces;

std::string buildLocalDeclPattern() {
    std::string types = "";
    for (const auto& [kType, cppType] : KSharpPrimitives) {
        if (!types.empty()) types += "|";
        types += kType;
    }
    // Add generic collection prefixes
    types += "|List<[^>]+>|Dictionary<[^,>]+,[^>]+>|HashSet<[^>]+>";
    return R"(\b()" + types + R"()\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*=)";
}

std::string buildLocalDeclNoInitPattern() {
    std::string types = "";
    for (const auto& [kType, cppType] : KSharpPrimitives) {
        if (!types.empty()) types += "|";
        types += kType;
    }
    return R"(\b()" + types + R"()\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*;)";
}

// Regex
static const std::regex localDeclRegex(buildLocalDeclPattern());
static const std::regex localDeclNoInitRegex(buildLocalDeclNoInitPattern());
static const std::regex foreachRegex(
        R"(foreach\s*\(\s*([a-zA-Z_][a-zA-Z0-9_<>, ]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+in\s+([a-zA-Z_][a-zA-Z0-9_\->\.]*)\s*\))");
static const std::regex declRegex(R"(([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+)\s*=\s*new\s+([a-zA-Z0-9_]+)\((.*)\);)");
static const std::regex connectRegex(R"(([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\s*\+=\s*([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+);)");
static const std::regex interpRegex(R"(\$\"([^\"]*)\")");
static const std::regex placeholderRegex(R"(\{([^}]+)\})");
static const std::regex isTypeRegex(
            R"(([a-zA-Z_][a-zA-Z0-9_]*)\s+\bis\b\s+([a-zA-Z_][a-zA-Z0-9_]*))");
static const std::regex asTypeRegex(
            R"(([a-zA-Z_][a-zA-Z0-9_]*)\s+\bas\b\s+([a-zA-Z_][a-zA-Z0-9_]*))");
static const std::regex memberAllocRegex(
    R"(([a-zA-Z0-9_]+)->m_([a-zA-Z0-9_]+)\s*=\s*new\s+([a-zA-Z0-9_]+)\((.*)\);)");
static const std::regex propConnectRegex(
    R"(this->m_([a-zA-Z0-9_]+)->([a-zA-Z0-9_]+)\s*\+=\s*this->([a-zA-Z0-9_]+);)");

void save_to_file(const std::string& filename, const std::string& content) {
    std::string fullPath = outputDir.empty() ? filename : outputDir + "/" + filename;
    std::ofstream file(fullPath);
    if (file.is_open()) {
        file << content;
        file.close();
        printf("[K#]: %s generated.\n", fullPath.c_str());
    } else {
        fprintf(stderr, "K# IO Error: could not write to file %s\n", fullPath.c_str());
    }
}


bool isPointerType(const std::string& mappedType)
{
    return
        KSharpWidgetBases.count(mappedType) > 0;
}

std::string mapType(const std::string& ksharpType) {
    // Check primitives first
    if (ksharpType == "auto") return "auto";
    if (KSharpPrimitives.count(ksharpType)) {
        return KSharpPrimitives.at(ksharpType);
    }

    // Then dynamic types from registry
    if (dynamicTypeMap.count(ksharpType)) {
        return dynamicTypeMap.at(ksharpType);
    }

    // Generic list handling
    if (ksharpType.find("List<") == 0) {
        std::string inner = ksharpType.substr(5, ksharpType.length() - 6);
        return "QList<" + mapType(inner) + ">";
    }

    if (ksharpType.find("Dictionary<") == 0) {
        // parse key,value types
        std::string inner = ksharpType.substr(11, ksharpType.length() - 12);
        size_t comma = inner.find(',');
        std::string key = inner.substr(0, comma);
        std::string val = inner.substr(comma + 1);
        return "QMap<" + mapType(key) + "," + mapType(val) + ">";
    }

    if (ksharpType.find("HashSet<") == 0) {
        std::string inner = ksharpType.substr(8, ksharpType.length() - 9);
        return "QSet<" + mapType(inner) + ">";
    }

    for (const auto& [ns, types] : KSharpTypeRegistry) {
        if (types.count(ksharpType))
            return types.at(ksharpType).cppType;
    }

    return ksharpType;
}

std::string mapImport(const std::string& imp) {
    if (ksharp_import_map.count(imp)) {
        return ksharp_import_map[imp];
    }
    return imp; // Default to literal name
}

std::string mapParamType(const std::string& type) {
    std::string mapped = mapType(type);


    if (type == "string[]") return "const QStringList&";
    if (mapped == "QString" || mapped == "QChar" ||
        mapped.find("List") != std::string::npos) {
        return "const " + mapped + "&";
    }

    return mapped; // int, float, etc. stay as-is
}

std::string mapParentClass(const std::string& parentClass) {
    for (const auto& [ns, types] : KSharpTypeRegistry) {
        if (types.count(parentClass)) {
            return types.at(parentClass).cppType;
        }
    }
    return parentClass; // fall through to literal, e.g. a user-defined parent
}


// Helper to resolve types
std::string get_class_of(const std::string& varName) {
    if (symbolTable.find(varName) != symbolTable.end()) {
        return symbolTable[varName];
    }
    // Fallback or Error
    return "QObject";
}


void resolve_registry_types(const std::set<std::string>& activeImports,
                            std::set<std::string>& auto_includes) {
    for (const std::string& import : activeImports) {
        if (KSharpTypeRegistry.count(import)) {
            for (auto const& [kType, data] : KSharpTypeRegistry.at(import)) {
                // Update the global mapType logic dynamically
                // (You'll need to modify your mapType function to check this)
                dynamicTypeMap[kType] = data.cppType;
                auto_includes.insert(data.requiredHeader);
            }
        }
    }
}

std::string apply_namespaced_libraries(std::string body,
                                      const std::set<std::string>& activeImports,
                                      std::set<std::string>& auto_includes) {
    std::string preambles = "";
    for (const std::string& import : activeImports) {
        // Check if this imported namespace exists in our registry
        if (KSharpNamespaceRegistry.count(import)) {
            const auto& availableMethods = KSharpNamespaceRegistry.at(import);

            for (auto const& [kMethod, data] : availableMethods) {
                size_t pos = 0;
                while ((pos = body.find(kMethod, pos)) != std::string::npos) {
                    // Only replace if it matches the namespace the user actually imported
                       size_t afterMatch = pos + kMethod.length();
                        if (afterMatch < body.size() && body[afterMatch] != '(') {
                            pos += kMethod.length();
                            continue;
                        }
                        body.replace(pos, kMethod.length(), data.cppTranslation);

                    auto_includes.insert(data.requiredHeader);
                    if (!data.preamble.empty() &&
                        preambles.find(data.preamble) == std::string::npos) {
                        preambles += data.preamble + "\n";
                    }
                    pos += data.cppTranslation.length();
                }
            }
        }
    }
    return preambles.empty() ? body : preambles + body;
}

bool isValueType(const std::string& cppType) {
    if (KSharpValueTypes.count(cppType)) return true;
    // Generic containers — QList<int>, QMap<QString,int> etc.
    if (cppType.find("QList<") == 0) return true;
    if (cppType.find("QMap<") == 0) return true;
    if (cppType.find("QSet<") == 0) return true;
    if (cppType.find("QHash<") == 0) return true;
    return false;
}

std::string process_allocation(std::string body,  bool isStatic = false)
{
    std::string result = "";
    auto words_begin = std::sregex_iterator(body.begin(), body.end(), declRegex);
    auto words_end = std::sregex_iterator();
    size_t lastPos = 0;

    for (std::sregex_iterator i = words_begin; i != words_end; ++i) {
        std::smatch match = *i;
        std::string type = match.str(1);
        std::string name = match.str(2);
        std::string args = match.str(4);
        std::string cppType = mapType(type);

        result += body.substr(lastPos, match.position() - lastPos);

        if (isValueType(cppType)) {
            // Stack allocation — no pointer, no this injection
            result += cppType + " " + name + "(" + args + ");";
        } else {
            // Heap allocation with parent injection
            symbolTable[name] = type;
            std::string heapAlloc = cppType + "* " + name + " = new " + cppType + "(";
            // Check if the instantiated type is a widget subclass
            bool isWidget = KSharpWidgetBases.count(cppType) > 0;
            if (!isWidget) {
                for (const auto& cls : fileClasses) {
                    if (cls.name == cppType && KSharpWidgetBases.count(cls.parentClass) > 0) {
                        isWidget = true;
                        break;
                    }
                }
            }

            bool isLayout = KSharpLayoutTypes.count(cppType) > 0;

            if (isStatic) {
                if (args.empty()) {
                    heapAlloc += isWidget ? "nullptr" : "&app";
                } else {
                    heapAlloc += isWidget ? args + ", nullptr" : args;
                }
            } else {
                if (isLayout) {
                    heapAlloc += args.empty() ? "this" : args;
                } else if (isWidget) {
                    heapAlloc += args.empty() ? "this" : args + ", this";
                } else {
                    heapAlloc += args.empty() ? "this" : "this, " + args;
                }
            }
            heapAlloc += ");";
            result += heapAlloc;
        }

        lastPos = match.position() + match.length();
    }
    result += body.substr(lastPos);
    auto member_begin = std::sregex_iterator(result.begin(), result.end(), memberAllocRegex);
    auto member_end = std::sregex_iterator();
    std::string result2 = "";
    size_t lastPos2 = 0;

    for (std::sregex_iterator i = member_begin; i != member_end; ++i) {
        std::smatch match = *i;
        std::string owner = match.str(1);   // "this"
        std::string member = match.str(2);  // "Title"
        std::string type = match.str(3);    // "Label"
        std::string args = match.str(4);    // "Hello from K#!"
        std::string cppType = mapType(type);

        result2 += result.substr(lastPos2, match.position() - lastPos2);

        bool isWidget = KSharpWidgetBases.count(cppType) > 0;
        std::string alloc = owner + "->m_" + member + " = new " + cppType + "(";

         bool isLayout = KSharpLayoutTypes.count(cppType) > 0;

            if (isStatic) {
                if (args.empty()) {
                    alloc += isWidget ? "nullptr" : "&app";
                } else {
                    alloc += isWidget ? args + ", nullptr" : args;
                }
            } else {
                if (isLayout) {
                    alloc += args.empty() ? "this" : args;
                } else if (isWidget) {
                    alloc += args.empty() ? "this" : args + ", this";
                } else {
                    alloc += args.empty() ? "this" : "this, " + args;
                }
            }
        alloc += ");";
        result2 += alloc;
        lastPos2 = match.position() + match.length();
    }
    result2 += result.substr(lastPos2);
    return result2;
}

std::string process_local_decl(const std::string& body, bool init = true){
    std::string result = "";
    size_t lastPos = 0;
    if (init){
        auto begin = std::sregex_iterator(body.begin(), body.end(), localDeclRegex);
        auto end = std::sregex_iterator();

        for (std::sregex_iterator i = begin; i != end; ++i) {
            std::smatch match = *i;
            std::string cppType = mapType(match.str(1));
            std::string varName = match.str(2);

            result += body.substr(lastPos, match.position() - lastPos);
            result += cppType + " " + varName + " =";
            lastPos = match.position() + match.length();
        }
    } else {
        auto begin = std::sregex_iterator(body.begin(), body.end(), localDeclNoInitRegex);
        auto end = std::sregex_iterator();

        for (std::sregex_iterator i = begin; i != end; ++i) {
            std::smatch match = *i;
            std::string cppType = mapType(match.str(1));
            std::string varName = match.str(2);

            result += body.substr(lastPos, match.position() - lastPos);
            result += cppType + " " + varName + ";";
            lastPos = match.position() + match.length();
        }
    }
    result += body.substr(lastPos);
    return result;
}

std::string process_type_check(const std::string& body){
        std::string result = "";
        size_t lastPos = 0;
        auto begin = std::sregex_iterator(body.begin(), body.end(), isTypeRegex);
        auto end = std::sregex_iterator();

        for (std::sregex_iterator i = begin; i != end; ++i) {
            std::smatch match = *i;
            std::string expr = match.str(1);
            std::string type = match.str(2);
            result += body.substr(lastPos, match.position() - lastPos);
            result += "dynamic_cast<" + mapType(type) + "*>(" + expr + ") != nullptr";
            lastPos = match.position() + match.length();
        }
        result += body.substr(lastPos);
        return result;
}

std::string process_cast(const std::string& body){
        std::string result = "";
        size_t lastPos = 0;
        auto begin = std::sregex_iterator(body.begin(), body.end(), asTypeRegex);
        auto end = std::sregex_iterator();

        for (std::sregex_iterator i = begin; i != end; ++i) {
            std::smatch match = *i;
            std::string expr = match.str(1);
            std::string type = match.str(2);
            result += body.substr(lastPos, match.position() - lastPos);
            result += "dynamic_cast<" + mapType(type) + "*>(" + expr + ")";
            lastPos = match.position() + match.length();
        }
        result += body.substr(lastPos);
        return result;
}

std::string process_for_loop(const std::string& body){
        std::string result = "";
        size_t lastPos = 0;
        auto begin = std::sregex_iterator(body.begin(), body.end(), foreachRegex);
        auto end = std::sregex_iterator();

        for (std::sregex_iterator i = begin; i != end; ++i) {
            std::smatch match = *i;
            std::string kType   = match.str(1);
            std::string varName = match.str(2);
            std::string expr    = match.str(3);
            std::string cppType = mapType(kType);

            // Use const ref for non-primitives
            std::string iterType = mapParamType(kType);

            result += body.substr(lastPos, match.position() - lastPos);
            result += "for (" + iterType + " " + varName + " : " + expr + ")";
            lastPos = match.position() + match.length();
        }
        result += body.substr(lastPos);
        return result;
}

std::string process_connection(const std::string& body, bool isStatic = false)
{
    std::string result = "";
    size_t lastPos = 0;
    if (!isStatic) {
        auto conn_begin = std::sregex_iterator(body.begin(), body.end(), connectRegex);
        auto conn_end = std::sregex_iterator();

        for (std::sregex_iterator i = conn_begin; i != conn_end; ++i) {
            std::smatch match = *i;
            result += body.substr(lastPos, match.position() - lastPos);

            std::string sender = match.str(1);
            std::string signal = match.str(2);
            std::string receiver = match.str(3);
            std::string slot = match.str(4);

            // This is where the barren loop gets its "Soul"
            std::string connStr = "QObject::connect(" + sender + ", &" + get_class_of(sender) + "::" + signal +
                                ", " + receiver + ", &" + get_class_of(receiver) + "::" + slot + ");";

            result += connStr;
            lastPos = match.position() + match.length();
        }
    }
    result += body.substr(lastPos);
    return result;
}

std::string process_prop_connection(const std::string& body, bool isStatic = false)
{
    std::string result = "";
    size_t lastPos = 0;
    if (!isStatic) {
        auto conn_begin = std::sregex_iterator(body.begin(), body.end(), propConnectRegex);
        auto conn_end = std::sregex_iterator();

        for (std::sregex_iterator i = conn_begin; i != conn_end; ++i) {
            std::smatch match = *i;
            result += body.substr(lastPos, match.position() - lastPos);

            std::string propName    = match.str(1);  // ClickMe
            std::string signal      = match.str(2);  // clicked
            std::string slot        = match.str(3);  // OnClickMe

            std::string propCppType = "QObject";
            for (const auto& prop : parsedClass.properties) {
                if (prop.name == propName) {
                    propCppType = mapType(prop.type);
                    break;
                }
            }

            // Look up signal in map
            std::string resolvedSignal = signal;
            if (KSharpSignalMap.count(propCppType) &&
                KSharpSignalMap.at(propCppType).count(signal)) {
                resolvedSignal = KSharpSignalMap.at(propCppType).at(signal);
            }

            std::string connStr = "QObject::connect(this->m_" + propName +
                ", &" + propCppType + "::" + resolvedSignal +
                ", this, &" + parsedClass.name + "::" + slot + ");";

            result += connStr;
            lastPos = match.position() + match.length();
        }
    }
    result += body.substr(lastPos);
    return result;
}

std::string process_strinterp(const std::string& body){
        std::string result = "";
        size_t lastPos = 0;
        auto begin = std::sregex_iterator(body.begin(), body.end(), interpRegex);
        auto end = std::sregex_iterator();

        for (std::sregex_iterator i = begin; i != end; ++i) {
            std::smatch match = *i;
            std::string inner = match.str(1);

            // Collect placeholder expressions
            std::vector<std::string> args;
            std::string format = inner;

            // Replace each {expr} with %N
            int argIndex = 1;
            std::smatch ph;
            std::string temp = inner;
            std::string formatResult = "";
            size_t searchPos = 0;

            auto ph_begin = std::sregex_iterator(inner.begin(), inner.end(), placeholderRegex);
            auto ph_end = std::sregex_iterator();
            size_t innerLast = 0;

            for (std::sregex_iterator j = ph_begin; j != ph_end; ++j) {
                std::smatch pmatch = *j;
                formatResult += inner.substr(innerLast, pmatch.position() - innerLast);
                formatResult += "%" + std::to_string(argIndex++);
                args.push_back(pmatch.str(1));
                innerLast = pmatch.position() + pmatch.length();
            }
            formatResult += inner.substr(innerLast);

            // Build QString("format").arg(expr1).arg(expr2)...
            std::string rewritten = "QString(\"" + formatResult + "\")";
            for (const auto& arg : args) {
                rewritten += ".arg(" + arg + ")";
            }

            result += body.substr(lastPos, match.position() - lastPos);
            result += rewritten;
            lastPos = match.position() + match.length();
        }
        result += body.substr(lastPos);
        return result;
}

std::string process_body(std::string body,  bool isStatic = false) {

    {
        size_t p = 0;
        while ((p = body.find("var", p)) != std::string::npos) {
            bool beforeOk = (p == 0) || !isalnum(body[p-1]) && body[p-1] != '_';
            bool afterOk  = (p + 3 >= body.size()) || !isalnum(body[p+3]) && body[p+3] != '_';
            if (beforeOk && afterOk) {
                body.replace(p, 3, "auto");
                p += 4;
            } else {
                p += 3;
            }
        }
    }

    if (!isStatic) {
        size_t pos = 0;
        while ((pos = body.find("this.", pos)) != std::string::npos) {
            body.replace(pos, 5, "this->");
            pos += 6;
        }

        // Rewrite null to nullptr
        {
            size_t p = 0;
            while ((p = body.find("null", p)) != std::string::npos) {
                bool beforeOk = (p == 0) || !isalnum(body[p-1]) && body[p-1] != '_';
                bool afterOk  = (p + 4 >= body.size()) || !isalnum(body[p+4]) && body[p+4] != '_';
                if (beforeOk && afterOk) {
                    body.replace(p, 4, "nullptr");
                    p += 7;
                } else {
                    p += 4;
                }
            }
        }

        for (const auto& prop : parsedClass.properties) {
            std::string search = "this->" + prop.name;
            std::string replace = "this->m_" + prop.name;

            size_t p_pos = 0;
            while ((p_pos = body.find(search, p_pos)) != std::string::npos) {
                body.replace(p_pos, search.length(), replace);
                p_pos += replace.length();
            }
        }
        for (const auto& method : parsedClass.methods) {
            if (method.isSignal) {
                std::string signalName = method.name;
                // Use a regex to find signal calls that aren't already preceded by 'emit'
                // or part of a string. For a simpler start, look for 'SignalName('
                size_t s_pos = 0;
                while ((s_pos = body.find(signalName + "(", s_pos)) != std::string::npos) {
                    // Look back to see if 'emit' is already there
                    bool hasEmit = false;
                    if (s_pos >= 5) {
                        std::string lead = body.substr(s_pos - 5, 5);
                        if (lead == "emit ") hasEmit = true;
                    }

                    if (!hasEmit) {
                        body.insert(s_pos, "emit ");
                        s_pos += 5; // Skip the new 'emit '
                    }
                    s_pos += signalName.length() + 1;
                }
            }
        }
        for (const auto& prop : parsedClass.properties) {
            std::string signalName = prop.name + "Changed";
            // same emit-injection logic as the methods loop
            size_t s_pos = 0;
            while ((s_pos = body.find(signalName + "(", s_pos)) != std::string::npos) {
                    // Look back to see if 'emit' is already there
                    bool hasEmit = false;
                    if (s_pos >= 5) {
                        std::string lead = body.substr(s_pos - 5, 5);
                        if (lead == "emit ") hasEmit = true;
                    }

                    if (!hasEmit) {
                        body.insert(s_pos, "emit ");
                        s_pos += 5; // Skip the new 'emit '
                    }
                    s_pos += signalName.length() + 1;
            }
        }
        for (const auto& prop : parsedClass.properties) {
            std::string mappedType = mapType(prop.type);
            if (KSharpWidgetBases.count(mappedType) > 0) {
                std::string search = "this->m_" + prop.name + ".";
                std::string replace = "this->m_" + prop.name + "->";
                size_t p = 0;
                while ((p = body.find(search, p)) != std::string::npos) {
                    body.replace(p, search.length(), replace);
                    p += replace.length();
                }
            }
        }
    }

    body = process_local_decl(body);
    // Pass: rewrite local variable declarations without initializers
    body = process_local_decl(body, false);
     // Rewrite 'expr is Type' to dynamic_cast check
    body = process_type_check(body);
    body = process_cast(body);
    body = process_for_loop(body);
    // Rewrite string interpolation $"..." to QString::arg()
    body = process_strinterp(body);

    {
        for (const auto& [csType, cppType] : KSharpExceptionRegistry) {
            size_t p = 0;
            while ((p = body.find(csType, p)) != std::string::npos) {
                bool beforeOk = (p == 0) || !isalnum(body[p-1]) && body[p-1] != '_';
                bool afterOk  = (p + csType.size() >= body.size()) ||
                                !isalnum(body[p + csType.size()]) && body[p + csType.size()] != '_';
                if (beforeOk && afterOk) {
                    body.replace(p, csType.size(), cppType);
                    p += cppType.size();
                } else {
                    p += csType.size();
                }
            }
        }

        size_t p = 0;
        while ((p = body.find(".Message", p)) != std::string::npos) {
            body.replace(p, 8, ".what()");
            p += 7;
        }
    }

    body = process_allocation(body, isStatic);
    for (const auto& [varName, type] : symbolTable) {
            std::string search = varName + ".";
            std::string replace = varName + "->";
            size_t p = 0;
            while ((p = body.find(search, p)) != std::string::npos) {
                // Don't rewrite if preceded by -> (it's a member, not a local variable)
                if (p >= 2 && body.substr(p - 2, 2) == "->") {
                    p += search.length();
                    continue;
                }
                body.replace(p, search.length(), replace);
                p += replace.length();
            }
    }



    body = process_connection(body, isStatic);
    body = process_prop_connection(body, isStatic);

    std::string result = body;

    size_t bodyStart = result.find_first_not_of("\n\r");
    if (bodyStart != std::string::npos)
        result = result.substr(bodyStart);

    std::istringstream stream(result);
    std::string line, normalized;
    bool lastWasEmpty = false;
    int depth = 1; // start at 1 since we're inside a method body
    while (std::getline(stream, line)) {
        size_t start = line.find_first_not_of(" \t");
        if (start == std::string::npos) {
            if (!lastWasEmpty) { normalized += "\n"; lastWasEmpty = true; }
            continue;
        }
        std::string trimmed = line.substr(start);
        if (trimmed[0] == '}') depth--;
        normalized += std::string(depth * 4, ' ') + trimmed + "\n";
        if (trimmed.back() == '{') depth++;
        lastWasEmpty = false;
    }
    // Strip leading and trailing blank lines
    size_t first = normalized.find_first_not_of("\n");
    size_t last = normalized.find_last_not_of("\n");
    if (first != std::string::npos)
        normalized = normalized.substr(first, last - first + 1);

    return normalized;
}



void add_method_to_class(KSharpMethod m) {
    printf("[K#]: add_method_to_class: name=%s returnType=%s isStatic=%d\n",         m.name.c_str(), m.returnType.c_str(), m.isStatic);
    if (m.name == parsedClass.name) {
        parsedClass.hasCustomConstructor = true;
        // We still process the body to handle 'this.' and connections
        parsedClass.constructorBody = process_body(m.body);
    }  else if (m.isStatic && m.returnType == "void" && m.name == "Main") {
            hasEntryPoint = true;
            parsedClass.entryPointBody = process_body(m.body, true);
            // Don't push it into methods — it won't become a class method in the output
    } else {
        m.body = process_body(m.body);
        parsedClass.methods.push_back(m);
    }
}

std::string getDefaultValue(const std::string& cppType) {
    if (cppType == "int" || cppType == "float" ||
        cppType == "double" || cppType == "long") return "0";
    if (cppType == "bool")    return "false";
    if (cppType == "QString") return "\"\"";
    if (cppType == "QChar")   return "'\\0'";
    return ""; // QList, QMap etc. — default constructed, no init needed
}



 void generate_cpp_class(const KSharpClass& cls)
 {

   nlohmann::json ctx;
    std::set<std::string> header_includes = ksharp_imports;
    header_includes.insert("QObject");


   std::string ns = cls.namespaceId;
   size_t pos = 0;
   while ((pos = ns.find('.', pos)) != std::string::npos) {
            ns.replace(pos, 1, "::");
            pos += 2; // Move past the newly inserted "::"
        }


    std::set<std::string> requiredLinkerFlags;

    for (const auto& imp : ksharp_imports) {
        if (KSharpLibRegistry.count(imp)) {
            requiredLinkerFlags.insert(KSharpLibRegistry.at(imp).linkerFlag);
        }
    }

    // Pass this to your Inja template for the Build Script
    ctx["linkerFlags"] = requiredLinkerFlags;



    ctx["className"] = cls.name;
    ctx["parent"] = cls.parentClass;

    // Look up the required header for the parent
    std::string parentInclude = "";
    for (const auto& [ns, types] : KSharpTypeRegistry) {
        for (const auto& [kType, data] : types) {
            if (data.cppType == cls.parentClass) {
                parentInclude = data.requiredHeader;
                break;
            }
        }
    }

    ctx["parentInclude"] = parentInclude;
    ctx["modifier"] = cls.accessModifier;
    ctx["namespaceName"] = ns;
    ctx["existingConstructorBody"] = cls.hasCustomConstructor;
    ctx["constructorBody"] = cls.constructorBody;
    ctx["isAbstract"] = cls.isAbstract;
    ctx["properties"] = nlohmann::json::array();
    for (const auto& prop : cls.properties) {
        nlohmann::json p;
        p["name"] = prop.name;
        std::string mappedType = mapType(prop.type);
        bool isPointer = isPointerType(mappedType);
        p["isPointerType"] = isPointer;
        p["type"] = isPointer ? mappedType + "*" : mappedType;
        p["paramType"] = isPointer ? mappedType + "*" : mapParamType(prop.type);
        p["hasCustomGetter"] = prop.hasCustomGetter;
        p["hasCustomSetter"] = prop.hasCustomSetter;
        p["getterBody"] = prop.getterBody;
        p["setterBody"] = prop.setterBody;
        std::string defVal = prop.defaultValue.empty() ?
            getDefaultValue(mappedType) : prop.defaultValue;
        p["defaultValue"] = defVal;
        p["hasDefault"] = !defVal.empty();
        p["isStatic"] = prop.isStatic;
        ctx["properties"].push_back(p);
    }

    for (const auto& prop : cls.properties) {
        if (prop.type == "string") header_includes.insert("QString");
    }

    for (const auto& prop : cls.properties) {
        std::string mapped = mapType(prop.type);
        if (mapped.find("QList") != std::string::npos) header_includes.insert("QList");
        if (mapped == "QStringList") header_includes.insert("QStringList");
    }

    for (const auto& prop : cls.properties) {
        std::string mappedType = mapType(prop.type);
        // Look up header for this type
        for (const auto& [ns, types] : KSharpTypeRegistry) {
            for (const auto& [kType, data] : types) {
                if (data.cppType == mappedType || kType == prop.type) {
                    if (!data.requiredHeader.empty())
                        header_includes.insert(data.requiredHeader);
                }
            }
        }
    }

    // Check methods for types that need headers
    for (const auto& method : cls.methods) {
        if (method.returnType == "string" || method.returnType == "QString")
            header_includes.insert("QString");

        for (const auto& p : method.parameters) {
            if (p.type.find("QString") != std::string::npos)
                header_includes.insert("QString");
        }
    }

    ctx["methods"] = nlohmann::json::array();
    ctx["signals"] = nlohmann::json::array();
    ctx["slots"] = nlohmann::json::array();

    for (const auto& method : cls.methods) {
        nlohmann::json m;
        m["name"] = method.name;
        m["returnType"] = mapType(method.returnType);
        m["body"] = apply_namespaced_libraries(method.body, ksharp_active_namespaces, header_includes);
        m["accessModifier"] = method.accessModifier;
        m["isSlot"] = method.isSlot;
        m["isSignal"] = method.isSignal;
        m["isStatic"] = method.isStatic;
        m["isAbstract"] = method.isAbstract;
        m["isOverride"] = method.isOverride;
        m["isVirtual"] = method.isVirtual;
        m["parameters"] = nlohmann::json::array();
        for (const auto& p : method.parameters) {
            nlohmann::json param;
            param["name"] = p.name;
            // Map parameter 'string' to 'const QString&'
            param["type"] = p.type;
            m["parameters"].push_back(param);
        }
        if (method.isSignal) {
            ctx["signals"].push_back(m);
        } else if (method.isSlot) {
            ctx["slots"].push_back(m);
        } else {
            ctx["methods"].push_back(m);
        }
        if (method.body.find("std::exception") != std::string::npos ||
            method.body.find("std::runtime_error") != std::string::npos) {
            header_includes.insert("stdexcept");
        }
    }

    std::set<std::string> filtered_includes;
       for (const auto& inc : header_includes) {
        // Strip raw K# import keys
        if (ksharp_import_map.count(inc)) continue;
        // Strip namespace registry keys
        if (KSharpNamespaceRegistry.count(inc)) continue;
        // Strip KSharpTypeRegistry namespace keys
        bool isTypeNamespace = false;
        for (const auto& [ns, types] : KSharpTypeRegistry) {
            if (inc == ns) { isTypeNamespace = true; break; }
        }
        if (isTypeNamespace) continue;
        // Strip anything containing a dot — not a valid C++ header
        if (inc.find('.') != std::string::npos) continue;
        filtered_includes.insert(inc);
    }

    header_includes = filtered_includes;
    ctx["includes"] = header_includes;
    ctx["hasPrivateMethods"] = std::any_of(cls.methods.begin(), cls.methods.end(),
        [](const KSharpMethod& m){ return m.accessModifier == "private" && !m.isSlot; });
    ctx["hasProtectedMethods"] = std::any_of(cls.methods.begin(), cls.methods.end(),
        [](const KSharpMethod& m){ return m.accessModifier == "protected" && !m.isSlot; });
    ctx["hasPrivateSlots"] = std::any_of(cls.methods.begin(), cls.methods.end(),
        [](const KSharpMethod& m){ return m.accessModifier == "private" && m.isSlot; });
    ctx["hasProtectedSlots"] = std::any_of(cls.methods.begin(), cls.methods.end(),
        [](const KSharpMethod& m){ return m.accessModifier == "protected" && m.isSlot; });

    bool isAppClass = KSharpAppEntryTypes.count(cls.parentClass) > 0;
    ctx["isAppClass"] = isAppClass;

    bool isWidgetClass = false;
    if (KSharpWidgetBases.count(cls.parentClass)) isWidgetClass = true;
    ctx["isWidgetClass"] = isWidgetClass;

    std::string firstInNs = "";

    bool isFirstClassInNamespace = true;
    for (const auto& other : fileClasses) {
        if (other.name == cls.name) break;
        if (other.namespaceId == cls.namespaceId) {
            isFirstClassInNamespace = false;
            firstInNs = other.name;

            break;
        }
    }



    ctx["isFirstClassInNamespace"] = isFirstClassInNamespace;
    ctx["firstClassInNamespace"] = isFirstClassInNamespace ? "" : firstInNs;

    ctx["enums"] = nlohmann::json::array();
    ctx["interfaces"] = nlohmann::json::array();

    if (isFirstClassInNamespace) {
        for (const auto& enm : fileEnums) {
            if (enm.namespaceId == cls.namespaceId) {
                nlohmann::json e;
                e["name"] = enm.name;
                e["values"] = nlohmann::json::array();
                for (const auto& v : enm.values) {
                    nlohmann::json val;
                    val["name"] = v.name;
                    val["hasExplicitValue"] = v.hasExplicitValue;
                    val["explicitValue"] = v.explicitValue;
                    e["values"].push_back(val);
                }
                ctx["enums"].push_back(e);
            }
        }
        for (const auto& iface : fileInterfaces) {
            if (iface.namespaceId == cls.namespaceId) {
                nlohmann::json i;
                i["name"] = iface.name;
                i["methods"] = nlohmann::json::array();
                for (const auto& method : iface.methods) {
                    nlohmann::json m;
                    m["name"] = method.name;
                    m["returnType"] = mapType(method.returnType);
                    m["parameters"] = nlohmann::json::array();
                    for (const auto& p : method.parameters) {
                        nlohmann::json param;
                        param["name"] = p.name;
                        param["type"] = mapParamType(p.type);
                        m["parameters"].push_back(param);
                    }
                    i["methods"].push_back(m);
                }
                ctx["interfaces"].push_back(i);
            }
        }
    }



    inja::Environment env;
    try {
        std::string header = env.render_file("templates/class.h.tpl", ctx);
        std::string source = env.render_file("templates/class.cpp.tpl", ctx);
        save_to_file(cls.name + ".h", header);
        save_to_file(cls.name + ".cpp", source);
    } catch(std::exception& e) {
       fprintf(stderr, "K# Template Error: %s\n", e.what());
    }
 }

 void generate_cmake(const std::string& projectName) {
   if (fileClasses.empty() && !hasEntryPoint) {
        fprintf(stderr, "K# Warning: No classes or entry point found — skipping CMakeLists.txt generation.\n");
        return;
    }

    nlohmann::json ctx;
    ctx["projectName"] = projectName;
    ctx["hasEntryPoint"] = hasEntryPoint;
    ctx["hasClasses"] = !fileClasses.empty();
    ctx["classes"] = nlohmann::json::array();
    for (const auto& cls : fileClasses) {
        ctx["classes"].push_back(cls.name);
    }

    ctx["linkerFlags"] = nlohmann::json::array();
    std::set<std::string> flags;
    for (const auto& imp : ksharp_imports) {
        if (KSharpLibRegistry.count(imp)) {
            flags.insert(KSharpLibRegistry.at(imp).linkerFlag);
        }
    }
    for (const auto& f : flags) {
        ctx["linkerFlags"].push_back(f);
    }

    bool needsKF6 = false;
    for (const auto& cls : fileClasses) {
        if (KF6Types.count(cls.parentClass) > 0) {
            needsKF6 = true;
            break;
        }
    }
    bool needsWidgets = false;
    for (const auto& cls : fileClasses) {
        if (KSharpWidgetBases.count(cls.parentClass)) {
            needsWidgets = true;
            break;
        }
    }
    ctx["needsWidgets"] = needsWidgets;

    ctx["needsKF6"] = needsKF6;

    inja::Environment env;
    try {
        std::string cmake = env.render_file("templates/CMakeLists.txt.tpl", ctx);
        save_to_file("CMakeLists.txt", cmake);
    } catch (std::exception& e) {
        fprintf(stderr, "K# Template Error: %s\n", e.what());
    }
}

void generate_main(const std::string& projectName) {
    // Find the entry point class
    KSharpClass* entryClass = nullptr;
    for (auto& cls : fileClasses) {
        if (!cls.entryPointBody.empty()) {
            entryClass = &cls;
            break;
        }
    }

    if (!entryClass) {
        fprintf(stderr, "K# Warning: hasEntryPoint set but no entry point body found.\n");
        return;
    }

    // Look up the header for the app type
    std::string parentInclude = "";
    for (const auto& [ns, types] : KSharpTypeRegistry) {
        for (const auto& [kType, data] : types) {
            if (data.cppType == entryClass->parentClass) {
                parentInclude = data.requiredHeader;
                break;
            }
        }
    }

    nlohmann::json ctx;
    ctx["projectName"] = projectName;
    ctx["appType"] = entryClass->parentClass;
    ctx["parentInclude"] = parentInclude;
    ctx["entryPointBody"] = entryClass->entryPointBody;
    ctx["className"] = entryClass->name;

    ctx["allClasses"] = nlohmann::json::array();
    for (const auto& cls : fileClasses) {
        ctx["allClasses"].push_back(cls.name);
    }

    ctx["namespaces"] = nlohmann::json::array();
    std::set<std::string> seenNs;
    for (const auto& cls : fileClasses) {
        if (!cls.namespaceId.empty() && !seenNs.count(cls.namespaceId)) {
            // Convert dots to ::
            std::string ns = cls.namespaceId;
            size_t pos = 0;
            while ((pos = ns.find('.', pos)) != std::string::npos) {
                ns.replace(pos, 1, "::");
                pos += 2;
            }
            ctx["namespaces"].push_back(ns);
            seenNs.insert(cls.namespaceId);
        }
    }

    inja::Environment env;
    try {
        bool isTridentu = KSharpTridentuAppTypes.count(entryClass->parentClass) > 0;
        std::string templateFile = isTridentu ?
        "templates/main_tridentu.cpp.tpl" :
        "templates/main.cpp.tpl";

        std::string main = env.render_file(templateFile, ctx);
        save_to_file("kshp_main.cpp", main);
    } catch (std::exception& e) {
        fprintf(stderr, "K# Template Error: %s\n", e.what());
    }
}

void generate_rc(const std::string& projectName) {
    std::string rc =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<!DOCTYPE gui SYSTEM \"kpartgui.dtd\">\n"
        "<gui name=\"" + projectName + "\" version=\"1\">\n"
        "    <MenuBar>\n"
        "        <Menu name=\"file\"><text>&amp;File</text>\n"
        "        </Menu>\n"
        "        <Menu name=\"edit\"><text>&amp;Edit</text>\n"
        "        </Menu>\n"
        "    </MenuBar>\n"
        "    <ToolBar name=\"mainToolBar\"><text>Main Toolbar</text>\n"
        "    </ToolBar>\n"
        "</gui>\n";
    save_to_file(projectName + "ui.rc", rc);
}

void reset_parser_state() {
    fileClasses.clear();
    fileEnums.clear();
    fileInterfaces.clear();
    ksharp_imports.clear();
    ksharp_active_namespaces.clear();
    symbolTable.clear();
    dynamicTypeMap.clear();
    temp_params.clear();
    hasEntryPoint = false;
    currentNamespaceId = "";
    parsedClass = KSharpClass();
    currentProp = KSharpProperty();
    currentEnum = KSharpEnum();
    currentInterface = KSharpInterface();
    isStatic_flag = 0;
    isAbstract_flag = 0;
    isOverride_flag = 0;
    isVirtual_flag = 0;
}


%}

%union {
    char *sval;
}


%token <sval> IDENTIFIER METHOD_BODY NUMBER STRING_LITERAL

%type <sval> access_modifier method_prefix

%token NAMESPACE CLASS PUBLIC PROPERTY SET GET  LBRACE RBRACE SEMICOLON DOT

%token VOID LBRACE_PAREN RBRACE_PAREN COMMA SLOT SIGNAL COLON L_ANGLE R_ANGLE

%token USING PLUS_EQUAL ASSIGN NEW PRIVATE PROTECTED

%token ENUM STATIC INTERFACE ABSTRACT OVERRIDE VIRTUAL

%right COLON

%%
program:
    prog_elements {
        bool hasKDEWindow = false;
        for (auto& cls : fileClasses) {
            generate_cpp_class(cls);
            if (cls.parentClass == "KXmlGuiWindow") hasKDEWindow = true;
        }
        if (hasEntryPoint) generate_main(projectName);
        if (hasKDEWindow) generate_rc(projectName);
        generate_cmake(projectName);
    }
    ;

prog_elements:
    | prog_elements using_statement
    | prog_elements namespace_definition
    | prog_elements class_declaration
    | prog_elements enum_declaration
    | prog_elements interface_declaration
    | prog_elements error SEMICOLON { yyerrok; }
    | prog_elements error RBRACE { yyerrok; }
    ;

namespace_definition:
    NAMESPACE IDENTIFIER LBRACE {
        capture_mode = 0;
        currentNamespaceId = $2;
        free($2);
    } prog_elements RBRACE {
        currentNamespaceId = "";
    }
    ;

using_statement:
    USING IDENTIFIER SEMICOLON {
        std::string raw = $2;
        std::string mapped = mapImport(raw);
        if (mapped != raw) {
            // It resolved to a header — add to includes
            ksharp_imports.insert(mapped);
        }
        // Always add raw for namespace registry lookups
        ksharp_active_namespaces.insert(raw);
        free($2);
    }
    ;


enum_declaration:
    PUBLIC ENUM IDENTIFIER LBRACE enum_values RBRACE {
        currentEnum.name = $3;
        currentEnum.namespaceId = currentNamespaceId;
        fileEnums.push_back(currentEnum);
        currentEnum = KSharpEnum();
        free($3);
    }
    ;

enum_values:
    | enum_values enum_value
    ;

enum_value:
    IDENTIFIER COMMA {
        KSharpEnumValue v;
        v.name = $1;
        currentEnum.values.push_back(v);
        free($1);
    }
    | IDENTIFIER ASSIGN NUMBER COMMA {
        KSharpEnumValue v;
        v.name = $1;
        v.hasExplicitValue = true;
        v.explicitValue = atoi($3);
        currentEnum.values.push_back(v);
        free($1);
    }
    | IDENTIFIER {
        KSharpEnumValue v;
        v.name = $1;
        currentEnum.values.push_back(v);
        free($1);
    }
    | IDENTIFIER ASSIGN NUMBER {
        KSharpEnumValue v;
        v.name = $1;
        v.hasExplicitValue = true;
        v.explicitValue = atoi($3);
        currentEnum.values.push_back(v);
        free($1);
    }
    ;

access_modifier:
    PUBLIC     { $$ = strdup("public"); }
    | PRIVATE  { $$ = strdup("private"); }
    | PROTECTED { $$ = strdup("protected"); }
    ;

method_prefix:
    access_modifier {
        $$ = strdup($1);
        isStatic_flag = 0;
        isAbstract_flag = 0;
        isOverride_flag = 0;
        isVirtual_flag = 0;
        free($1);
    }
    | access_modifier STATIC {
        $$ = strdup($1);
        isStatic_flag = 1;
        isAbstract_flag = 0;
        isOverride_flag = 0;
        isVirtual_flag = 0;
        free($1);
    }
    | access_modifier VIRTUAL {
        $$ = strdup($1);
        isStatic_flag = 0;
        isAbstract_flag = 0;
        isOverride_flag = 0;
        isVirtual_flag = 1;
        free($1);
    }
    | access_modifier OVERRIDE {
        $$ = strdup($1);
        isStatic_flag = 0;
        isAbstract_flag = 0;
        isOverride_flag = 1;
        isVirtual_flag = 0;
        free($1);
    }
    ;

interface_declaration:
    access_modifier INTERFACE IDENTIFIER LBRACE {
        currentInterface = KSharpInterface();
        currentInterface.name = $3;
        currentInterface.namespaceId = currentNamespaceId;
        currentInterface.accessModifier = $1;
        free($1);
    } interface_body RBRACE {
        fileInterfaces.push_back(currentInterface);
        free($3);
    }
    ;

interface_body:
    | interface_body interface_method
    ;

interface_method:
    IDENTIFIER IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN SEMICOLON {
        KSharpMethod m;
        m.returnType = $1;
        m.name = $2;
        m.parameters = temp_params;
        m.accessModifier = "public";
        temp_params.clear();
        currentInterface.methods.push_back(m);
        free($1); free($2);
    }
    | VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN SEMICOLON {
        KSharpMethod m;
        m.returnType = "void";
        m.name = $2;
        m.parameters = temp_params;
        m.accessModifier = "public";
        temp_params.clear();
        currentInterface.methods.push_back(m);
        free($2);
    }
    ;


class_declaration:
    method_prefix CLASS IDENTIFIER COLON IDENTIFIER LBRACE {
        parsedClass = KSharpClass();
        parsedClass.name = $3;
        parsedClass.namespaceId = currentNamespaceId;
        parsedClass.accessModifier = $1;
        parsedClass.parentClass = mapParentClass($5);
        free($1); free($3); free($5);
    } class_body RBRACE {
        printf("[K#]: Generating Qt/KDE C++ for class: %s\n", parsedClass.name.c_str());
        fileClasses.push_back(parsedClass);
    }
    | method_prefix CLASS IDENTIFIER LBRACE {
        parsedClass = KSharpClass();
        parsedClass.name = $3;
        parsedClass.namespaceId = currentNamespaceId;
        parsedClass.accessModifier = $1;
        parsedClass.parentClass = "QObject";
        free($1); free($3);
    } class_body RBRACE {
        printf("[K#]: Generating Qt/KDE C++ for class: %s\n", parsedClass.name.c_str());
        fileClasses.push_back(parsedClass);
    }
    | method_prefix ABSTRACT CLASS IDENTIFIER COLON IDENTIFIER LBRACE {
        parsedClass = KSharpClass();
        parsedClass.name = $4;
        parsedClass.namespaceId = currentNamespaceId;
        parsedClass.accessModifier = $1;
        parsedClass.isAbstract = true;
        parsedClass.parentClass = mapParentClass($6);
        free($1); free($4); free($6);
    } class_body RBRACE {
        printf("[K#]: Generating Qt/KDE C++ for abstract class: %s\n", parsedClass.name.c_str());
        fileClasses.push_back(parsedClass);
    }
    | method_prefix ABSTRACT CLASS IDENTIFIER LBRACE {
        parsedClass = KSharpClass();
        parsedClass.name = $4;
        parsedClass.namespaceId = currentNamespaceId;
        parsedClass.accessModifier = $1;
        parsedClass.isAbstract = true;
        parsedClass.parentClass = "QObject";
        free($1); free($4);
    } class_body RBRACE {
        printf("[K#]: Generating Qt/KDE C++ for abstract class: %s\n", parsedClass.name.c_str());
        fileClasses.push_back(parsedClass);
    }
    ;

class_body:
    | class_body member_declaration
    ;

member_declaration:
    property_declaration
    | method_declaration
    | signal_declaration
    | error SEMICOLON {
        yyerrok;
        fprintf(stderr, "[K#] Skipping malformed member declaration.\n");
    }
    | error RBRACE {
        yyerrok;
        fprintf(stderr, "[K#] Skipping malformed member declaration.\n");
    }
    ;



signal_declaration:
    method_prefix SIGNAL VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN SEMICOLON {
        KSharpMethod s;
        s.name = $4;
        s.returnType = "void";
        s.accessModifier = $1;
        s.isSignal = true; // Add this flag to your struct
        s.parameters = temp_params;
        temp_params.clear();
        parsedClass.methods.push_back(s);
        free($4);
    }
    ;



method_declaration:
    method_prefix SLOT IDENTIFIER IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN METHOD_BODY {
        KSharpMethod m;
        m.returnType = $3;
        m.name = $4;
        m.isSlot = true; // Mark as slot
        m.body = $8;
        m.parameters = temp_params;
        m.isStatic = isStatic_flag;
        m.isAbstract = isAbstract_flag;
        m.isOverride = isOverride_flag;
        m.isVirtual = isVirtual_flag;
        m.accessModifier = $1;
        add_method_to_class(m);
        temp_params.clear();
        free($1); free($3); free($4); free($8);
    }
    | method_prefix SLOT VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN METHOD_BODY {
        KSharpMethod m;
        m.returnType = "void";
        m.name = $4;
        m.isSlot = true; // Mark as slot
        m.body = $8;
        m.parameters = temp_params;
        m.accessModifier = $1;
        m.isStatic = isStatic_flag;
        m.isAbstract = isAbstract_flag;
        m.isOverride = isOverride_flag;
        m.isVirtual = isVirtual_flag;
        add_method_to_class(m);
        temp_params.clear();
        free($1); free($4); free($8);
    }
    | method_prefix VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN  METHOD_BODY {
        KSharpMethod m;
        m.returnType = "void";
        m.name = $3;
        m.body = $7;
        m.isSlot = false; // Or handle slot logic here if needed
        m.accessModifier = $1;
        m.parameters = temp_params;
        m.isStatic = isStatic_flag;
        m.isAbstract = isAbstract_flag;
        m.isOverride = isOverride_flag;
        m.isVirtual = isVirtual_flag;
        add_method_to_class(m);
        temp_params.clear();
        free($1); free($3); free($7);
    }
    | method_prefix IDENTIFIER IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN METHOD_BODY {
        KSharpMethod m;
        m.returnType = $2;
        m.name = $3;
        m.parameters = temp_params;
        m.body = $7;
        m.accessModifier = $1;
        m.isStatic = isStatic_flag;
        m.isAbstract = isAbstract_flag;
        m.isOverride = isOverride_flag;
        m.isVirtual = isVirtual_flag;
        add_method_to_class(m);
        temp_params.clear(); // Clear for the next method
        free($1); free($2); free($3); free($7);
    }
    | method_prefix IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN  METHOD_BODY {
        KSharpMethod m;
        m.name = $2;
        m.returnType = ""; // No return type implies constructor or error
        m.body = $6;
        m.accessModifier = $1;
        m.parameters = temp_params;
        m.isStatic = isStatic_flag;
        m.isAbstract = isAbstract_flag;
        m.isOverride = isOverride_flag;
        m.isVirtual = isVirtual_flag;
        add_method_to_class(m);
        temp_params.clear();
        free($1); free($2); free($6);
    }
    | method_prefix VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN SEMICOLON {
        KSharpMethod m;
        m.returnType = "void";
        m.name = $3;
        m.accessModifier = $1;
        m.isAbstract = isAbstract_flag;
        m.isVirtual = isVirtual_flag;
        m.parameters = temp_params;
        temp_params.clear();
        add_method_to_class(m);
        free($1); free($3);
    }
    | method_prefix IDENTIFIER IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN SEMICOLON {
        KSharpMethod m;
        m.returnType = $2;
        m.name = $3;
        m.accessModifier = $1;
        m.isAbstract = isAbstract_flag;
        m.isVirtual = isVirtual_flag;
        m.parameters = temp_params;
        temp_params.clear();
        add_method_to_class(m);
        free($1); free($2); free($3);
    }
    | method_prefix ABSTRACT VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN SEMICOLON {
        KSharpMethod m;
        m.returnType = "void";
        m.name = $4;
        m.accessModifier = $1;
        m.isAbstract = true;
        m.parameters = temp_params;
        temp_params.clear();
        add_method_to_class(m);
        free($1); free($4);
    }
    | method_prefix ABSTRACT IDENTIFIER IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN SEMICOLON {
        KSharpMethod m;
        m.returnType = $3;
        m.name = $4;
        m.accessModifier = $1;
        m.isAbstract = true;
        m.parameters = temp_params;
        temp_params.clear();
        add_method_to_class(m);
        free($1); free($3); free($4);
    }
    ;


parameter_list:
   | parameter_list_actual
   ;

parameter_list_actual:
    parameter
    | parameter_list_actual COMMA parameter
    ;

parameter:
    IDENTIFIER IDENTIFIER {
        KSharpParameter p;
        p.type = mapParamType($1); // Maps "string" -> "const QString&"
        p.name = $2;
        temp_params.push_back(p); // Temp storage
        std::string mapped = mapType($1);
         if (KSharpPrimitives.count($1) == 0 &&
            mapped != "QString" &&
            mapped != "QChar" &&
            mapped.find("QList") == std::string::npos &&
            mapped != "QStringList") {
            symbolTable[$2] = mapped;
        }
        free($1); free($2);
    }
    ;

property_accessors:
    | property_accessors property_accessor
    ;

property_accessor:
    GET METHOD_BODY {
        currentProp.hasCustomGetter = true;
        currentProp.getterBody = process_body($2);
        free($2);
    }
    | SET METHOD_BODY {
        currentProp.hasCustomSetter = true;
        currentProp.setterBody = process_body($2);
        free($2);
    }
    ;

property_declaration:
     PUBLIC PROPERTY IDENTIFIER IDENTIFIER SEMICOLON {
        KSharpProperty p;
        p.type = $3;
        p.name = $4;
        p.accessModifier = "public";
        parsedClass.properties.push_back(p);
        free($3); free($4);
    }
    | PUBLIC PROPERTY IDENTIFIER IDENTIFIER LBRACE {
       currentProp = KSharpProperty();
        currentProp.type = $3;
        currentProp.name = $4;
        currentProp.accessModifier = "public";
    }  property_accessors RBRACE {
        parsedClass.properties.push_back(currentProp);
        free($3); free($4);
    }
    | access_modifier STATIC PROPERTY IDENTIFIER IDENTIFIER SEMICOLON {
        KSharpProperty p;
        p.type = $4;
        p.name = $5;
        p.isStatic = true;
        p.accessModifier = $1;
        parsedClass.properties.push_back(p);
        free($1); free($4); free($5);
    }
   | PUBLIC PROPERTY IDENTIFIER IDENTIFIER ASSIGN STRING_LITERAL SEMICOLON {
        KSharpProperty p;
        p.type = $3;
        p.name = $4;
        p.accessModifier = "public";
        p.defaultValue = $6;
        parsedClass.properties.push_back(p);
        free($3); free($4); free($6);
    }
    | PUBLIC PROPERTY IDENTIFIER IDENTIFIER ASSIGN NUMBER SEMICOLON {
        KSharpProperty p;
        p.type = $3;
        p.name = $4;
        p.accessModifier = "public";
        p.defaultValue = $6;
        parsedClass.properties.push_back(p);
        free($3); free($4); free($6);
    }
    | PUBLIC PROPERTY IDENTIFIER IDENTIFIER ASSIGN IDENTIFIER SEMICOLON {
        KSharpProperty p;
        p.type = $3;
        p.name = $4;
        p.accessModifier = "public";
        p.defaultValue = $6;
        parsedClass.properties.push_back(p);
        free($3); free($4); free($6);
    }
    ;
%%

void yyerror(const char *s) {
    extern char* yytext; // The token that caused the error
    extern int yylineno; // You may need %option yylineno in lexer
    fprintf(stderr, "[K#]: %s at token '%s' (line %d)\n", s, yytext, yylineno);
}
