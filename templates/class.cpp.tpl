#include "{{ className }}.h"

{%- if namespaceName %}
using namespace {{ namespaceName }};
{%- endif %}

{%- if isAppClass %}
{{ className }}::{{ className }}(int& argc, char** argv)
: {{ parent }}(argc, argv)
{%- else if isWidgetClass %}
{{ className }}::{{ className }}(QWidget* parent)
: {{ parent }}(parent)
{%- else %}
{{ className }}::{{ className }}(QObject* parent)
: {{ parent }}(parent)
{%- endif %}
{
    // Constructor implementation
    {%- for prop in properties %}{%- if prop.hasDefault %}
    m_{{ prop.name }} = {{ prop.defaultValue }};
    {%- endif %}{%- endfor %}
    {%- if existingConstructorBody %}
    {{ constructorBody }}
    {%- endif %}
}

{{ className }}::~{{ className }}()
{
    // Destructor implementation
}

{%- for prop in properties %}

{{ prop.type }} {{ className }}::get{{ prop.name }}() const {
    {%- if prop.hasCustomGetter %}
    {{ prop.getterBody }}
    {%- else %}
    {%- if prop.isPointerType %}
    return m_{{ prop.name }};
    {%- else %}
    return m_{{ prop.name }};
    {%- endif %}
    {%- endif %}
}

{%- if prop.isPointerType %}
void {{ className }}::set{{ prop.name }}({{ prop.paramType }} value) {
    m_{{ prop.name }} = value;
    emit {{ prop.name }}Changed(value);
}
{%- else %}
void {{ className }}::set{{ prop.name }}({{ prop.paramType }} value) {
    if (m_{{ prop.name }} == value) return;
    m_{{ prop.name }} = value;
    emit {{ prop.name }}Changed(value);
}
{%- endif %}
{%- endfor %}

{%- for method in methods %}

{{ method.returnType }} {{ className }}::{{ method.name }}({% for p in method.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %}) {
{{ method.body }}
}
{%- endfor %}

{%- for slot in slots %}
{{ slot.returnType }} {{ className }}::{{ slot.name }}({% for p in slot.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %}) {
{{ slot.body }}
}
{%- endfor %}
