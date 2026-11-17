// test_errors.mc - Casos de erro lexico que NAO terminam o arquivo
// (isto e, o scanner reporta o erro e continua lendo normalmente).
//
// Rode com: ./lexer test_errors.mc
// Cada ERRO LEXICO esperado esta comentado logo acima da linha que o causa.

int main() {
    int x;

    // caractere invalido isolado -> ERRO LEXICO: '@'
    x = @;

    // outro caractere invalido -> ERRO LEXICO: '#'
    x = #5;

    // "*/" sem "/*" correspondente -> ERRO LEXICO: Comentario nao iniciado
    x = 1 */ 2;

    // aspas simples vazias -> ERRO LEXICO: Constante de caractere mal formada
    x = '';

    // mais de um caractere entre aspas simples -> ERRO LEXICO: Constante de caractere mal formada
    x = 'ab';

    // aspas simples nao fechadas (ate o fim da linha) -> ERRO LEXICO: Aspas simples nao fechadas
    x = 'A;

    // string com quebra de linha nao escapada -> ERRO LEXICO: String nao terminada
    x = "linha
    quebrada";

    // depois do erro acima, a leitura volta ao normal nesta linha
    x = 1 + 1;

    return 0;
}
