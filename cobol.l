%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Layout de colunas do formato fixo (especificacao, secao 2.1):
  1-6   area de sequencia
  7     indicador
  8-11  Area A
  12-72 Area B
  73-80 area de identificacao (ignorada) */
#define COLUNA_INDICADOR 7
#define COLUNA_INICIO_AREA_A 8
#define COLUNA_FIM_AREA_A 11
#define COLUNA_INICIO_AREA_B 12
#define COLUNA_FIM_AREA_B 72
#define COLUNA_FIM_LINHA 80

#define TAMANHO_MAXIMO_TEXTO 200000

int quantidade_de_erros = 0;

char texto_normalizado[TAMANHO_MAXIMO_TEXTO + 1];
int linha_de_origem[TAMANHO_MAXIMO_TEXTO];
int coluna_de_origem[TAMANHO_MAXIMO_TEXTO];
int tamanho_texto = 0;

int caracteres_consumidos = 0;
int linha_do_token = 0;
int coluna_do_token = 0;

void registrar_posicao_do_token(int tamanho_do_lexema) {
  linha_do_token = linha_de_origem[caracteres_consumidos];
  coluna_do_token = coluna_de_origem[caracteres_consumidos];
  caracteres_consumidos = caracteres_consumidos + tamanho_do_lexema;
}

#define YY_USER_ACTION registrar_posicao_do_token(yyleng);

enum Token {
  IDENTIFICATION = 258,
  ENVIRONMENT,
  DATA,
  PROCEDURE,
  DIVISION,
  SECTION,
  DISPLAY,
  ACCEPT,
  PERFORM,
  STOP,
  RUN,
  IF,
  ELSE,
  MOVE,
  NUMERICO,
  STRING,
  IDENTIFICADOR,
  PONTO,
  VIRGULA,
  PONTO_VIRGULA,
  ABRE_PARENTESES,
  FECHA_PARENTESES,
  IGUAL,
  MULTIPLICACAO,
  MAIS,
  MENOS,
  DIVISAO,
  MENOR_QUE,
  MAIOR_QUE,
  POTENCIA
};

const char *nomes_dos_tokens[] = {
  "IDENTIFICATION",
  "ENVIRONMENT",
  "DATA",
  "PROCEDURE",
  "DIVISION",
  "SECTION",
  "DISPLAY",
  "ACCEPT",
  "PERFORM",
  "STOP",
  "RUN",
  "IF",
  "ELSE",
  "MOVE",
  "NUMERICO",
  "STRING",
  "IDENTIFICADOR",
  "PONTO",
  "VIRGULA",
  "PONTO_VIRGULA",
  "ABRE_PARENTESES",
  "FECHA_PARENTESES",
  "IGUAL",
  "MULTIPLICACAO",
  "MAIS",
  "MENOS",
  "DIVISAO",
  "MENOR_QUE",
  "MAIOR_QUE",
  "POTENCIA"
};

const char *nome_token(int token) {
  return nomes_dos_tokens[token - IDENTIFICATION];
}
%}

%option noyywrap
%option nounput
%option noinput
%option case-insensitive

DIGITO [0-9]

%%

[ \t\r\n]+

IDENTIFICATION { return IDENTIFICATION; }
ENVIRONMENT { return ENVIRONMENT; }
DATA { return DATA; }
PROCEDURE { return PROCEDURE; }
DIVISION { return DIVISION; }
SECTION { return SECTION; }
DISPLAY { return DISPLAY; }
ACCEPT { return ACCEPT; }
PERFORM { return PERFORM; }
STOP { return STOP; }
RUN { return RUN; }
IF { return IF; }
ELSE { return ELSE; }
MOVE { return MOVE; }

[+-]?{DIGITO}+("."{DIGITO}+)? { return NUMERICO; }
\"[^\"\n]*\" { return STRING; }
\'[^\'\n]*\' { return STRING; }

