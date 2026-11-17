aluno: 2019.1904.005-6


# Compiladores I — Trabalho Prático 2: Gerador de Analisadores Sintáticos Descendentes Recursivos

Aluno: João Pedro Godinho Mongelli (2019.1904.005-6)
Disciplina: Compiladores I — FACOM / UFMS

## Compilar e executar

```
make                      # compila o gerador (e o analisador de Micro C, se o TP1 estiver em microc/)
make test                 # executa os testes de testes/
make microc               # gera e compila build/microc/parser_microc
make clean                # remove build/ e o executavel gerador
```

```
./gerador gramatica.ebnf -o saida/parser [--scanner microc] [--sets] [--tree] [--debug]
gcc -ansi -pedantic -Wall -Wextra -o parser saida/parser.c
./parser [--tree] programa.txt        # ou: ./parser --tokens tokens.txt
```

Todo o código compila sem avisos com gcc -ansi -pedantic -Wall -Wextra.

## Estrutura implementada

- src/ebnf_parser.c: leitura das expressões das regras EBNF (parse_expr, parse_seq, parse_fator).
- src/verificacao.c: verificação de não-terminais inalcançáveis, improdutivos e recursão à esquerda direta e indireta.
- src/conjuntos.c: cálculo de anulável, FIRST e FOLLOW por ponto fixo.
- src/ll1.c: verificação das três condições LL(1).
- src/codegen.c: geração do analisador descendente recursivo em ANSI C (gen_expr), casamento de expressões regulares por AFN/AFD (gen_casamento_regex) e leitura de arquivo de tokens (gen_token_de_arquivo).
- src/microc_mapa.c: leitura da enumeração TokenType do arquivo tokens.h do TP1 (microc_carregar_tokens_h).

## Integração e correções feitas no scanner do TP1 (microc/)

O scanner desenvolvido no TP1 foi copiado para a pasta microc/ e adaptado com as seguintes correções em relação à entrega do TP1:

1. Adicionada a opção %option prefix="microc_yy" noyywrap no arquivo microc/microc.flex.
2. Extraídas as declarações da enumeração TokenType, da tabela de strings (StringTable) e das variáveis globais (linha_atual, token_atributo, error_msg) para microc/tokens.h.
3. Adicionada a regra <INITIAL><<EOF>> devolvendo END_OF_FILE no microc.flex.
4. Removida a função main() do final do microc.flex para utilizar a função main() do analisador sintático gerado.
5. Ajustado o tratamento de erros léxicos para preencher a variável error_msg e devolver UNDEF, permitindo que microc/scanner.c repasse a mensagem ao analisador.
6. Corrigida a contagem de linha na regra <STRING>\n do microc.flex: substituído linha_atual++ por yyless(0) para que o erro "String nao terminada" seja reportado na linha em que a string foi aberta.
7. Ajustada a expressão regular de ID para [a-zA-Z_][a-zA-Z0-9_]* e adaptado microc/scanner.c para buscar os lexemas de ID e STRINGCONST na tabela de strings com get_string(&st, token_atributo).

## Testes

A pasta testes/ contém 5 gramáticas e os programas de teste (24 testes no total pelo comando make test):

- testes/gramaticas/expr.ebnf: gramática de expressões aritméticas (3 programas aceitos e 4 rejeitados em testes/programas/expr/).
- testes/gramaticas/json.ebnf: gramática para JSON (3 programas aceitos e 3 rejeitados em testes/programas/json/).
- testes/gramaticas/microc.ebnf: gramática de Micro C integrada ao scanner do TP1 (3 programas aceitos e 3 rejeitados em testes/programas/microc/).
- testes/gramaticas/conflito_ll1.ebnf: gramática com conflitos LL(1).
- testes/gramaticas/recursao_esquerda.ebnf: gramática com recursão à esquerda, regra improdutiva e regra inalcançável.
