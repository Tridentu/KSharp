#include <QCoreApplication>
#include <QCommandLineParser>
#include <QFile>
#include <QDebug>
#include <cstdio>
#include <QFileInfo>
#include <filesystem>
#include <QProcess>
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
    QCommandLineOption buildOption("build", "Build the generated project");
    QCommandLineOption runOption("run", "Run the binary after building");
    parserCmd.addOption(buildOption);
    parserCmd.addOption(runOption);
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

    std::string outDir = projectName + "_build";
    extern std::string outputDir;
    outputDir = outDir;
    try {
        std::filesystem::create_directories(outDir);
    } catch (const std::filesystem::filesystem_error& e) {
        qCritical() << "K# Error: Could not create output directory:" << e.what();
        return 1;
    }

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

    if (parserCmd.isSet(buildOption) || parserCmd.isSet(runOption)) {
        QString outDirQ = QString::fromStdString(outDir);
        QString buildDir = outDirQ + "/build";
        QString cacheFile = outDirQ + "/build/CMakeCache.txt";
        if (!QFile::exists(cacheFile)) {
            qInfo() << "[K#]: Configuring CMake...";
            QProcess cmake;
            cmake.setWorkingDirectory(outDirQ);
            cmake.setProcessChannelMode(QProcess::ForwardedChannels);
            cmake.start("cmake", {"-B", "build", "-S", "."});
            cmake.waitForFinished(-1);
            if (cmake.exitCode() != 0) {
                qCritical() << "K# Build Error: CMake configuration failed.";
                return 1;
            }
        }

        qInfo() << "[K#]: Building...";
        QProcess make;
        make.setWorkingDirectory(outDirQ);
        make.setProcessChannelMode(QProcess::ForwardedChannels);
        make.start("cmake", {"--build", "build"});
        make.waitForFinished(-1);
        if (make.exitCode() != 0) {
            qCritical() << "K# Build Error: Build failed.";
            return 1;
        }

        qInfo() << "[K#]: Build successful.";

        if (parserCmd.isSet(runOption)) {
            qInfo() << "[K#]: Running...";
            QProcess run;
            run.setWorkingDirectory(buildDir);
            run.setProcessChannelMode(QProcess::ForwardedChannels);
            run.start("./" + QString::fromStdString(projectName));
            run.waitForFinished(-1);
            return run.exitCode();
        }
    }

    qInfo() << "[K#]: Compilation successful.";

    return 0;

}
