#include <QApplication>
#include <KAboutData>
#include <KLocalizedString>
{%- for cls in allClasses %}
#include "{{ cls }}.h"
{%- endfor %}

#include "{{ className }}.h"

{%- for ns in namespaces %}
using namespace {{ ns }};
{%- endfor %}


int main(int argc, char** argv) {
    QApplication app(argc, argv);

    KAboutData aboutData(
        "{{ projectName }}",
        i18n("{{ projectName }}"),
        "0.1.0",
        i18n("A Tridentu Application"),
        KAboutLicense::GPL
    );
    KAboutData::setApplicationData(aboutData);

    QStringList args = app.arguments();
    {{ entryPointBody }}
    return app.exec();
}
