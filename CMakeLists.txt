cmake_minimum_required(VERSION 3.10)
project(ksharp VERSION 0.1 LANGUAGES C CXX)

find_package(FLEX REQUIRED)
find_package(BISON REQUIRED)
find_package(nlohmann_json REQUIRED)
find_package(inja CONFIG REQUIRED)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core)

set(LEXER_SRC "src/lexer.l")
set(PARSER_SRC "src/parser.y")
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/templates DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

BISON_TARGET(KSharpParser ${PARSER_SRC} "${CMAKE_CURRENT_BINARY_DIR}/KSharpParser.cpp" DEFINES_FILE "${CMAKE_CURRENT_BINARY_DIR}/KSharpParser.h" )
FLEX_TARGET(KSharpLexer ${LEXER_SRC} "${CMAKE_CURRENT_BINARY_DIR}/KSharpLexer.cpp")
ADD_FLEX_BISON_DEPENDENCY(KSharpLexer KSharpParser)

add_executable(ksharpc
    src/KSharpHelpers.cpp
    src/main.cpp
    ${BISON_KSharpParser_OUTPUTS}
    ${FLEX_KSharpLexer_OUTPUTS}
)


target_include_directories(ksharpc PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(ksharpc PRIVATE
    Qt6::Core
    nlohmann_json::nlohmann_json
)
