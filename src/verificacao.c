/*
 * verificacao.c - Verificacoes semanticas da gramatica (etapa 2).
 *
 * Ja implementados (use como modelo):
 *   - verif_indefinidos: nao terminais usados mas nao definidos;
 *   - verif_terminais:   terminais nomeados sem declaracao.
 *
 * Verificacoes implementadas:
 *   - verif_inalcancaveis      (aviso)
 *   - verif_improdutivos       (erro)
 *   - verif_recursao_esquerda  (erro; direta e indireta)
 *
 * A duplicidade de definicoes ja e detectada durante a leitura
 * (ebnf_parser.c).
 */
#include <stdlib.h>
#include <string.h>
#include "verificacao.h"
#include "microc_mapa.h"
#include "util.h"

/* ------------------------------------------------------------------ */
/* Fornecido                                                          */
/* ------------------------------------------------------------------ */

static int verif_indefinidos(Gramatica *g)
{
    int i, erros = 0;
    for (i = 0; i < g->nnts; i++) {
        if (g->nts[i].regra == NULL) {
            diag_erro(g->nts[i].linha, g->nts[i].coluna,
                      "nao terminal %s usado mas nao definido", g->nts[i].nome);
            erros++;
        }
    }
    return erros;
}

static int verif_terminais(Gramatica *g, int modo_microc)
{
    int i, erros = 0, carregado = 0;
    Terminal *t;

    if (modo_microc)
        carregado = microc_carregar_tokens_h(g->tokens_externos) == 0;

    for (i = 1; i < g->nterms; i++) {
        t = &g->terms[i];
        if (modo_microc) {
            if (t->literal && microc_nome_literal(t->nome) == NULL) {
                diag_erro(t->linha, t->coluna, "literal %s nao corresponde a nenhum "
                          "token de Micro C", t->exibicao);
                erros++;
            } else if (!t->literal && carregado && !microc_token_existe(t->nome)) {
                diag_erro(t->linha, t->coluna, "terminal %s nao existe na enumeracao "
                          "TokenType de %s", t->nome, g->tokens_externos);
                erros++;
            }
        } else if (!t->declarado) {
            diag_erro(t->linha, t->coluna, "terminal %s nao declarado em TOKENS", t->nome);
            erros++;
        }
    }
    return erros;
}

/* ------------------------------------------------------------------ */
/* A implementar                                                      */
/* ------------------------------------------------------------------ */


static void marcar_alcancavel(Expr *e, void *ctx){
    int *alcancavel = (int *) ctx;
    if (e->tipo == E_NAOTERM){
        alcancavel[e->simbolo] = 1;
    }
}

static int verif_inalcancaveis(Gramatica *g){
    int i, passo;
    int *alcancavel = (int *) xcalloc((size_t) g->nnts, sizeof(int));
    alcancavel[g->inicial] = 1;
    for (passo = 0; passo < g->nnts; passo++){
        for (i = 0; i < g->nnts; i++){
            if (alcancavel[i]){
                expr_percorrer(g->nts[i].regra, marcar_alcancavel, alcancavel);
            }
        }
    }
    for (i = 0; i < g->nnts; i++){
        if (!alcancavel[i]){
            diag_aviso(g->nts[i].linha, g->nts[i].coluna,
                       "nao terminal %s inalcancavel a partir de %s",
                       g->nts[i].nome, g->nts[g->inicial].nome);
        }
    }
    free(alcancavel);
    return 0;
}

static int expr_produtiva(const Expr *e, const int *prod){
    int i;
    if (e == NULL){
        return 0;
    }
    switch (e->tipo){
        case E_TERM:
        case E_VAZIO:
        case E_OPC:
        case E_REP:
            return 1;
        case E_NAOTERM:
            return prod[e->simbolo];
        case E_SEQ:
            for (i = 0; i < e->nfilhos; i++){
                if (!expr_produtiva(e->filhos[i], prod)){
                    return 0;
                }
            }
            return 1;
        case E_ALT:
            for (i = 0; i < e->nfilhos; i++){
                if (expr_produtiva(e->filhos[i], prod)){
                    return 1;
                }
            }
            return 0;
    }
    return 0;
}

static int verif_improdutivos(Gramatica *g){
    int i, passo, erros = 0;
    int *prod = (int *) xcalloc((size_t) g->nnts, sizeof(int));
    for (passo = 0; passo < g->nnts; passo++){
        for (i = 0; i < g->nnts; i++){
            if (!prod[i] && g->nts[i].regra != NULL){
                prod[i] = expr_produtiva(g->nts[i].regra, prod);
            }
        }
    }
    for (i = 0; i < g->nnts; i++){
        if (g->nts[i].regra != NULL && !prod[i]){
            diag_erro(g->nts[i].linha, g->nts[i].coluna,
                      "nao terminal %s improdutivo (nao deriva cadeia de terminais)",
                      g->nts[i].nome);
            erros++;
        }
    }
    free(prod);
    return erros;
}

static void marcar_iniciais(const Expr *e, int *ini){
    int k;
    if (e == NULL){
        return;
    }
    switch (e->tipo){
        case E_NAOTERM:
            ini[e->simbolo] = 1;
            break;
        case E_ALT:
        case E_OPC:
        case E_REP:
            for (k = 0; k < e->nfilhos; k++){
                marcar_iniciais(e->filhos[k], ini);
            }
            break;
        case E_SEQ:
            for (k = 0; k < e->nfilhos; k++){
                marcar_iniciais(e->filhos[k], ini);
                if (!e->filhos[k]->anulavel){
                    break;
                }
            }
            break;
        case E_TERM:
        case E_VAZIO:
            break;
    }
}

int verif_recursao_esquerda(Gramatica *g){
    int i, j, passo, direta, erros = 0;
    int *ini = (int *) xmalloc((size_t) g->nnts * sizeof(int));
    for (i = 0; i < g->nnts; i++){
        if (g->nts[i].regra == NULL){
            continue;
        }
        memset(ini, 0, (size_t) g->nnts * sizeof(int));
        marcar_iniciais(g->nts[i].regra, ini);
        direta = ini[i];
        if (!direta){
            for (passo = 0; passo < g->nnts; passo++){
                for (j = 0; j < g->nnts; j++){
                    if (ini[j] && g->nts[j].regra != NULL){
                        marcar_iniciais(g->nts[j].regra, ini);
                    }
                }
            }
        }
        if (ini[i]){
            diag_erro(g->nts[i].linha_def, 0,
                      "nao terminal %s tem recursao a esquerda %s",
                      g->nts[i].nome, direta ? "direta" : "indireta");
            erros++;
        }
    }
    free(ini);
    return erros;
}

int verif_basica(Gramatica *g, int modo_microc)
{
    int erros = 0;
    if (g->inicial < 0) {
        diag_erro(0, 0, "a gramatica nao tem nenhuma regra");
        return 1;
    }
    erros += verif_indefinidos(g);
    erros += verif_terminais(g, modo_microc);
    erros += verif_inalcancaveis(g);
    if (erros == 0)
        erros += verif_improdutivos(g);
    return erros;
}
