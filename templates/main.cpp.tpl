#include <{{ parentInclude }}>
#include "{{ className }}.h"

int main(int argc, char** argv) {
    {{ appType }} app(argc, argv);
    QStringList args = app.arguments();
    {{ entryPointBody }}
    return app.exec();
}
