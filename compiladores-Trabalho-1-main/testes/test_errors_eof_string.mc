// test_errors_eof_string.mc - EOF ocorre dentro de uma string, sem
// fechamento. Espera-se: ERRO LEXICO (linha N): EOF em string
//
// Rode com: ./lexer test_errors_eof_string.mc

int main() {
    print("esta string nunca fecha...