// test_errors_eof_comment.mc - EOF ocorre dentro de um comentario de
// bloco, sem fechamento. Espera-se: ERRO LEXICO (linha N): EOF em comentario
//
// Rode com: ./lexer test_errors_eof_comment.mc

int main() {
    /* este comentario nunca fecha...
    int x;
    x = 1;
