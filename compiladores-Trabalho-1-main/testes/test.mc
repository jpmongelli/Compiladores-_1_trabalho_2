// test.mc - Programa de teste para o scanner de Micro C
//
// Este arquivo exercita boa parte dos tokens da linguagem: palavras
// reservadas, identificadores, constantes inteiras (positivas e
// negativas), de caractere e de string (com escapes), operadores
// aritmeticos, relacionais e logicos, simbolos de pontuacao, alem de
// comentarios de linha e de bloco.
//
// Casos de ERRO lexico ficam em arquivos separados (veja test_errors.mc
// e test_errors_eof_string.mc / test_errors_eof_comment.mc), ja que um
// erro fatal (EOF dentro de string/comentario) interrompe a leitura do
// restante do arquivo.

/* Calcula o fatorial de um numero inteiro utilizando um laco for. */
int fatorial(int n) {
    int resultado;
    int i;

    resultado = 1;
    for (i = 1; i <= n; i = i + 1) {
        resultado = resultado * i;
    }
    return resultado;
}

int main() {
    int x;
    int y;
    int z;
    char c;
    char letras[10];

    x = 5;
    y = fatorial(x);
    z = -10;              // constante inteira negativa
    z = x - 3;             // "-" como operador de subtracao (com espacos)
    z = y-3;               // "-" como operador de subtracao (sem espacos)
    z = -3 + x;             // "-" como sinal, logo apos "="
    z = (x)-3;              // "-" como subtracao, logo apos ")"
    z = letras[0]-1;        // "-" como subtracao, logo apos "]"

    if (y > 100) {
        print("Resultado grande");
    } else {
        print("Resultado pequeno");
    }

    c = 'A';
    c = '\n';
    c = '\t';
    c = '\\';
    c = '\"';
    c = '\0';
    letras[0] = 'H';
    letras[1] = 'i';

    print("linha com escape:\ttabulado e\nquebrado");
    print("aspas escapadas: \" e barra: \\");

    // Testando operadores relacionais e logicos
    if (x >= 0 && y != 0) {
        print("x e nao-negativo e y e diferente de zero");
    }

    if (x == 5 || y == 0) {
        print("condicao ou satisfeita");
    }

    if (!(x < 0)) {
        print("x nao e negativo");
    }

    if (x <= 5 && y >= -1) {
        print("faixa valida");
    }

    return 0;
}
