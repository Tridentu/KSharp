#include <string>
#include <vector>
#include <map>


struct KSharpSymbol {
    std::string name;
    std::string type;
};

struct KSharpParameter {
    std::string name;
    std::string type;
};

struct KSharpMethod {
    std::string name;
    std::string body;
    bool isSlot = false;
    bool isSignal = false;
    std::string returnType;
    std::string accessModifier;
    std::vector<KSharpParameter> parameters;
};


struct KSharpProperty {
    std::string name;
    std::string type;
    std::string accessModifier;
};

struct KSharpClass {
    std::string name;
    std::string namespaceId;
    std::string accessModifier;
    std::vector<KSharpProperty> properties; // The list for the template
    std::vector<KSharpMethod> methods;
    std::string parentClass = "QObject";
    bool hasCustomConstructor = false;
    std::string constructorBody = "";

};

struct KSharpLib {
    std::string header;
    std::string linkerFlag;
    std::map<std::string, std::string> methodMap;
};


struct KSharpLibMethod {
    std::string cppTranslation;
    std::string requiredHeader;
};

struct KSharpLibType {
    std::string cppType;
    std::string requiredHeader;
};


static const std::string KSSTD_NAMESPACE = "Sys";

std::map<std::string, std::string> ksharp_import_map = {
   {KSSTD_NAMESPACE + ".Application", "QtCore/QCoreApplication"}
};

static const std::map<std::string, std::map<std::string, KSharpLibMethod>> KSharpNamespaceRegistry = {
    { KSSTD_NAMESPACE, {
        { "Console.WriteLine", { "qDebug() << ", "QDebug" } },
        { "Math.Abs",           { "qAbs",         "QtMath" } },
        { "Math.Clamp",         { "qBound",       "QtMath" } }
    }},
    { "System.Tridentu", {
        { "MessageBox.Show",    { "QMessageBox::information", "QMessageBox" } }
    }}
};

static const std::map<std::string, std::map<std::string, KSharpLibType>> KSharpTypeRegistry = {
    { "System", {
        { "List<string>", { "QStringList", "QStringList" } }
    }}
};

static const std::map<std::string, KSharpLib> LibRegistry = {

};

static std::map<std::string, std::string> dynamicTypeMap;

extern std::set<std::string> ksharp_imports;
extern std::vector<KSharpClass> fileClasses;
extern KSharpClass parsedClass;
