cmake_minimum_required(VERSION 3.16)

project({{ projectName }} VERSION 0.1 LANGUAGES CXX)


set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(Qt6_NO_VULKAN ON)

find_package(Qt6 REQUIRED COMPONENTS Core{% if needsWidgets %} Widgets{% endif %}{% for flag in linkerFlags %} {{ flag }}{% endfor %})
{%- if needsKF6 %}
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(KF6 REQUIRED COMPONENTS CoreAddons I18n XmlGui)
{%- endif %}

add_executable({{ projectName }}
{%- if hasEntryPoint %}
    kshp_main.cpp
{%- endif %}
{%- for cls in classes %}
    {{ cls }}.cpp
{%- endfor %}
)

target_link_libraries({{ projectName }} PRIVATE
    Qt6::Core
    Qt6::Widgets
{%- for flag in linkerFlags %}
    Qt6::{{ flag }}
{%- endfor %}
{%- if needsKF6 %}
    KF6::CoreAddons
    KF6::I18n
    KF6::XmlGui
{%- endif %}
)


