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


    KAboutData aboutData(
        "{{ projectName }}",
        i18n("{{ projectName }}"),
                         "0.1.0",
                         i18n("A Tridentu Application"),
                         KAboutLicense::GPL
    );
    KAboutData::setApplicationData(aboutData);
    KLocalizedString::setApplicationDomain("{{ projectName }}");
    {{ entryPointBody }}
    return app.exec();
}
