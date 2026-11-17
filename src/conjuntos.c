/*
 * conjuntos.c - Calculo de anulavel, FIRST e FOLLOW (etapa 3).
 *
 * Fornecido: conj_iniciar e conj_imprimir.
 */
#include <stdio.h>
#include <string.h>
#include "conjuntos.h"
#include "util.h"

/* ------------------------------------------------------------------ */
/* Fornecido                                                          */
/* ------------------------------------------------------------------ */

static void iniciar_expr(Expr *e, void *ctx)
{
    int n = *(int *) ctx;
    bitset_liberar(&e->first);
    bitset_liberar(&e->follow);
    bitset_iniciar(&e->first, n);
    bitset_iniciar(&e->follow, n);
    e->anulavel = 0;
}

void conj_iniciar(Gramatica *g)
{
    int i, n = g->nterms;
    for (i = 0; i < g->nnts; i++) {
        bitset_liberar(&g->nts[i].first);
        bitset_liberar(&g->nts[i].follow);
        bitset_iniciar(&g->nts[i].first, n);
        bitset_iniciar(&g->nts[i].follow, n);
        g->nts[i].anulavel = 0;
        expr_percorrer(g->nts[i].regra, iniciar_expr, &n);
    }
}

void conj_imprimir(FILE *f, const Gramatica *g)
{
    int i;
    size_t largura = strlen("NAO TERMINAL");
    for (i = 0; i < g->nnts; i++)
        if (strlen(g->nts[i].nome) > largura)
            largura = strlen(g->nts[i].nome);
    fprintf(f, "%-*s  ANULAVEL  FIRST / FOLLOW\n", (int) largura, "NAO TERMINAL");
    for (i = 0; i < g->nnts; i++) {
        fprintf(f, "%-*s  %-8s  FIRST  = ", (int) largura, g->nts[i].nome,
                g->nts[i].anulavel ? "sim" : "nao");
        gram_imprimir_conjunto(f, g, &g->nts[i].first);
        fprintf(f, "\n%-*s            FOLLOW = ", (int) largura, "");
        gram_imprimir_conjunto(f, g, &g->nts[i].follow);
        fputc('\n', f);
    }
}

/* ------------------------------------------------------------------ */
/* A implementar                                                      */
/* ------------------------------------------------------------------ */

static int calc_anulavel_expr(Expr *e, const Gramatica *g){
    int i, mudou = 0, novo = 0;
    if (e == NULL){
        return 0;
    }
    for (i = 0; i < e->nfilhos; i++){
        if (calc_anulavel_expr(e->filhos[i], g)){
            mudou = 1;
        }
    }
    switch (e->tipo){
        case E_TERM:
            novo = 0;
            break;
        case E_VAZIO:
        case E_OPC:
        case E_REP:
            novo = 1;
            break;
        case E_NAOTERM:
            novo = g->nts[e->simbolo].anulavel;
            break;
        case E_SEQ:
            novo = 1;
            for (i = 0; i < e->nfilhos; i++){
                if (!e->filhos[i]->anulavel){
                    novo = 0;
                }
            }
            break;
        case E_ALT:
            novo = 0;
            for (i = 0; i < e->nfilhos; i++){
                if (e->filhos[i]->anulavel){
                    novo = 1;
                }
            }
            break;
    }
    if (novo != e->anulavel){
        e->anulavel = novo;
        mudou = 1;
    }
    return mudou;
}

void conj_anulavel(Gramatica *g){
    int i, mudou;
    do{
        mudou = 0;
        for (i = 0; i < g->nnts; i++){
            if (g->nts[i].regra == NULL){
                continue;
            }
            if (calc_anulavel_expr(g->nts[i].regra, g)){
                mudou = 1;
            }
            if (g->nts[i].anulavel != g->nts[i].regra->anulavel){
                g->nts[i].anulavel = g->nts[i].regra->anulavel;
                mudou = 1;
            }
        }
    } while (mudou);
}

