/*
 * microc.flex
 *
 * Analisador lexico (scanner) para a linguagem Micro C.
 * Disciplina: Compiladores I - FACOM
 *
 * Compilacao:
 *     flex microc.flex
 *     gcc lex.yy.c -o lexer
 *
 * Uso:
 *     ./lexer test.mc
 */

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------------------------------------------------------------------
 * 1. VOCABULARIO DE TOKENS (equivalente a tokens.h)
 * ------------------------------------------------------------------- */

typedef enum {
    /* Tokens fundamentais */
    UNDEF,          /* token indefinido (usado para reportar erros) */
    ID,             /* identificador                                */
    END_OF_FILE,    /* fim de arquivo                               */

    /* Constantes literais */
    INTEGERCONST,
    CHARCONST,
    STRINGCONST,

    /* Operadores aritmeticos */
    PLUS, MINUS, MUL, DIV, MOD,

    /* Operadores relacionais e logicos */
    EQ, NEQ, LT, GT, LEQ, GEQ, AND, OR, NOT,

    /* Simbolos de atribuicao e pontuacao */
    ASSIGN, SEMICOLON, COMMA, LPAREN, RPAREN,
    LBRACE, RBRACE, LBRACKET, RBRACKET,

    /* Palavras reservadas */
    MAIN, IF, ELSE, FOR, RETURN, INT, CHAR, PRINT
} TokenType;

/* Nomes dos tokens, usados apenas pelo main() de teste abaixo para
 * imprimir o tipo de cada token de forma legivel. Mantenha esta lista
 * na MESMA ORDEM do enum TokenType. */
static const char *nome_token[] = {
    "UNDEF", "ID", "END_OF_FILE",
    "INTEGERCONST", "CHARCONST", "STRINGCONST",
    "PLUS", "MINUS", "MUL", "DIV", "MOD",
    "EQ", "NEQ", "LT", "GT", "LEQ", "GEQ", "AND", "OR", "NOT",
    "ASSIGN", "SEMICOLON", "COMMA", "LPAREN", "RPAREN",
    "LBRACE", "RBRACE", "LBRACKET", "RBRACKET",
    "MAIN", "IF", "ELSE", "FOR", "RETURN", "INT", "CHAR", "PRINT"
};

/* Valor semantico do token corrente. */
typedef struct {
    char *symbol;      /* lexema para ID, INTEGERCONST, CHARCONST, STRINGCONST */
    char *error_msg;   /* mensagem de erro, usada apenas quando tipo == UNDEF   */
} YYSTYPE;

YYSTYPE microc_yylval;

/* Linha atual do arquivo-fonte sendo processado. Deve ser incrementada
 * toda vez que uma quebra de linha for consumida pelo scanner (seja em
 * codigo "normal", dentro de comentarios ou dentro de strings). */
int linha_atual = 1;

/* Funcao auxiliar para preencher microc_yylval.symbol com uma copia do
 * texto reconhecido (yytext). */
static void guarda_lexema(void) {
    microc_yylval.symbol = strdup(yytext);
}

/* -----------------------------------------------------------------------
 * Suporte para constantes inteiras negativas (Item 4 do enunciado)
 * -------------------------------------------------------------------
 * Nao ha como decidir, olhando so para o "-" e o que vem depois dele, se
 * ele e o operador de subtracao ou o sinal de um numero negativo: "a-5"
 * e "-5" tem exatamente a mesma coisa a direita do "-". A diferenca esta
 * no que veio ANTES: se o token anterior pode "terminar" uma expressao
 * (um identificador, uma constante, ou um ")"/"]" fechando algo), entao
 * o "-" que vem em seguida e subtracao; caso contrario, ele faz parte de
 * um literal negativo.
 *
 * Por isso guardamos, numa variavel global, se o ULTIMO token devolvido
 * pode aparecer imediatamente antes de um operador binario (ou seja, se
 * ele "encerra" um operando). Toda vez que um token e devolvido, usamos
 * a funcao emitir() abaixo em vez de "return TOKEN;" diretamente, para
 * manter essa variavel sempre atualizada em um unico lugar. */
static int ultimo_pode_preceder_operador = 0;

