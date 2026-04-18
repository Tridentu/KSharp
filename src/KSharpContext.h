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
    bool isStatic = false;
    bool isAbstract = false;
    bool isOverride = false;
    bool isVirtual = false;
    std::string returnType;
    std::string accessModifier;
    std::vector<KSharpParameter> parameters;
};

struct KSharpEnumValue {
    std::string name;
    bool hasExplicitValue = false;
    int explicitValue = 0;
};

struct KSharpEnum {
    std::string name;
    std::string namespaceId;
    std::vector<KSharpEnumValue> values;
};

struct KSharpProperty {
    std::string name;
    std::string type;
    std::string accessModifier;
    std::string getterBody;
    std::string setterBody;
    bool hasCustomGetter = false;
    bool hasCustomSetter = false;
    bool isStatic = false;
};

struct KSharpInterface {
    std::string name;
    std::string namespaceId;
    std::string accessModifier;
    std::vector<KSharpMethod> methods;
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
    bool isAbstract = false;
    std::string entryPointBody = "";

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

};

static const std::map<std::string, std::string> KSharpPrimitives = {
    {"string", "QString"},
    {"int", "int"},
    {"bool", "bool"},
    {"double", "double"},
    {"float", "float"},
    {"char", "QChar"}

};

static const std::map<std::string, std::map<std::string, KSharpLibMethod>> KSharpNamespaceRegistry = {
    { KSSTD_NAMESPACE, {
        { "Console.WriteLine", { "qDebug() << ", "QDebug" } },
        { "Math.Abs",           { "qAbs",         "QtMath" } },
        { "Math.Clamp",         { "qBound",       "QtMath" } }
    }},
    { KSSTD_NAMESPACE + ".Tridentu", {
        { "MessageBox.Show",    { "QMessageBox::information", "QMessageBox" } }
    }}
};

static const std::map<std::string, std::map<std::string, KSharpLibType>> KSharpTypeRegistry = {
    { KSSTD_NAMESPACE, {
        { "List<string>", { "QStringList", "QStringList" } }
    }},
    { KSSTD_NAMESPACE + ".Application", {
        { "ConsoleApplication", {"QCoreApplication", "QtCore/QCoreApplication" }}
    }}
};


static const std::map<std::string, KSharpLib> KSharpLibRegistry = {

};

extern std::map<std::string, std::string> dynamicTypeMap;

extern std::set<std::string> ksharp_imports;
extern std::vector<KSharpClass> fileClasses;
extern std::vector<KSharpEnum> fileEnums;
extern std::vector<KSharpInterface> fileInterfaces;
extern std::set<std::string> ksharp_active_namespaces;
extern KSharpClass parsedClass;
extern KSharpProperty currentProp;
extern KSharpEnum currentEnum;
extern KSharpInterface currentInterface;