[A-Z0-9]([A-Z0-9-]*[A-Z0-9])? {
  if (yyleng > 30) {
    fprintf(stderr, "Erro lexico linha %d, coluna %d: identificador com mais de 30 caracteres: '%s'\n", linha_do_token, coluna_do_token, yytext);
    quantidade_de_erros++;
  } else {
    return IDENTIFICADOR;
  }
}

-+[A-Z0-9]([A-Z0-9-]*[A-Z0-9])?-*|[A-Z0-9]([A-Z0-9-]*[A-Z0-9])?-+ {
  int inicia_com_hifen = yytext[0] == '-';
  int termina_com_hifen = yytext[yyleng - 1] == '-';
  const char *problema = "terminando com hifen";

  if (inicia_com_hifen && termina_com_hifen) {
    problema = "iniciando e terminando com hifen";
  } else if (inicia_com_hifen) {
    problema = "iniciando com hifen";
  }

  fprintf(stderr, "Erro lexico linha %d, coluna %d: identificador %s: '%s'\n", linha_do_token, coluna_do_token, problema, yytext);
  quantidade_de_erros++;

  if (yyleng > 30) {
    fprintf(stderr, "Erro lexico linha %d, coluna %d: identificador com mais de 30 caracteres: '%s'\n", linha_do_token, coluna_do_token, yytext);
    quantidade_de_erros++;
  }
}

"." { return PONTO; }
"," { return VIRGULA; }
";" { return PONTO_VIRGULA; }
"(" { return ABRE_PARENTESES; }
")" { return FECHA_PARENTESES; }
"=" { return IGUAL; }
"*" { return MULTIPLICACAO; }
"+" { return MAIS; }
"-" { return MENOS; }
"/" { return DIVISAO; }
"<" { return MENOR_QUE; }
">" { return MAIOR_QUE; }
"**" { return POTENCIA; }

. {
  fprintf(stderr, "Erro lexico linha %d, coluna %d: caractere invalido '%s'\n", linha_do_token, coluna_do_token, yytext);
  quantidade_de_erros++;
}

%%
int dentro_literal = 0;
char aspa_literal = ' ';

void adicionar_caractere(char caractere, int numero_linha, int coluna) {
  if (tamanho_texto >= TAMANHO_MAXIMO_TEXTO) {
    fprintf(stderr, "Erro: arquivo grande demais (limite de %d caracteres)\n", TAMANHO_MAXIMO_TEXTO);
    exit(1);
  }

  texto_normalizado[tamanho_texto] = caractere;
  linha_de_origem[tamanho_texto] = numero_linha;
  coluna_de_origem[tamanho_texto] = coluna;
  tamanho_texto++;
  texto_normalizado[tamanho_texto] = '\0';
}

void adicionar_trecho_codigo(const char linha[], int inicio, int fim, int numero_linha) {
  for (int coluna = inicio; coluna <= fim; coluna++) {
    char caractere = linha[coluna - 1];

    adicionar_caractere(caractere, numero_linha, coluna);

    if (dentro_literal) {
      if (caractere == aspa_literal) {
          dentro_literal = 0;
      }
    } else if (caractere == '"' || caractere == '\'') {
      dentro_literal = 1;
      aspa_literal = caractere;
    }
  }
}

void completar_ate_area_b(int ultima_coluna_lida, int numero_linha) {
    int coluna = ultima_coluna_lida + 1;

    if (coluna < COLUNA_INICIO_AREA_A) {
      coluna = COLUNA_INICIO_AREA_A;
    }

    while (coluna <= COLUNA_FIM_AREA_B) {
      adicionar_caractere(' ', numero_linha, coluna);
      coluna++;
    }
}

