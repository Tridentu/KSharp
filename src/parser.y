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
#include <nlohmann/json.hpp>
std::vector<KSharpClass> fileClasses;
std::vector<KSharpEnum> fileEnums;
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
int isStatic_flag = 0;

 void save_to_file(const std::string& filename, const std::string& content)
 {
    std::ofstream file(filename);
    if (file.is_open())
    {
        file << content;
        file.close();
        printf("[K#]: %s generated.\n", filename.c_str());
    } else {
        fprintf(stderr, "K# IO Error: could not write to file %s\n", filename.c_str());
    }
 }

std::string mapType(const std::string& ksharpType) {
    // Check primitives first
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
    // If it's a class/container (QString, QList, QStringList), pass by const ref
   if (mapped == "QString" || mapped == "QChar" ||
        mapped.find("List") != std::string::npos) {
        return "const " + mapped + "&";
    }
    return mapped; // int, float, etc. stay as-is
}


// Helper to resolve types
std::string get_class_of(const std::string& varName) {
    if (symbolTable.find(varName) != symbolTable.end()) {
        return symbolTable[varName];
    }
    // Fallback or Error
    return "QObject";
}


std::string finalize_logic(std::string body) {
    // Regex for: identifier.identifier += identifier.identifier;
    // Captures: 1=Sender, 2=Signal, 3=Receiver, 4=Slot
    std::regex connectRegex(R"(([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\s*\+=\s*([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+);)");

    std::string result = std::regex_replace(body, connectRegex,
        "QObject::connect($1, &$1_TYPE::$2, $3, &$3_TYPE::$4);");

    // Note: To get the actual TYPE in there, you'd iterate matches and
    // query your get_class_of() function for each $1 and $3 found.

    return result;
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

    for (const std::string& import : activeImports) {
        // Check if this imported namespace exists in our registry
        if (KSharpNamespaceRegistry.count(import)) {
            const auto& availableMethods = KSharpNamespaceRegistry.at(import);

            for (auto const& [kMethod, data] : availableMethods) {
                size_t pos = 0;
                while ((pos = body.find(kMethod, pos)) != std::string::npos) {
                    // Only replace if it matches the namespace the user actually imported
                    body.replace(pos, kMethod.length(), data.cppTranslation);

                    auto_includes.insert(data.requiredHeader);
                    pos += data.cppTranslation.length();
                }
            }
        }
    }
    return body;
}