static int emitir(TokenType tipo) {
    switch (tipo) {
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

/* -----------------------------------------------------------------------
 * Suporte para constantes de string (Item 2 do enunciado / Secao 4.3)
 * -------------------------------------------------------------------
 * Usamos um buffer dinamico para ir acumulando, caractere a caractere, o
 * VALOR da string (ja com as sequencias de escape convertidas), enquanto
 * o scanner permanece no estado exclusivo <STRING>. */
static char *strbuf = NULL;
static size_t strbuf_len = 0;
static size_t strbuf_cap = 0;

static void strbuf_start(void) {
    strbuf_cap = 64;
    strbuf_len = 0;
    strbuf = malloc(strbuf_cap);
    strbuf[0] = '\0';
}

static void strbuf_add(char c) {
    if (strbuf_len + 1 >= strbuf_cap) {
        strbuf_cap *= 2;
        strbuf = realloc(strbuf, strbuf_cap);
    }
    strbuf[strbuf_len++] = c;
    strbuf[strbuf_len] = '\0';
}

static char *strbuf_finish(void) {
    /* usamos memcpy (em vez de strdup) para preservar corretamente um
     * eventual caractere nulo (\0) inserido no meio da string. */
    char *result = malloc(strbuf_len + 1);
    memcpy(result, strbuf, strbuf_len + 1);
    return result;
}

/* Analogo ao strbuf_finish(), mas para um UNICO caractere (usado pelas
 * constantes de caractere), preservando o caso do caractere nulo \0. */
static char *guarda_char(char c) {
    char *buf = malloc(2);
    buf[0] = c;
    buf[1] = '\0';
    return buf;
}

%}

/* -----------------------------------------------------------------------
 * 2. SECAO DE DEFINICOES
 * ------------------------------------------------------------------- */

DIGIT       [0-9]
LETRA       [a-zA-Z_]
ALFANUM      [a-zA-Z0-9_]

%x COMMENT
%x STRING

%%

 /* -----------------------------------------------------------------------
  * 3. SECAO DE REGRAS
  * --------------------------------------------------------------------- */

 /* --- Fim de arquivo -----------------------------------------------------
  * Tratada explicitamente (em vez de depender do retorno automatico 0
  * do flex), pois o token UNDEF tambem vale 0 no enum TokenType -- se
  * dependessemos do comportamento padrao, um erro lexico seria
  * confundido com o fim do arquivo pelo main() de teste abaixo.
  *
  * IMPORTANTE: qualificamos explicitamente com <INITIAL> (em vez de usar
  * "<<EOF>>" sem prefixo). Se deixassemos sem prefixo, o Flex a aplicaria
  * automaticamente a TODOS os estados ja declarados nesse ponto do
  * arquivo (incluindo COMMENT e STRING, pois %x COMMENT/%x STRING vem
  * antes na secao de definicoes) -- e entao as regras <COMMENT><<EOF>>
  * e <STRING><<EOF>> logo abaixo seriam vistas como DUPLICADAS, gerando
  * o erro "multiple <<EOF>> rules for start condition ...". */
<INITIAL><<EOF>>    { return emitir(END_OF_FILE); }

 /* --- Espacos em branco e quebras de linha ---------------------------- */
\n                  { linha_atual++; }
[ \t\r]+            { /* ignora espacos em branco */ }

 /* --- Comentarios ------------------------------------------------------
  * Ja implementados como exemplo de uso de estados (%x) e de tratamento
  * de erro via EOF dentro de um estado especial. */
"//".*              { /* comentario de linha: ignora ate o fim da linha */ }

"/*"                { BEGIN(COMMENT); }
<COMMENT>"*/"       { BEGIN(INITIAL); }
<COMMENT>\n         { linha_atual++; }
<COMMENT><<EOF>>    {
                        microc_yylval.error_msg = "EOF em comentario";
                        return emitir(UNDEF);
                    }
<COMMENT>.          { /* consome qualquer outro caractere dentro do comentario */ }

 /* Fechamento de comentario sem abertura correspondente. */
"*/"                {
                        microc_yylval.error_msg = "Comentario nao iniciado";
                        return emitir(UNDEF);
                    }

 /* --- Palavras reservadas e identificadores ----------------------------
  * Compara o lexema reconhecido com cada palavra reservada da linguagem;
  * se nao houver correspondencia, trata-se de um identificador comum. */
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

 /* --- Constantes inteiras (positivas e negativas) -----------------------
  * O "-" so e incorporado ao numero quando o token anterior NAO pode
  * "terminar" um operando (veja o comentario de ultimo_pode_preceder_operador
  * acima). Quando o "-" e, na verdade, o operador de subtracao, devolvemos
  * apenas o "-" (via yyless) e deixamos os digitos serem re-analisados na
  * proxima chamada, como uma constante inteira comum. */
-?{DIGIT}+          {
                        if (yytext[0] == '-' && ultimo_pode_preceder_operador) {
                            /* "-" e operador de subtracao: devolve os digitos
                             * para a entrada, mantendo so o "-" reconhecido agora. */
                            yyless(1);
                            return emitir(MINUS);
                        }
                        guarda_lexema();
                        return emitir(INTEGERCONST);
                    }

 /* --- Constantes de caractere --------------------------------------------
  * Formato: aspas simples, um caractere (ou uma sequencia de escape),
  * aspas simples de fechamento. As regras de escape sao verificadas
  * primeiro para que, em caso de empate no tamanho do casamento, o flex
  * prefira a regra declarada antes (a interpretacao correta do escape),
  * conforme a regra do "maior casamento, e em caso de empate, a regra que
  * aparece primeiro" explicada no enunciado. */
'\\n'               { microc_yylval.symbol = guarda_char('\n'); return emitir(CHARCONST); }
'\\t'               { microc_yylval.symbol = guarda_char('\t'); return emitir(CHARCONST); }
'\\\\'              { microc_yylval.symbol = guarda_char('\\'); return emitir(CHARCONST); }/*
'\"'              { microc_yylval.symbol = guarda_char('"');  return emitir(CHARCONST); }
*/
'\\0'               { microc_yylval.symbol = guarda_char(0);   return emitir(CHARCONST); }
'[^'\\\n]'          { microc_yylval.symbol = guarda_char(yytext[1]); return emitir(CHARCONST); }

 /* Erro: aspas simples fechadas, mas com conteudo invalido (vazio, mais
  * de um caractere, ou sequencia de escape desconhecida). */