// LEITURA DO ARQUIVO
int ler_linha(FILE *arquivo, char linha[]) {
  int caractere = fgetc(arquivo);
  int colunas_lidas = 0;
  int leu = 0;

  while (caractere != EOF && caractere != '\n') {
    leu = 1;

    if (caractere == '\t') {
      do {
        if (colunas_lidas < COLUNA_FIM_LINHA) {
          linha[colunas_lidas] = ' ';
        }
        colunas_lidas++;
      } while (colunas_lidas % 8 != 0);
    } else if (caractere != '\r') {
      if (colunas_lidas < COLUNA_FIM_LINHA) {
        linha[colunas_lidas] = caractere;
      }
      colunas_lidas++;
    }

    caractere = fgetc(arquivo);
  }

  if (colunas_lidas > COLUNA_FIM_LINHA) {
    colunas_lidas = COLUNA_FIM_LINHA;
  }

  linha[colunas_lidas] = '\0';

  if (caractere == EOF && !leu) {
    return 0;
  }

  return 1;
}

// EXIBE SEPARAÇÃO DE COLUNAS
void copiar_colunas(const char linha[], int inicio, int fim, char destino[]) {
  int tamanho_linha = strlen(linha);
  int posicao = 0;

  for (int coluna = inicio; coluna <= fim; coluna++) {
    if (coluna <= tamanho_linha) {
      destino[posicao] = linha[coluna - 1];
    } else {
      destino[posicao] = ' ';
    }

    posicao++;
  }

  destino[posicao] = '\0';
}

void mostrar_cabecalho_colunas(void) {
    printf("=== SEPARACAO DE COLUNAS (formato fixo) ===\n");
    printf("%4s | %-6s | %s | %-4s | %-61s | %-8s | %s\n",
           "Lin", "1-6", "7", "8-11", "12-72", "73-80", "Tipo");
    printf("%4s | %-6s | %s | %-4s | %-61s | %-8s |\n",
           "", "Seq", "I", "A", "B", "Ident");
    printf("-----+--------+---+------+"
           "---------------------------------------------------------------"
           "+----------+------------\n");
}

void mostrar_linha(int numero_linha, const char linha[], const char *tipo) {
  char sequencia[7];
  char indicador[2];
  char area_a[5];
  char area_b[62];
  char identificacao[9];

  copiar_colunas(linha, 1, 6, sequencia);
  copiar_colunas(linha, COLUNA_INDICADOR, COLUNA_INDICADOR, indicador);
  copiar_colunas(linha, COLUNA_INICIO_AREA_A, COLUNA_FIM_AREA_A, area_a);
  copiar_colunas(linha, COLUNA_INICIO_AREA_B, COLUNA_FIM_AREA_B, area_b);
  copiar_colunas(linha, COLUNA_FIM_AREA_B + 1, COLUNA_FIM_LINHA, identificacao);

  printf("%4d | %s | %s | %s | %s | %s | %s\n", numero_linha, sequencia, indicador, area_a, area_b, identificacao, tipo);
}

int area_vazia(const char linha[], int ultima_coluna) {
  for (int coluna = COLUNA_INICIO_AREA_A; coluna <= ultima_coluna; coluna++) {
    if (linha[coluna - 1] != ' ') {
      return 0;
    }
  }

  return 1;
}

void processar_linha(const char linha[], int ultima_coluna, int numero_linha) {
  if (area_vazia(linha, ultima_coluna)) {
    mostrar_linha(numero_linha, linha, "vazia");
  } else {
    mostrar_linha(numero_linha, linha, "codigo");
  }

  if (dentro_literal) {
    fprintf(stderr, "Erro lexico linha %d: literal nao fechado na linha anterior\n", numero_linha);
    quantidade_de_erros++;
    dentro_literal = 0;
  }

  adicionar_caractere('\n', numero_linha, 0);
  adicionar_trecho_codigo(linha, COLUNA_INICIO_AREA_A, ultima_coluna, numero_linha);

  if (dentro_literal) {
    completar_ate_area_b(ultima_coluna, numero_linha);
  }
}

