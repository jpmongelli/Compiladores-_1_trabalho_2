/*
 * microc.flex
 *
 * Analisador lexico (scanner) para a linguagem Micro C (TP1 adaptado para o TP2).
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tokens.h"

YYSTYPE microc_yylval;

int linha_atual = 1;

static void definir_simbolo(char *s){
    free(microc_yylval.symbol);
    microc_yylval.symbol = s;
}

static void guarda_lexema(void){
    size_t n = strlen(yytext);
    char *s = (char *) malloc(n + 1);
    memcpy(s, yytext, n + 1);
    definir_simbolo(s);
}

static int ultimo_pode_preceder_operador = 0;

static int emitir(TokenType tipo){
    switch (tipo){
        case ID:
        case INTEGERCONST:
        case CHARCONST:
        case STRINGCONST:
        case RPAREN:
        case RBRACKET:
            ultimo_pode_preceder_operador = 1;
            break;
        default:
            ultimo_pode_preceder_operador = 0;
            break;
    }
    return tipo;
}

static char *strbuf = NULL;
static size_t strbuf_len = 0;
static size_t strbuf_cap = 0;

static void strbuf_start(void){
    free(strbuf);
    strbuf_cap = 64;
    strbuf_len = 0;
    strbuf = (char *) malloc(strbuf_cap);
    strbuf[0] = '\0';
}

static void strbuf_add(char c){
    if (strbuf_len + 1 >= strbuf_cap){
        strbuf_cap *= 2;
        strbuf = (char *) realloc(strbuf, strbuf_cap);
    }
    strbuf[strbuf_len++] = c;
    strbuf[strbuf_len] = '\0';
}

static char *strbuf_finish(void){
    char *result = (char *) malloc(strbuf_len + 1);
    memcpy(result, strbuf, strbuf_len + 1);
    free(strbuf);
    strbuf = NULL;
    return result;
}

static char *guarda_char(char c){
    char *buf = (char *) malloc(2);
    buf[0] = c;
    buf[1] = '\0';
    return buf;
}

static char erro_char_invalido[32];

void microc_limpar_recursos(void){
    free(strbuf);
    strbuf = NULL;
    free(microc_yylval.symbol);
    microc_yylval.symbol = NULL;
    ultimo_pode_preceder_operador = 0;
}

%}

%option prefix="microc_yy" noyywrap

DIGIT       [0-9]
LETRA       [a-zA-Z_]
ALFANUM     [a-zA-Z0-9_]

%x COMMENT
%x STRING

%%

<INITIAL><<EOF>>    { return emitir(END_OF_FILE); }

\n                  { linha_atual++; }
[ \t\r]+            { /* ignora espacos em branco */ }

"//".*              { /* comentario de linha: ignora ate o fim da linha */ }

"/*"                { BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); }
<COMMENT>\n         { linha_atual++; }
<COMMENT><<EOF>>    {
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "EOF em comentario";
                        return emitir(UNDEF);
                    }
<COMMENT>.          { /* consome qualquer outro caractere dentro do comentario */ }

"*/"                {
                        microc_yylval.error_msg = "Comentario nao iniciado";
                        return emitir(UNDEF);
                    }

{LETRA}{ALFANUM}*   {
                        if (strcmp(yytext, "main")   == 0) return emitir(MAIN);
                        if (strcmp(yytext, "if")     == 0) return emitir(IF);
                        if (strcmp(yytext, "else")   == 0) return emitir(ELSE);
                        if (strcmp(yytext, "for")    == 0) return emitir(FOR);
                        if (strcmp(yytext, "return") == 0) return emitir(RETURN);
                        if (strcmp(yytext, "int")    == 0) return emitir(INT);
                        if (strcmp(yytext, "char")   == 0) return emitir(CHAR);
                        if (strcmp(yytext, "print")  == 0) return emitir(PRINT);

                        guarda_lexema();
                        return emitir(ID);
                    }

-?{DIGIT}+          {
                        if (yytext[0] == '-' && ultimo_pode_preceder_operador){
                            yyless(1);
                            return emitir(MINUS);
                        }
                        guarda_lexema();
                        return emitir(INTEGERCONST);
                    }

'\\n'               { definir_simbolo(guarda_char('\n')); return emitir(CHARCONST); }
'\\t'               { definir_simbolo(guarda_char('\t')); return emitir(CHARCONST); }
'\\\\'              { definir_simbolo(guarda_char('\\')); return emitir(CHARCONST); }
'\\0'               { definir_simbolo(guarda_char(0));    return emitir(CHARCONST); }
'[^'\\\n]'          { definir_simbolo(guarda_char(yytext[1])); return emitir(CHARCONST); }

'[^'\n]*'           {
                        microc_yylval.error_msg = "Constante de caractere mal formada";
                        return emitir(UNDEF);
                    }

'[^'\n]*            {
                        microc_yylval.error_msg = "Aspas simples nao fechadas";
                        return emitir(UNDEF);
                    }

\"                  { strbuf_start(); BEGIN(STRING); }

<STRING>\"          {
                        BEGIN(INITIAL);
                        definir_simbolo(strbuf_finish());
                        return emitir(STRINGCONST);
                    }
<STRING>\\n         { strbuf_add('\n'); }
<STRING>\\t         { strbuf_add('\t'); }
<STRING>\\\\        { strbuf_add('\\'); }
<STRING>\\\"        { strbuf_add('"');  }
<STRING>\\0         { strbuf_add(0); }
<STRING>\\.         { strbuf_add(yytext[1]); }
<STRING>\000        {
                        microc_yylval.error_msg = "String contem caractere nulo";
                        return emitir(UNDEF);
                    }
<STRING>\n          {
                        yyless(0);
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "String nao terminada";
                        return emitir(UNDEF);
                    }
<STRING><<EOF>>     {
                        BEGIN(INITIAL);
                        microc_yylval.error_msg = "EOF em string";
                        return emitir(UNDEF);
                    }
<STRING>.           { strbuf_add(yytext[0]); }

"=="                { return emitir(EQ); }
"="                 { return emitir(ASSIGN); }

"!="                { return emitir(NEQ); }
"!"                 { return emitir(NOT); }

"<="                { return emitir(LEQ); }
"<"                 { return emitir(LT); }

">="                { return emitir(GEQ); }
">"                 { return emitir(GT); }

"&&"                { return emitir(AND); }
"||"                { return emitir(OR); }

"+"                 { return emitir(PLUS); }
"-"                 { return emitir(MINUS); }
"*"                 { return emitir(MUL); }
"/"                 { return emitir(DIV); }
"%"                 { return emitir(MOD); }
";"                 { return emitir(SEMICOLON); }
","                 { return emitir(COMMA); }
"("                 { return emitir(LPAREN); }
")"                 { return emitir(RPAREN); }
"{"                 { return emitir(LBRACE); }
"}"                 { return emitir(RBRACE); }
"["                 { return emitir(LBRACKET); }
"]"                 { return emitir(RBRACKET); }

.                   {
                        sprintf(erro_char_invalido, "Caractere invalido '%c'", yytext[0]);
                        microc_yylval.error_msg = erro_char_invalido;
                        return emitir(UNDEF);
                    }

%%
