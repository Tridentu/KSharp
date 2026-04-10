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

const std::string KSSTD_NAMESPACE = "Sys";

std::map<std::string, std::string> ksharp_import_map = {
   {KSSTD_NAMESPACE + ".Application", "QtCore/QCoreApplication"}
};

extern std::set<std::string> ksharp_imports;
extern std::vector<KSharpClass> fileClasses;
extern KSharpClass parsedClass;
