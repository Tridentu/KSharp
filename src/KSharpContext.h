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
    std::string defaultValue = "";
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
    std::string preamble = "";
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
        { "Console.WriteLine", { "qDebug() << ", "QDebug", "" } },
        { "Console.Write",     { "qDebug().nospace() << ","QDebug",     "" } },
        { "Console.ReadLine", { "_ks_stdin.readLine()", "QTextStream", "QTextStream _ks_stdin(stdin);" } },
        { "Console.Error",     { "qCritical() << ",      "QDebug",      "" } },
        { "Math.Abs",   { "qAbs",       "QtMath", "" } },
        { "Math.Clamp", { "qBound",     "QtMath", "" } },
        { "Math.Min",   { "qMin",       "QtMath", "" } },
        { "Math.Max",   { "qMax",       "QtMath", "" } },
        { "Math.Floor", { "qFloor",     "QtMath", "" } },
        { "Math.Ceil",  { "qCeil",      "QtMath", "" } },
        { "Math.Sqrt",  { "qSqrt",      "QtMath", "" } },
        { "Math.Pow",   { "qPow",       "QtMath", "" } },
        { "String.IsNullOrEmpty", { "QString::isEmpty", "QString", "" } },
        { "String.Join",          { "QStringList::join","QString", "" } },
        { "String.Format",        { "QString::asprintf","QString", "" } },
        { "Environment.Exit",        { "QCoreApplication::exit",          "QCoreApplication", "" } },
        { "Environment.GetVariable", { "qEnvironmentVariable", "QtCore", "" } },
    }},
    { KSSTD_NAMESPACE + ".IO", {
        { "File.Exists",      { "QFile::exists",   "QFile", "" } },
        { "File.Delete",      { "QFile::remove",   "QFile", "" } },
        { "Directory.Exists", { "QDir::exists",    "QDir",  "" } },
        { "Directory.Create", { "QDir().mkpath",   "QDir",  "" } },
        { "Path.Combine",     { "QDir::cleanPath", "QDir",  "" } },
    }},
    { KSSTD_NAMESPACE + ".Tridentu", {
        { "MessageBox.Show",     { "QMessageBox::information", "QMessageBox", "" } },
        { "MessageBox.Warning",  { "QMessageBox::warning",     "QMessageBox", "" } },
        { "MessageBox.Critical", { "QMessageBox::critical",    "QMessageBox", "" } },
        { "MessageBox.Question", { "QMessageBox::question",    "QMessageBox", "" } },
    }}
};

static const std::map<std::string, std::map<std::string, KSharpLibType>> KSharpTypeRegistry = {
    { KSSTD_NAMESPACE, {
        { "List<string>",              { "QStringList",          "QStringList" } },
        { "Dictionary<string,string>", { "QMap<QString,QString>","QMap"        } },
        { "Dictionary<string,int>",    { "QMap<QString,int>",    "QMap"        } },
        { "HashSet<string>",           { "QSet<QString>",        "QSet"        } },
        { "HashSet<int>",              { "QSet<int>",            "QSet"        } },
        { "Vector<string>", { "QList<QString>", "QList" } },
    }},
    { KSSTD_NAMESPACE + ".Application", {
        { "ConsoleApplication", {"QCoreApplication", "QtCore/QCoreApplication" }},
        { "GuiApplication",    { "QGuiApplication", "QtGui/QGuiApplication"       } },
        { "TridentuApplication", { "QApplication", "QtWidgets/QApplication" } },
    }},
    { KSSTD_NAMESPACE + ".Tridentu.UI", {
        { "MainWindow",   { "QMainWindow",   "QtWidgets/QMainWindow"  } },
        { "KDEWindow",    { "KXmlGuiWindow", "KXmlGuiWindow"  } },
        { "Dialog",       { "QDialog",       "QtWidgets/QDialog"      } },
        { "Widget",       { "QWidget",       "QtWidgets/QWidget"      } },
        { "DockWidget",   { "QDockWidget",   "QtWidgets/QDockWidget"  } },
        { "Label",        { "QLabel",        "QtWidgets/QLabel"       } },
        { "PushButton",   { "QPushButton",   "QtWidgets/QPushButton"  } },
        { "LineEdit",     { "QLineEdit",     "QtWidgets/QLineEdit"    } },
        { "TextEdit",     { "QTextEdit",     "QtWidgets/QTextEdit"    } },
        { "ComboBox",     { "QComboBox",     "QtWidgets/QComboBox"    } },
        { "CheckBox",     { "QCheckBox",     "QtWidgets/QCheckBox"    } },
        { "RadioButton",  { "QRadioButton",  "QtWidgets/QRadioButton" } },
        { "Slider",       { "QSlider",       "QtWidgets/QSlider"      } },
        { "SpinBox",      { "QSpinBox",      "QtWidgets/QSpinBox"     } },
        { "VBoxLayout",   { "QVBoxLayout",   "QtWidgets/QVBoxLayout"  } },
        { "HBoxLayout",   { "QHBoxLayout",   "QtWidgets/QHBoxLayout"  } },
        { "GridLayout",   { "QGridLayout",   "QtWidgets/QGridLayout"  } },
    }}
};

