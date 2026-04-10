#pragma once

{% for includeFile in includes %}
#include <{{ includeFile }}>
{% endfor %}

{% if parent != "QObject" %}
#include "{{ parent }}.h"
{% endif %}

{% if namespaceName %}
namespace {{ namespaceName }} {
{% endif %}

class {{ className }} : {{ modifier }} {{ parent }} {
    Q_OBJECT
public:
    explicit {{ className }}(QObject* parent = nullptr);
    virtual ~{{ className }}();

    {% for prop in properties %}
        Q_PROPERTY({{ prop.type }} {{ prop.name }} READ get{{ prop.name }} WRITE set{{ prop.name }} NOTIFY {{ prop.name }}Changed)
        {{ prop.type }} get{{ prop.name }}() const;
        void set{{ prop.name }}({{ prop.type }} value);
    {% endfor %}

    {% for method in methods %}
    {% if method.accessModifier == "public" %}
    {{ method.returnType }} {{ method.name }}({% for param in method.parameters %}{{ param.type }} {{ param.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {% endif %}
    {% endfor %}

public slots:
    {% for slot in slots %}
    {% if slot.accessModifier == "public" %}
{{ slot.returnType }} {{ slot.name }}({% for p in slot.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {% endif %}
    {% endfor %}

signals:
    {% for prop in properties %}
        void {{ prop.name }}Changed({{ prop.type }} {{ prop.name }});
    {% endfor %}

    {% for signal in signals %}
    {% if signal.accessModifier == "public" %}

    void {{ signal.name }}({% for p in signal.parameters %}{{ p.type }} {{ p.name }}{% if not loop.is_last %}, {% endif %}{% endfor %});
    {% endif %}
    {% endfor %}

private:
    {% for prop in properties %}
        {{ prop.type }} m_{{ prop.name }};
    {% endfor %}
};

{% if namespaceName %}
} // namespace {{ namespaceName }}
{% endif %}
