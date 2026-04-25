# The K# Language

## Overview

K# (KSharp) is a C#-inspired language that compiles to Qt/KDE C++. It is the native language of the Tridentu 2 Linux platform, designed for writing Qt and KDE applications with familiar C#-style syntax.


---

## Building the Compiler
 
### Dependencies
 
- CMake 3.16+
- Qt6 (Core, Widgets)
- Flex
- Bison 3.x
- [Inja](https://github.com/pantor/inja) (C++ template engine)
- [nlohmann/json](https://github.com/nlohmann/json)
- KDE Frameworks 6 (CoreAddons, I18n, XmlGui) — for KDE app support
### Build Steps
 
```bash
git clone https://github.com/Tridentu/KSharp
cd KSharp
cmake -B build -S .
cmake --build build
```
 
The compiler binary will be at `build/ksharpc`.
 
---

 
## Compiler Usage
 
```bash
ksharpc source.kshp              # Compile only
ksharpc source.kshp --build      # Compile and build with CMake
ksharpc source.kshp --run        # Compile, build, and run
ksharpc source.kshp --reconfigure # Force CMake reconfiguration

```

K# Source files use the `.kshp` extension. The C++ Output is written to a directory named after the first source file's base name.
 
---

## Syntax Highlighting
 
K# syntax highlighting is available for Kate, KWrite, and any editor using KSyntaxHighlighting (including KDevelop).
 
Install the syntax definition:
 
```bash
mkdir -p ~/.local/share/org.kde.syntax-highlighting/syntax/
cp ksharp.xml ~/.local/share/org.kde.syntax-highlighting/syntax/
```
 
Restart Kate and open any `.kshp` file — K# will appear under **Tools → Highlighting → Sources**.
 
---

 
## Program Structure
 
A K# program consists of one or more `.kshp` files, each containing namespaces, classes, interfaces, and enums.
 
```csharp
using Sys;
using Sys.Application;
 
namespace MyApp {
    public class MyProgram : ConsoleApplication {
        public static void Main(string[] args) {
            Console.WriteLine("Hello from K#!");
        }
    }
}
```
 
---
 
## Namespaces
 
Namespaces group related classes together and map to C++ namespaces.
 
```csharp
namespace MyApp {
    // classes, enums, interfaces
}
```
 
Dotted namespaces are supported and map to nested `::` in C++:
 
```csharp
namespace MyApp.Core {
    // ...
}
```
 
---
 
## Using Statements
 
Import K# standard library namespaces with `using`:
 
```csharp
using Sys;                  // Core standard library
using Sys.IO;               // File system
using Sys.Application;      // Application entry point types
using Sys.Tridentu;         // Tridentu platform APIs
using Sys.Tridentu.UI;      // UI widgets and windows
```
 
---

## Classes
 
Classes compile to Qt C++ classes inheriting from `QObject` by default.
 
```csharp
public class MyClass {
    // ...
}
```
 
With inheritance:
 
```csharp
public class MyClass : ParentClass {
    // ...
}
```
 
### Constructors
 
Constructors are declared with the same name as the class and no return type:
 
```csharp
public class MyClass {
    public MyClass() {
        // constructor body
    }
}
```
 
### Abstract Classes
 
```csharp
public abstract class MyAbstractClass {
    public abstract void DoSomething();
}
```
 
---
 
## Access Modifiers
 
| K# | C++ |
|---|---|
| `public` | `public` |
| `private` | `private` |
| `protected` | `protected` |
 
---

## Properties
 
Properties compile to Qt's `Q_PROPERTY` with getter, setter, and change signal.
 
```csharp
public property int Health;
public property string Name = "Player";  // with default value
public property List<string> Items;
```
 
Properties with custom accessors:
 
```csharp
public property int Health {
    get { return m_Health; }
    set { m_Health = value; emit HealthChanged(value); }
}
```
 
Static properties:
 
```csharp
public static property int Count;
```
 
---

## Methods
 
```csharp
public void DoSomething() {
    // body
}
 
public string GetName() {
    return this.Name;
}
 
public static void StaticMethod() {
    // no this access
}
```
 
Method modifiers:
 
```csharp
public virtual void CanOverride() { }
public override void Overridden() { }
public abstract void MustImplement();
```
 
---

## Signals and Slots
 
Signals are Qt signals — they are emitted automatically when called:
 
```csharp
public signal void PlayerDied();
public signal void Damaged(int amount);
```
 
Slots are Qt slots:
 
```csharp
public slot void TakeDamage(int amount) {
    this.Health -= amount;
    Damaged(amount);
}
```
 
The compiler automatically injects `emit` before signal calls.
 
---

## Connecting Signals
 
### K# signal to K# slot
 
```csharp
sender.SignalName += receiver.SlotName;
```
 
### Native Qt signal to K# slot
 
Uses C#-style `+=` with the property and signal name:
 
```csharp
this.Button.clicked += this.OnButtonClicked;
```
 
The compiler looks up the property type and generates the correct `QObject::connect` call.
 
---

## Built-in Types
 
| K# | C++ |
|---|---|
| `string` | `QString` |
| `int` | `int` |
| `float` | `float` |
| `double` | `double` |
| `bool` | `bool` |
| `char` | `QChar` |
| `void` | `void` |
| `var` | `auto` |
 
## Collection Types
 
| K# | C++ |
|---|---|
| `List<string>` | `QStringList` |
| `List<T>` | `QList<T>` |
| `Dictionary<K,V>` | `QMap<K,V>` |
| `HashSet<T>` | `QSet<T>` |
 
---

## Control Flow
 
Standard K#/C# control flow passes through verbatim:
 
```csharp
if (condition) { }
else { }
 
while (condition) { }
 
for (int i = 0; i < 10; i++) { }
 
foreach (string item in this.Items) {
    Console.WriteLine(item);
}
 
switch (value) {
    case 1: break;
}
 
try {
    // ...
} catch (Exception e) {
    Console.Error(e.Message);
}
```
 
---
 
## String Interpolation
 
```csharp
Console.WriteLine($"Hello {this.Name}, you have {count} items.");
```
 
Compiles to `QString::arg()` chains.
 
---

## Type Checking
 
```csharp
if (obj is MyClass) { }
MyClass c = obj as MyClass;
```
 
Compiles to `dynamic_cast`.
 
---

## Null
 
```csharp
if (obj == null) { }
```
 
Compiles to `nullptr`.
 
---
# Object Creation
 
```csharp
// QObject subclass — heap allocated with parent
MyClass obj = new MyClass();
 
// Widget — heap allocated, parent injected correctly
PushButton btn = new PushButton("Click Me");
 
// Value type — stack allocated
var name = new QString("Hello");
```
 
---
 
## Enums
 
```csharp
public enum PlayerState {
    Idle = 0,
    Walking = 2,
    Running = 4,
    Dead = 6
}
```
 
Compiles to C++ `enum class`.
 
---

## Interfaces
 
```csharp
public interface IDrawable {
    void Draw();
    string GetName();
}
```
 
Compiles to a C++ abstract class with pure virtual methods.
 
---

## Standard Library
 
### `Sys` (using Sys)
 
| K# | Qt equivalent |
|---|---|
| `Console.WriteLine(x)` | `qDebug() << x` |
| `Console.Write(x)` | `qDebug().nospace() << x` |
| `Console.ReadLine()` | `QTextStream` stdin read |
| `Console.Error(x)` | `qCritical() << x` |
| `Math.Abs(x)` | `qAbs(x)` |
| `Math.Min(a,b)` | `qMin(a,b)` |
| `Math.Max(a,b)` | `qMax(a,b)` |
| `Math.Floor(x)` | `qFloor(x)` |
| `Math.Ceil(x)` | `qCeil(x)` |
| `Math.Sqrt(x)` | `qSqrt(x)` |
| `Math.Pow(x,y)` | `qPow(x,y)` |
| `Math.Clamp(x,a,b)` | `qBound(a,x,b)` |
| `Environment.Exit(code)` | `QCoreApplication::exit(code)` |
| `Environment.GetVariable(name)` | `qEnvironmentVariable(name)` |
 
### `Sys.IO` (using Sys.IO)
 
| K# | Qt equivalent |
|---|---|
| `File.Exists(path)` | `QFile::exists(path)` |
| `File.Delete(path)` | `QFile::remove(path)` |
| `Directory.Exists(path)` | `QDir::exists(path)` |
| `Directory.Create(path)` | `QDir().mkpath(path)` |
 
### `Sys.Tridentu` (using Sys.Tridentu)
 
| K# | Qt equivalent |
|---|---|
| `MessageBox.Show(p,t,m)` | `QMessageBox::information(p,t,m)` |
| `MessageBox.Warning(p,t,m)` | `QMessageBox::warning(p,t,m)` |
| `MessageBox.Critical(p,t,m)` | `QMessageBox::critical(p,t,m)` |
| `MessageBox.Question(p,t,m)` | `QMessageBox::question(p,t,m)` |
 
---
 
## Application Types (`using Sys.Application`)
 
| K# | Qt equivalent | Use case |
|---|---|---|
| `ConsoleApplication` | `QCoreApplication` | Console apps |
| `GuiApplication` | `QGuiApplication` | GUI without widgets |
| `WidgetApplication` | `QApplication` | Widget-based apps |
| `TridentuApplication` | `QApplication` + KAboutData | Tridentu/KDE apps |
 
---
 
## UI Types (`using Sys.Tridentu.UI`)
 
### Window and Container Types
 
| K# | Qt/KDE equivalent |
|---|---|
| `MainWindow` | `QMainWindow` |
| `KDEWindow` | `KXmlGuiWindow` |
| `Dialog` | `QDialog` |
| `Widget` | `QWidget` |
| `DockWidget` | `QDockWidget` |
 
### Widget Types
 
| K# | Qt equivalent |
|---|---|
| `Label` | `QLabel` |
| `PushButton` | `QPushButton` |
| `LineEdit` | `QLineEdit` |
| `TextEdit` | `QTextEdit` |
| `ComboBox` | `QComboBox` |
| `CheckBox` | `QCheckBox` |
| `RadioButton` | `QRadioButton` |
| `Slider` | `QSlider` |
| `SpinBox` | `QSpinBox` |
 
### Layout Types
 
| K# | Qt equivalent |
|---|---|
| `VBoxLayout` | `QVBoxLayout` |
| `HBoxLayout` | `QHBoxLayout` |
| `GridLayout` | `QGridLayout` |
 
---
 
## Native Qt Signal Map
 
When connecting native Qt signals via `+=`, the following signals are recognized:
 
| Widget | Signals |
|---|---|
| `PushButton` | `clicked`, `pressed`, `released` |
| `LineEdit` | `textChanged`, `returnPressed`, `editingFinished` |
| `CheckBox` | `toggled`, `stateChanged` |
| `Slider` | `valueChanged`, `sliderMoved` |
| `ComboBox` | `currentIndexChanged`, `currentTextChanged` |
| `SpinBox` | `valueChanged` |
 
---
 
## Complete Example — Console Application
 
```csharp
using Sys;
using Sys.Application;
 
namespace MyApp {
    public class Program : ConsoleApplication {
        public static void Main(string[] args) {
            Console.WriteLine($"Hello from K#! Args: {args}");
        }
    }
}
```
 
## Complete Example — GUI Application
 
```csharp
using Sys;
using Sys.Application;
using Sys.Tridentu.UI;
 
namespace MyApp {
    public class MyWindow : MainWindow {
        public property Label Title;
        public property PushButton ClickMe;
        public property VBoxLayout Layout;
        public property Widget Container;
 
        public MyWindow() {
            this.Container = new Widget();
            this.Title = new Label("Hello from K#!");
            this.ClickMe = new PushButton("Click Me");
            this.Layout = new VBoxLayout(this.Container);
            this.Layout.addWidget(this.Title);
            this.Layout.addWidget(this.ClickMe);
            this.setCentralWidget(this.Container);
            this.resize(400, 300);
            this.ClickMe.clicked += this.OnClicked;
        }
 
        public void OnClicked() {
            Console.WriteLine("Button clicked!");
        }
    }
 
    public class App : TridentuApplication {
        public static void Main(string[] args) {
            MyWindow window = new MyWindow();
            window.show();
        }
    }
}
```

If you want to view these examples in file form, look in the ```examples``` folder.
 
---

## Known Limitations
 
- No inline expression parsing — complex expressions in `new` calls may not translate correctly
- No multi-file namespace merging — classes across files in the same namespace don't share type information
- No generics — K# types cannot be parameterized beyond the built-in collection types
- No lambda expressions or anonymous functions
- No `async`/`await`
- File I/O (`File.Read`, `File.Write`) requires manual `QFile` usage for now
- `Path.Combine` is not supported due to argument structure differences
- `String.Format` is not supported — use string interpolation `$"..."` instead

---

## Licensing

K# is dual-licensed:
- The K# language specification and standard library are licensed under [LICENSE]
- The `ksharpc` compiler is licensed under [LICENSE-COMPILER]

---
