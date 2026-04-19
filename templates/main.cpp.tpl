#include <{{ parentInclude }}>

{%- for cls in allClasses %}
#include "{{ cls }}.h"
{%- endfor %}

{%- for ns in namespaces %}
using namespace {{ ns }};
{%- endfor %}

int main(int argc, char** argv) {
    {{ appType }} app(argc, argv);
    QStringList args = app.arguments();
    {{ entryPointBody }}
    return app.exec();
}
