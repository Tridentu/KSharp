cmake_minimum_required(VERSION 3.16)

project({{ projectName }} VERSION 0.1 LANGUAGES CXX)


set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


find_package(Qt6 REQUIRED COMPONENTS Core{% for flag in linkerFlags %} {{ flag }}{% endfor %})

add_executable({{ projectName }}
    main.cpp
{%- for cls in classes %}
    {{ cls }}.cpp
{%- endfor %}
)

target_link_libraries({{ projectName }} PRIVATE
    Qt6::Core
{%- for flag in linkerFlags %}
    Qt6::{{ flag }}
{%- endfor %}
)
