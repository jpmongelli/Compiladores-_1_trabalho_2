/*
 * microc_mapa.c - Correspondencia com os tokens de Micro C (ver microc_mapa.h).
 *
 * A tabela de literais segue o tokens.h do livro-texto (secao 2.3.1):
 *
 *   UNDEF, ID, END_OF_FILE, INTEGERCONST, CHARCONST, STRINGCONST,
 *   PLUS, MINUS, MUL, DIV, MOD, EQ, NEQ, LT, GT, LEQ, GEQ, AND, OR, NOT,
 *   ASSIGN, SEMICOLON, COMMA, LPAREN, RPAREN, LBRACE, RBRACE,
 *   LBRACKET, RBRACKET, MAIN, IF, ELSE, FOR, RETURN, INT, CHAR, PRINT
 *
 * Se o seu tokens.h do TP1 usar outros nomes, ajuste a tabela.
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "microc_mapa.h"
#include "util.h"

static const char *const literais[][2] = {
    { "+",  "PLUS" },      { "-",  "MINUS" },     { "*",  "MUL" },
    { "/",  "DIV" },       { "%",  "MOD" },
    { "==", "EQ" },        { "!=", "NEQ" },       { "<",  "LT" },
    { ">",  "GT" },        { "<=", "LEQ" },       { ">=", "GEQ" },
    { "&&", "AND" },       { "||", "OR" },        { "!",  "NOT" },
    { "=",  "ASSIGN" },    { ";",  "SEMICOLON" }, { ",",  "COMMA" },
    { "(",  "LPAREN" },    { ")",  "RPAREN" },    { "{",  "LBRACE" },
    { "}",  "RBRACE" },    { "[",  "LBRACKET" },  { "]",  "RBRACKET" },
    { "main", "MAIN" },    { "if", "IF" },        { "else", "ELSE" },
    { "for", "FOR" },      { "return", "RETURN" },{ "int", "INT" },
    { "char", "CHAR" },    { "print", "PRINT" }
};

static char **nomes = NULL;
static int nnomes = 0, capnomes = 0;

const char *microc_nome_literal(const char *literal)
{
    size_t i;
    for (i = 0; i < sizeof(literais) / sizeof(literais[0]); i++)
        if (strcmp(literais[i][0], literal) == 0)
            return literais[i][1];
    return NULL;
}

static void adicionar_nome(const char *s, size_t n)
{
    if (nnomes == capnomes) {
        capnomes = capnomes ? 2 * capnomes : 64;
        nomes = (char **) xrealloc(nomes, (size_t) capnomes * sizeof(char *));
    }
    nomes[nnomes++] = xstrndup(s, n);
}


int microc_carregar_tokens_h(const char *caminho){
    char *conteudo, *p, *fim, *ini_id;
    if (caminho == NULL){
        return -1;
    }
    conteudo = ler_arquivo(caminho);
    if (conteudo == NULL){
        diag_erro(0, 0, "nao foi possivel abrir %s", caminho);
        return -1;
    }
    fim = strstr(conteudo, "TokenType");
    if (fim == NULL){
        free(conteudo);
        return -1;
    }
    p = fim;
    while (p > conteudo && *p != '{'){
        p--;
    }
    if (*p != '{'){
        free(conteudo);
        return -1;
    }
    p++;
    while (p < fim && *p != '}'){
        if (p[0] == '/' && p[1] == '*'){
            p += 2;
            while (p < fim && !(p[0] == '*' && p[1] == '/')){
                p++;
            }
            if (p < fim){
                p += 2;
            }
        } else if (p[0] == '/' && p[1] == '/'){
            while (p < fim && *p != '\n'){
                p++;
            }
        } else if (isalpha((unsigned char) *p) || *p == '_'){
            ini_id = p;
            while (isalnum((unsigned char) *p) || *p == '_'){
                p++;
            }
            adicionar_nome(ini_id, (size_t) (p - ini_id));
            while (p < fim && *p != ',' && *p != '}'){
                p++;
            }
        } else{
            p++;
        }
    }
    free(conteudo);
    return 0;
}

int microc_token_existe(const char *nome)
{
    int i;
    for (i = 0; i < nnomes; i++)
        if (strcmp(nomes[i], nome) == 0)
            return 1;
    return 0;
}

void microc_liberar(void)
{
    int i;
    for (i = 0; i < nnomes; i++)
        free(nomes[i]);
    free(nomes);
    nomes = NULL;
    nnomes = capnomes = 0;
}