std::string process_body(std::string body) {
    size_t pos = 0;
    while ((pos = body.find("this.", pos)) != std::string::npos) {
        body.replace(pos, 5, "this->");
        pos += 6;
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

    std::regex declRegex(R"(([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+)\s*=\s*new\s+([a-zA-Z0-9_]+)\((.*)\);)");
    std::string result = "";
    auto words_begin = std::sregex_iterator(body.begin(), body.end(), declRegex);
    auto words_end = std::sregex_iterator();
    size_t lastPos = 0;

    for (std::sregex_iterator i = words_begin; i != words_end; ++i) {
        std::smatch match = *i;
        std::string type = match.str(1);
        std::string name = match.str(2);
        std::string args = match.str(4);

        // Update the table so the += connection logic below knows the types!
        symbolTable[name] = type;
        std::string heapAlloc = type + "* " + name + " = new " + type + "(";

        // Inject 'this' as the first argument if it's a QObject type
        if (args.empty()) {
            heapAlloc += "this";
        } else {
            heapAlloc += "this, " + args;
        }
        heapAlloc += ");";

        result += body.substr(lastPos, match.position() - lastPos); // passthrough text
        result += heapAlloc;
        lastPos = match.position() + match.length();
    }
    std::regex connectRegex(R"(([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\s*\+=\s*([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+);)");
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
    result += body.substr(lastPos);
    return result;
}

void add_method_to_class(KSharpMethod m) {
    if (m.name == parsedClass.name) {
        parsedClass.hasCustomConstructor = true;
        // We still process the body to handle 'this.' and connections
        parsedClass.constructorBody = process_body(m.body);
    } else {
        m.body = process_body(m.body);
        parsedClass.methods.push_back(m);
    }
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
    ctx["modifier"] = cls.accessModifier;
    ctx["namespaceName"] = ns;
    ctx["existingConstructorBody"] = cls.hasCustomConstructor;
    ctx["constructorBody"] = cls.constructorBody;

    ctx["properties"] = nlohmann::json::array();
    for (const auto& prop : cls.properties) {
        nlohmann::json p;
        p["name"] = prop.name;
        p["type"] = mapType(prop.type);
        p["paramType"] = mapParamType(prop.type);
        p["hasCustomGetter"] = prop.hasCustomGetter;
        p["hasCustomSetter"] = prop.hasCustomSetter;
        p["getterBody"] = prop.getterBody;
        p["setterBody"] = prop.setterBody;
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
        m["body"] = apply_namespaced_libraries(method.body, ksharp_imports, header_includes);
        m["body"] = process_body(m["body"]);
        m["accessModifier"] = method.accessModifier;
        m["isSlot"] = method.isSlot;
        m["isSignal"] = method.isSignal;
        m["isStatic"] = method.isStatic;
        m["parameters"] = nlohmann::json::array();
        for (const auto& p : method.parameters) {
            nlohmann::json param;
            param["name"] = p.name;
            // Map parameter 'string' to 'const QString&'
            param["type"] = mapParamType(p.type);
            m["parameters"].push_back(param);
        }
        if (method.isSignal) {
            ctx["signals"].push_back(m);
        } else if (method.isSlot) {
            ctx["slots"].push_back(m);
        } else {
            ctx["methods"].push_back(m);
        }
    }
    std::set<std::string> filtered_includes;
    for (const auto& inc : header_includes) {
        if (ksharp_import_map.count(inc) == 0 &&
            KSharpNamespaceRegistry.count(inc) == 0) {
            filtered_includes.insert(inc);
        }
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

    ctx["enums"] = nlohmann::json::array();
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

%}

%union {
    char *sval;
}


%token <sval> IDENTIFIER METHOD_BODY NUMBER

%type <sval> access_modifier method_prefix

%token NAMESPACE CLASS PUBLIC PROPERTY SET GET  LBRACE RBRACE SEMICOLON DOT

%token VOID LBRACE_PAREN RBRACE_PAREN COMMA SLOT SIGNAL COLON L_ANGLE R_ANGLE

%token USING PLUS_EQUAL ASSIGN NEW PRIVATE PROTECTED

%token ENUM STATIC

%%
program:
    prog_elements {
        for (auto& cls: fileClasses) {
            generate_cpp_class(cls);
        }
    }
    ;

prog_elements:
    | prog_elements using_statement
    | prog_elements namespace_definition
    | prog_elements class_declaration
    | prog_elements enum_declaration
    ;

namespace_definition:
    NAMESPACE IDENTIFIER  {
        currentNamespaceId = $2;
        free($2);
    } LBRACE prog_elements RBRACE {
        currentNamespaceId = "";
    }
    ;

using_statement:
    USING IDENTIFIER SEMICOLON {
        ksharp_imports.insert(mapImport($2));
        free($2);
    }
    ;

inheritance_opt:
    COLON IDENTIFIER {
        parsedClass.parentClass = $2;
        free($2);
    }
    | {

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
    access_modifier           { $$ = strdup($1); isStatic_flag = 0; free($1); }
    | access_modifier STATIC  { $$ = strdup($1); isStatic_flag = 1; free($1); }
    ;

class_declaration:
    method_prefix CLASS IDENTIFIER inheritance_opt LBRACE {
        // Prepare a new class context
        parsedClass = KSharpClass();
        parsedClass.name = $3;
        parsedClass.namespaceId = currentNamespaceId;
        parsedClass.accessModifier = $1;
        parsedClass.parentClass = parsedClass.parentClass.empty() ? "QObject" : parsedClass.parentClass;
    } class_body RBRACE {
        printf("Generating Qt/KDE C++ for class: %s\n", $3);
        fileClasses.push_back(parsedClass);
        free($1); free($3);
    }
    ;

class_body:
    | class_body member_declaration
    ;

member_declaration:
    property_declaration
    | method_declaration
    | signal_declaration
    | enum_declaration
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
    method_prefix SLOT IDENTIFIER IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN { capture_mode = 1; } METHOD_BODY {
        KSharpMethod m;
        m.returnType = $3;
        m.name = $4;
        m.isSlot = true; // Mark as slot
        m.body = $9;
        m.parameters = temp_params;
        m.isStatic = isStatic_flag;
        m.accessModifier = $1;
        add_method_to_class(m);
        temp_params.clear();
        free($1); free($3); free($4); free($9);
    }
    | method_prefix SLOT VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN { capture_mode = 1; } METHOD_BODY {
        KSharpMethod m;
        m.returnType = "void";
        m.name = $4;
        m.isSlot = true; // Mark as slot
        m.body = $9;
        m.parameters = temp_params;
        m.accessModifier = $1;
        m.isStatic = isStatic_flag;
        add_method_to_class(m);
        temp_params.clear();
        free($1); free($4); free($9);
    }
    | method_prefix VOID IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN { capture_mode = 1; } METHOD_BODY {
        KSharpMethod m;
        m.returnType = "void";
        m.name = $3;
        m.body = $8;
        m.isSlot = false; // Or handle slot logic here if needed
        m.accessModifier = $1;
        m.parameters = temp_params;
        add_method_to_class(m);
        m.isStatic = isStatic_flag;
        temp_params.clear();
        free($1); free($3); free($8);
    }
    | method_prefix IDENTIFIER IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN { capture_mode = 1; } METHOD_BODY {
        KSharpMethod m;
        m.returnType = $2;
        m.name = $3;
        m.parameters = temp_params;
        m.body = $8;
        m.accessModifier = $1;
        m.isStatic = isStatic_flag;
        add_method_to_class(m);
        temp_params.clear(); // Clear for the next method
        free($1); free($2); free($3); free($8);
    }
    | method_prefix IDENTIFIER LBRACE_PAREN parameter_list RBRACE_PAREN { capture_mode = 1; } METHOD_BODY {
        KSharpMethod m;
        m.name = $2;
        m.returnType = ""; // No return type implies constructor or error
        m.body = $7;
        m.accessModifier = $1;
        m.parameters = temp_params;
        m.isStatic = isStatic_flag;  // move BEFORE add_method_to_class(m)
        add_method_to_class(m);
        temp_params.clear();
        free($1); free($2); free($7);
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
        free($1); free($2);
    }
    ;

property_accessors:
    | property_accessors property_accessor
    ;

property_accessor:
    GET { capture_mode = 1; } METHOD_BODY {
        currentProp.hasCustomGetter = true;
        currentProp.getterBody = process_body($3);
        free($3);
    }
    | SET { capture_mode = 1; } METHOD_BODY {
        currentProp.hasCustomSetter = true;
        currentProp.setterBody = process_body($3);
        free($3);
    }
    ;

property_declaration:
     PUBLIC PROPERTY IDENTIFIER IDENTIFIER SEMICOLON {
        KSharpProperty p;
        p.type = $3;
        p.name = $4;
        p.accessModifier = "public";
        symbolTable[$4] = mapType($3);
        parsedClass.properties.push_back(p);
        free($3); free($4);
    }
    | PUBLIC PROPERTY IDENTIFIER IDENTIFIER LBRACE {
       currentProp = KSharpProperty();
        currentProp.type = $3;
        currentProp.name = $4;
        currentProp.accessModifier = "public";
        symbolTable[$4] = mapType($3);
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
        symbolTable[$5] = mapType($4);
        parsedClass.properties.push_back(p);
        free($1); free($4); free($5);
    }
    ;
%%

void yyerror(const char *s) {
    extern char* yytext; // The token that caused the error
    extern int yylineno; // You may need %option yylineno in lexer
    fprintf(stderr, "K# Syntax Error: %s at token '%s' (line %d)\n", s, yytext, yylineno);
}