static const std::map<std::string, std::string> KSharpExceptionRegistry = {
    { "Exception",            "std::exception"              },
    { "ArgumentException",    "std::invalid_argument"       },
    { "NullReferenceException","std::runtime_error"         },
    { "IOException",          "std::ios_base::failure"      },
    { "OverflowException",    "std::overflow_error"         },
    { "NotImplementedException","std::logic_error"          },
};

static const std::set<std::string> KSharpAppEntryTypes = {
    "TridentuApplication",
    "QApplication"
};

static const std::set<std::string> KSharpTridentuAppTypes = {
    "TridentuApplication",
    "QApplication",
    "KXmlGuiWindow",
    "QMainWindow",
    "KPageDialog",
    "QWidget",
    "QDockWidget"
};


static const std::set<std::string> KF6Types = {
    "TridentuApplication",
    "QApplication",
    "KXmlGuiWindow",
    "QMainWindow",
    "KPageDialog",
};


static const std::map<std::string, KSharpLib> KSharpLibRegistry = {

};
static const std::set<std::string> KSharpWidgetBases = {
    "KXmlGuiWindow", "KPageDialog", "QMainWindow",
    "QDialog", "QWidget", "QDockWidget",
    "QLabel", "QPushButton", "QLineEdit",
    "QTextEdit", "QComboBox", "QCheckBox",
    "QRadioButton", "QSlider", "QSpinBox",
    "QVBoxLayout", "QHBoxLayout", "QGridLayout"
};


static const std::set<std::string> KSharpValueTypes = {
    "QString", "QChar", "QList", "QMap", "QSet",
    "QStringList", "QVector", "QHash", "QVariant",
    "int", "float", "double", "bool", "char"
};

static const std::set<std::string> KSharpLayoutTypes = {
    "QVBoxLayout", "QHBoxLayout", "QGridLayout"
};

static std::map<std::string, std::map<std::string, std::string>> KSharpSignalMap = {
    { "QPushButton", {
        { "clicked",  "clicked" },
        { "pressed",  "pressed" },
        { "released", "released" },
    }},
    { "QLineEdit", {
        { "textChanged",    "textChanged" },
        { "returnPressed",  "returnPressed" },
        { "editingFinished","editingFinished" },
    }},
    { "QCheckBox", {
        { "toggled",        "toggled" },
        { "stateChanged",   "stateChanged" },
    }},
    { "QSlider", {
        { "valueChanged",   "valueChanged" },
        { "sliderMoved",    "sliderMoved" },
    }},
    { "QComboBox", {
        { "currentIndexChanged", "currentIndexChanged" },
        { "currentTextChanged",  "currentTextChanged" },
    }},
    { "QSpinBox", {
        { "valueChanged", "valueChanged" },
    }},
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