void processar_continuacao(const char linha[], int ultima_coluna, int numero_linha) {
  mostrar_linha(numero_linha, linha, "continuacao");

  if (tamanho_texto == 0) {
    fprintf(stderr, "Erro lexico linha %d: continuacao sem linha anterior\n", numero_linha);
    quantidade_de_erros++;
    return;
  }

  int coluna = COLUNA_INICIO_AREA_A;

  while (coluna <= ultima_coluna && linha[coluna - 1] == ' ') {
    coluna++;
  }

  if (dentro_literal) {
    if (coluna <= ultima_coluna && linha[coluna - 1] == aspa_literal) {
      coluna++;
    } else {
      fprintf(stderr, "Erro lexico linha %d: continuacao de literal sem aspas\n", numero_linha);
      quantidade_de_erros++;
    }
  } else {
    adicionar_caractere(' ', numero_linha, coluna);
  }

  adicionar_trecho_codigo(linha, coluna, ultima_coluna, numero_linha);

  if (dentro_literal) {
    completar_ate_area_b(ultima_coluna, numero_linha);
  }
}

int ultima_coluna_de_codigo(const char linha[]) {
  int tamanho = strlen(linha);

  if (tamanho > COLUNA_FIM_AREA_B) {
    return COLUNA_FIM_AREA_B;
  }

  return tamanho;
}

char indicador_da_linha(const char linha[]) {
  if (strlen(linha) < COLUNA_INDICADOR) {
    return ' ';
  }

  return linha[COLUNA_INDICADOR - 1];
}

void processar_indicador_invalido(const char linha[], char indicador, int numero_linha) {
  mostrar_linha(numero_linha, linha, "INDICADOR INVALIDO");
  fprintf(stderr, "Erro lexico linha %d: indicador invalido '%c' na coluna 7\n", numero_linha, indicador);
  quantidade_de_erros++;
}

void classificar_linha(const char linha[], int numero_linha) {
  int ultima_coluna = ultima_coluna_de_codigo(linha);
  char indicador = indicador_da_linha(linha);

  switch (indicador) {
    case ' ':
      processar_linha(linha, ultima_coluna, numero_linha);
      break;
    case '-':
      processar_continuacao(linha, ultima_coluna, numero_linha);
      break;
    case '*':
    case '/':
      mostrar_linha(numero_linha, linha, "comentario");
      break;
    case 'D':
    case 'd':
      mostrar_linha(numero_linha, linha, "depuracao");
      break;
    default:
      processar_indicador_invalido(linha, indicador, numero_linha);
      break;
  }
}

void verificar_literal_no_fim(void) {
  if (dentro_literal) {
    fprintf(stderr, "Erro lexico: literal nao fechado no fim do arquivo\n");
    quantidade_de_erros++;
  }
}

void preprocessar(FILE *arquivo) {
  char linha[COLUNA_FIM_LINHA + 1];
  int numero_linha = 0;

  mostrar_cabecalho_colunas();

  while (ler_linha(arquivo, linha)) {
    numero_linha++;
    classificar_linha(linha, numero_linha);
  }

  verificar_literal_no_fim();
}

int main(int argc, char *argv[]) {
  FILE *arquivo = stdin;

  if (argc > 1) {
    arquivo = fopen(argv[1], "r");
    if (arquivo == NULL) {
      perror(argv[1]);
      return 1;
    }
  }

  preprocessar(arquivo);

  if (arquivo != stdin) {
    fclose(arquivo);
  }

  /* Garante que a tabela de colunas saia antes dos erros dos tokens */
  fflush(stdout);

  printf("\n=== TOKENS ===\n");
  printf("%-9s %-5s %-18s %s\n", "Lin:Col", "Area", "Token", "Lexema");
  printf("--------- ----- ------------------ ----------------\n");

  yy_scan_string(texto_normalizado);

  int token = yylex();
  while (token != 0) {
    const char *area = "B";
    if (coluna_do_token <= COLUNA_FIM_AREA_A) {
      area = "A";
    }

    printf("%4d:%-4d %-5s %-18s %s\n", linha_do_token, coluna_do_token, area, nome_token(token), yytext);

    token = yylex();
  }

  if (quantidade_de_erros > 0) {
    return 1;
  }

  return 0;
}