static int calc_first_expr(Expr *e, const Gramatica *g){
    int i, mudou = 0;
    if (e == NULL){
        return 0;
    }
    for (i = 0; i < e->nfilhos; i++){
        if (calc_first_expr(e->filhos[i], g)){
            mudou = 1;
        }
    }
    switch (e->tipo){
        case E_TERM:
            if (!bitset_tem(&e->first, e->simbolo)){
                bitset_add(&e->first, e->simbolo);
                mudou = 1;
            }
            break;
        case E_NAOTERM:
            if (bitset_unir(&e->first, &g->nts[e->simbolo].first)){
                mudou = 1;
            }
            break;
        case E_VAZIO:
            break;
        case E_ALT:
        case E_OPC:
        case E_REP:
            for (i = 0; i < e->nfilhos; i++){
                if (bitset_unir(&e->first, &e->filhos[i]->first)){
                    mudou = 1;
                }
            }
            break;
        case E_SEQ:
            for (i = 0; i < e->nfilhos; i++){
                if (bitset_unir(&e->first, &e->filhos[i]->first)){
                    mudou = 1;
                }
                if (!e->filhos[i]->anulavel){
                    break;
                }
            }
            break;
    }
    return mudou;
}

void conj_first(Gramatica *g){
    int i, mudou;
    do{
        mudou = 0;
        for (i = 0; i < g->nnts; i++){
            if (g->nts[i].regra == NULL){
                continue;
            }
            if (calc_first_expr(g->nts[i].regra, g)){
                mudou = 1;
            }
            if (bitset_unir(&g->nts[i].first, &g->nts[i].regra->first)){
                mudou = 1;
            }
        }
    } while (mudou);
}

static int calc_follow_expr(Expr *e, Gramatica *g){
    int i, j, mudou = 0, resto_anulavel;
    if (e == NULL){
        return 0;
    }
    switch (e->tipo){
        case E_NAOTERM:
            if (bitset_unir(&g->nts[e->simbolo].follow, &e->follow)){
                mudou = 1;
            }
            break;
        case E_ALT:
        case E_OPC:
            for (i = 0; i < e->nfilhos; i++){
                if (bitset_unir(&e->filhos[i]->follow, &e->follow)){
                    mudou = 1;
                }
            }
            break;
        case E_REP:
            if (bitset_unir(&e->filhos[0]->follow, &e->follow)){
                mudou = 1;
            }
            if (bitset_unir(&e->filhos[0]->follow, &e->filhos[0]->first)){
                mudou = 1;
            }
            break;
        case E_SEQ:
            for (i = 0; i < e->nfilhos; i++){
                resto_anulavel = 1;
                for (j = i + 1; j < e->nfilhos; j++){
                    if (bitset_unir(&e->filhos[i]->follow, &e->filhos[j]->first)){
                        mudou = 1;
                    }
                    if (!e->filhos[j]->anulavel){
                        resto_anulavel = 0;
                        break;
                    }
                }
                if (resto_anulavel){
                    if (bitset_unir(&e->filhos[i]->follow, &e->follow)){
                        mudou = 1;
                    }
                }
            }
            break;
        case E_TERM:
        case E_VAZIO:
            break;
    }
    for (i = 0; i < e->nfilhos; i++){
        if (calc_follow_expr(e->filhos[i], g)){
            mudou = 1;
        }
    }
    return mudou;
}

void conj_follow(Gramatica *g){
    int i, mudou;
    if (g->inicial >= 0){
        bitset_add(&g->nts[g->inicial].follow, TERM_FIM);
    }
    do{
        mudou = 0;
        for (i = 0; i < g->nnts; i++){
            if (g->nts[i].regra == NULL){
                continue;
            }
            if (bitset_unir(&g->nts[i].regra->follow, &g->nts[i].follow)){
                mudou = 1;
            }
            if (calc_follow_expr(g->nts[i].regra, g)){
                mudou = 1;
            }
        }
    } while (mudou);
}
