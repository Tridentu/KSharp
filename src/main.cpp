#include <QCoreApplication>
#include <QCommandLineParser>
#include <QFile>
#include <QDebug>
#include <cstdio>

#include "KSharpParser.h"
extern FILE *yyin;
extern int yyparse();


int main(int argc, char** argv){
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName("K# Compiler");
    QCoreApplication::setApplicationVersion("0.1.0");

    QCommandLineParser parserCmd;
    parserCmd.setApplicationDescription("K# Compiler");
    parserCmd.addHelpOption();
    parserCmd.addVersionOption();
    parserCmd.addPositionalArgument("source", "The .kshp source file to compile");

    parserCmd.process(app);

    const QStringList args = parserCmd.positionalArguments();
    if (args.isEmpty()) {
        qCritical() << "K# Command Error: No input file specified.";
        parserCmd.showHelp(1);
    }

    QString fileName = args.at(0);
    if (!fileName.endsWith(".kshp", Qt::CaseInsensitive)) {
        qCritical() << "K# Command Error: Input file must have a .kshp extension.";
        return 1;
    }

    QFile file(fileName);

    if (!file.open(QIODevice::ReadOnly)) {
        qCritical() << "K# Command Error: Could not open file" << fileName;
        return 1;
    }

    FILE *myfile = fdopen(file.handle(), "r");
    if (!myfile) {
        qCritical() << "K# Command Error: Failed to map file descriptor.";
        return 1;
    }

    yyin = myfile;

    int result = yyparse();

    // QFile will close the handle when it goes out of scope,
    // but it's good practice to be explicit.
    file.close();

    return result;

}
