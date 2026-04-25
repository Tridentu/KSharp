
#include "KSharpHelpers.h"

void ksharp_semantic_warn(const std::string& msg, const std::string& context) {
    if (context.empty())
        fprintf(stderr, "[K#]: Warning: %s\n", msg.c_str());
    else
        fprintf(stderr, "[K#]: Warning in '%s': %s\n", context.c_str(), msg.c_str());
}
