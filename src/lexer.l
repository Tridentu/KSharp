%{
 #include "KSharpParser.h"
 #include <cstring>
 #include <string>

 std::string block_contents;
 int brace_count = 0;
 extern int capture_mode; // We'll define this in the parser
%}
%x IN_BLOCK


%%
"namespace" { return NAMESPACE; }
"class"  { return CLASS; }
"public" { return PUBLIC; }
"property" { return PROPERTY; }
"slot" { return SLOT; }
"signal"   { return SIGNAL; }
"using"    { return USING; }
"int"     { yylval.sval = strdup(yytext); return IDENTIFIER; }
"string"  { yylval.sval = strdup(yytext); return IDENTIFIER; }
"void"  {  return VOID; }
"new"   { return NEW; }
"set"    { return SET; }
"get"    { return GET; }
"<"     { return L_ANGLE; }
">"     { return R_ANGLE; }
"{"      {
    if (capture_mode) {
        brace_count = 1;
        block_contents = "";
        capture_mode = 0; // Reset the trigger
        BEGIN(IN_BLOCK);
    } else {
        return LBRACE;
    }
}
"}"     { return RBRACE; }
";"     { return SEMICOLON; }
"."      { return DOT; }
","     { return COMMA; }
"("     { return LBRACE_PAREN; }
")"     { return RBRACE_PAREN; }
":"    { return COLON; } /* Preparing for inheritance too */
"+="    { return PLUS_EQUAL; }
"="     { return ASSIGN; }

[a-zA-Z_][a-zA-Z0-9_.]*("<"[a-zA-Z0-9_.<> ]+">")? {
yylval.sval = strdup(yytext);
  return IDENTIFIER;
}
[0-9]+  { return NUMBER; }


<IN_BLOCK>"{" { brace_count++; block_contents += "{"; }
<IN_BLOCK>"}" {
    brace_count--;
    if (brace_count == 0) {
        yylval.sval = strdup(block_contents.c_str());
        BEGIN(INITIAL);
        return METHOD_BODY;
    } else {
        block_contents += "}";
    }
}
<IN_BLOCK>.|\n { block_contents += yytext; }


[ \t\r\n]+ ; /* Skip Whitespace */
.       { printf("K# Syntax Error: Unknown character.\n"); }
%%

int yywrap(){ return 1;}
