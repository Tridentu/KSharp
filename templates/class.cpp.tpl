#include "{{ className }}.h"


{% if namespaceName %}
using namespace {{ namespaceName }};
{% endif %}


{{ className }}::{{ className }}(QObject* parent)
: {{ parent }}(parent)
{
    // Constructor implementation
    {%- for prop in properties %}
    {%- if prop.type == "int" %}
    m_{{ prop.name }} = 0;
    {%- else if prop.type == "QString" %}
    m_{{ prop.name }} = "";
    {%- endif %}
    {%- endfor %}
    {%- if existingConstructorBody %}
        {{ constructorBody }}
    {%- endif %}
}

{{ className }}::~{{ className }}()
{
    // Destructor implementation
}


{% for prop in properties %}
{{ prop.type }} {{ className }}::get{{ prop.name }}() const {
    return m_{{ prop.name }};
}

void {{ className }}::set{{ prop.name }}({{ prop.paramType }} value) {
    if (m_{{ prop.name }} == value) return;
    m_{{ prop.name }} = value;
    emit {{ prop.name }}Changed(value);
}
{% endfor %}

{% for method in methods %}
{{ method.returnType }} {{ className }}::{{ method.name }}({% for p in method.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %}) {
    // Generated Body
    {{ method.body }}
}
{% endfor %}


{% for slot in slots %}
{{ slot.returnType }} {{ className }}::{{ slot.name }}({% for p in slot.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %}) {
    // Generated Body
    {{ slot.body }}
}
{% endfor %}