'[^'\n]*'           {
                        microc_yylval.error_msg = "Constante de caractere mal formada";
                        return emitir(UNDEF);
                    }

 /* Erro: aspas simples nao fechadas antes do fim da linha (ou do EOF). */
'[^'\n]*            {
                        microc_yylval.error_msg = "Aspas simples nao fechadas";
                        return emitir(UNDEF);
                    }

 /* --- Constantes de string -------------------------------------------
  * Usamos um estado exclusivo <STRING>, no mesmo espirito do estado
  * <COMMENT> ja fornecido como exemplo, para poder acumular o conteudo
  * (com os escapes ja convertidos) e tratar cada tipo de erro descrito
  * na Secao 4.1 do enunciado separadamente. */
\"                  { strbuf_start(); BEGIN(STRING); }

<STRING>\"          {
                        BEGIN(INITIAL);
                        microc_yylval.symbol = strbuf_finish();
                        return emitir(STRINGCONST);
                    }
<STRING>\\n         { strbuf_add('\n'); }
<STRING>\\t         { strbuf_add('\t'); }
<STRING>\\\\        { strbuf_add('\\'); }
<STRING>\\\"        { strbuf_add('"');  }
<STRING>\\0         { strbuf_add(0); }
<STRING>\\.         { /* sequencia de escape desconhecida: mantem o caractere literal */
                        strbuf_add(yytext[1]);
                    }
<STRING>\000        {
                        microc_yylval.error_msg = "String contem caractere nulo";
                        return emitir(UNDEF);
                    }
<STRING>\n          {
                        linha_atual++;
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

 /* --- Operadores relacionais e logicos ---------------------------------
  * O caso de '=' esta implementado como EXEMPLO do uso de lookahead
  * (o flex sempre prefere o casamento mais longo, entao "==" vence "="
  * quando os dois caracteres estao presentes). Os demais operadores que
  * compartilham prefixo seguem exatamente o mesmo padrao. */
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

 /* --- Operadores aritmeticos e simbolos de pontuacao (ja prontos) ------ */
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

 /* --- Caractere invalido -------------------------------------------------
  * Casa com qualquer caractere que nao tenha correspondido a nenhuma
  * regra anterior. Deve ser SEMPRE a ultima regra do arquivo. */
.                   {
                        microc_yylval.error_msg = strdup(yytext);
                        return emitir(UNDEF);
                    }

%%

/* -----------------------------------------------------------------------
 * 4. SUB-ROTINAS DO USUARIO
 * ------------------------------------------------------------------- */

/* yywrap: informa ao flex que, ao atingir o EOF, a leitura deve
 * simplesmente parar (nao ha um proximo arquivo a processar). */
int yywrap(void) {
    return 1;
}

/* main() de teste: le o arquivo passado como argumento e imprime, para
 * cada token reconhecido, seu tipo, lexema e linha. */
int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo.mc>\n", argv[0]);
        return 1;
    }

    FILE *arquivo_fonte = fopen(argv[1], "r");
    if (!arquivo_fonte) {
        fprintf(stderr, "Erro: nao foi possivel abrir o arquivo '%s'\n", argv[1]);
        return 1;
    }
    yyin = arquivo_fonte;

    int tipo;
    while ((tipo = yylex()) != END_OF_FILE) {
        if (tipo == UNDEF) {
            fprintf(stderr, "ERRO LEXICO (linha %d): %s\n",
                    linha_atual, microc_yylval.error_msg);
            continue;
        }
        printf("Token: tipo = %-13s lexema = '%s'  linha = %d\n",
               nome_token[tipo], yytext, linha_atual);
    }

    fclose(arquivo_fonte);
    return 0;
}