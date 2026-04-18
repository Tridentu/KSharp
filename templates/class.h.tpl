#pragma once

{%- for includeFile in includes %}
#include <{{ includeFile }}>
{%- endfor %}

{%- if parentInclude and parentInclude != "" %}
#include <{{ parentInclude }}>
{%- else if parent != "QObject" and not parentInclude %}
#include "{{ parent }}.h"
{%- endif %}

{%- if namespaceName %}
namespace {{ namespaceName }} {
{%- endif %}

{%- for enum in enums %}
enum class {{ enum.name }} {
    {%- for value in enum.values %}
    {{ value.name }}{% if value.hasExplicitValue %} = {{ value.explicitValue }}{% endif %}{% if not loop.is_last %},{% endif %}
    {%- endfor %}
};
{%- endfor %}

{%- for iface in interfaces %}
class {{ iface.name }} {
public:
    virtual ~{{ iface.name }}() = default;
    {%- for method in iface.methods %}
    virtual {{ method.returnType }} {{ method.name }}({% for p in method.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %}) = 0;
    {%- endfor %}
};

{%- endfor %}

class {{ className }} : {{ modifier }} {{ parent }} {
    Q_OBJECT
public:
    {%- if isAppClass %}
        explicit {{ className }}(int& argc, char** argv);
    {%- else %}
        explicit {{ className }}(QObject* parent = nullptr);
    {%- endif %}
    virtual ~{{ className }}();
    {%- for prop in properties %}
        Q_PROPERTY({{ prop.type }} {{ prop.name }} READ get{{ prop.name }} WRITE set{{ prop.name }} NOTIFY {{ prop.name }}Changed)
        {{ prop.type }} get{{ prop.name }}() const;
        void set{{ prop.name }}({{ prop.paramType }} value);
    {%- endfor %}
    {%- for method in methods %}
    {%- if method.accessModifier == "public" %}
    {% if method.isVirtual %}virtual {% endif %}{% if method.isStatic %}static {% endif %}{{ method.returnType }} {{ method.name }}({% for p in method.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %}){% if method.isAbstract %} = 0{% endif %}{% if method.isOverride %} override{% endif %};
    {%- endif %}
    {%- endfor %}

{%- if hasPrivateMethods %}
private:
    {%- for method in methods %}
    {%- if method.accessModifier == "private" %}
    {{ method.returnType }} {{ method.name }}({% for param in method.parameters %}{{ param.type }} {{ param.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {%- endif %}
    {%- endfor %}
{%- endif %}

{%- if hasProtectedMethods %}
protected:
    {%- for method in methods %}
    {%- if method.accessModifier == "protected" %}
    {{ method.returnType }} {{ method.name }}({% for param in method.parameters %}{{ param.type }} {{ param.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {%- endif %}
    {%- endfor %}
{%- endif %}

public slots:
    {%- for slot in slots %}
    {%- if slot.accessModifier == "public" %}
    {{ slot.returnType }} {{ slot.name }}({% for p in slot.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {%- endif %}
    {%- endfor %}

{% if hasPrivateSlots %}
private slots:
    {% for slot in slots %}
    {% if slot.accessModifier == "private" %}
    {{ slot.returnType }} {{ slot.name }}({% for p in slot.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {% endif %}
    {% endfor %}
{% endif %}

{%- if hasProtectedSlots %}
protected slots:
    {%- for slot in slots %}
    {%- if slot.accessModifier == "protected" %}
    {{ slot.returnType }} {{ slot.name }}({% for p in slot.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {%- endif %}
    {%- endfor %}
{%- endif %}

signals:
    {%- for prop in properties %}
    void {{ prop.name }}Changed({{ prop.type }} {{ prop.name }});
    {%- endfor %}
    {%- for signal in signals %}
    {%- if signal.accessModifier == "public" %}
    void {{ signal.name }}({% for p in signal.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {%- endif %}
    {%- endfor %}

private:
    {%- for prop in properties %}
    {{ prop.type }} m_{{ prop.name }};
    {%- endfor %}
};

{%- if namespaceName %}
} // namespace {{ namespaceName }}
{%- endif %}
