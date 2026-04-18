#include <QCoreApplication>
#include <QCommandLineParser>
#include <QFile>
#include <QDebug>
#include <cstdio>
#include <QFileInfo>

#include "KSharpParser.h"
extern FILE *yyin;
extern int yyparse();
extern void yyrestart(FILE*);
std::string projectName;
extern void reset_parser_state();


int main(int argc, char** argv){
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName("K# Compiler");
    QCoreApplication::setApplicationVersion("0.1.0");

    QCommandLineParser parserCmd;
    parserCmd.setApplicationDescription("ksharpc - The K# Compiler");
    parserCmd.addHelpOption();
    parserCmd.addVersionOption();
    parserCmd.addPositionalArgument("source", "One or more .kshp source files to compile");

    parserCmd.process(app);

    const QStringList args = parserCmd.positionalArguments();
    if (args.isEmpty()) {
        qCritical() << "K# Command Error: No input file specified.";
        parserCmd.showHelp(1);
    }

    QString firstName = args.at(0);
    firstName = QFileInfo(firstName).baseName();
    extern std::string projectName;
    projectName = firstName.toStdString();

    for (const QString& fileName : args) {
        if (!fileName.endsWith(".kshp", Qt::CaseInsensitive)) {
            qCritical() << "K# Command Error: Input file must have a .kshp extension:" << fileName;
            return 1;
        }

        QFile file(fileName);
        if (!file.open(QIODevice::ReadOnly)) {
            qCritical() << "K# Command Error: Could not open file" << fileName;
            return 1;
        }

        FILE *myfile = fdopen(file.handle(), "r");
        if (!myfile) {
            qCritical() << "K# Command Error: Failed to map file descriptor for" << fileName;
            return 1;
        }

        qInfo() << "[K#]: Compiling" << fileName;

        yyrestart(myfile);
        yyin = myfile;

        int result = yyparse();
        file.close();

        if (result != 0) {
            qCritical() << "K# Command Error: Compilation failed for" << fileName;
            return result;
        }

        reset_parser_state();

    }

    qInfo() << "[K#]: Compilation successful.";

    return 0;

}
