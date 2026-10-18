; ============================================================================
;  CIDADE ICMC - jogo de construir cidade para o Processador ICMC
;  SSC0513 Organizacao e Arquitetura de Computadores - ICMC-USP - 2026
;
;  Objetivo: chegar a 100 mil habitantes no menor tempo.
;  Regras e balanceamento: DESIGN.md
;
;  Tela (40 x 30 caracteres):
;    linhas 0 a 4   : painel (dinheiro, populacao, gargalo, energia, roleta)
;    linha 5        : separador
;    linhas 6 a 29  : cidade, grid de 20 x 12 blocos de 2 x 2 caracteres
;
;  Convencoes:
;    - populacao, casas, servico e empregos sao guardados em DEZENAS de
;      pessoas (100 mil = 10000) para caber em 16 bits; na tela imprime-se
;      um "0" a mais no fim.
;    - toda rotina salva na pilha os registradores que usa.
;    - cor = numero somado ao caractere (tabela abaixo).
;
;  Cores:  0 branco     256 marrom   512 verde    768 oliva
;          1024 marinho 1280 roxo    1536 teal    1792 prata
;          2048 cinza   2304 vermelho 2560 lima   2816 amarelo
;          3072 azul    3328 rosa    3584 aqua    3840 preto
; ============================================================================

jmp main

; ----------------------------------------------------------------------------
;  Estado do jogo
; ----------------------------------------------------------------------------
tipo : var #240         ; tipo de cada bloco: 0 vazio, 1 casa, 2 comercio,
                        ; 3 industria, 4 usina pequena, 5 usina grande
nivel : var #240        ; nivel de cada bloco (1 a 3; usina sempre 1)
luz : var #240          ; 1 se o bloco recebeu energia na ultima conta
terreno : var #240      ; chao de cada bloco: 0 grama, 1 terra, 2 grama (outro desenho)
semente : var #1        ; estado do gerador de numeros aleatorios

sel : var #1            ; bloco selecionado (0 a 239)
ferr : var #1           ; acao da roleta: 0 casa ... 4 usina grande, 5 demolir
dinheiro : var #1
popul : var #1            ; populacao em dezenas
prod : var #1           ; energia produzida pelas usinas
cons : var #1           ; energia pedida por todos os blocos (com e sem luz)
apagao : var #1         ; 1 se cons > prod

; Os tres grupos abaixo ficam em sequencia (casa, comercio, industria) para
; serem acessados como vetor: endereco = base + (tipo - 1).
totR : var #1           ; casas (dezenas de pessoas) dos blocos com luz
totC : var #1           ; servico do comercio
totI : var #1           ; empregos da industria
eR : var #1             ; energia consumida pelas casas com luz
eC : var #1
eI : var #1
candR : var #1          ; blocos com luz que ainda podem subir de nivel
candC : var #1
candI : var #1

ticks : var #1          ; atualizacoes feitas (cada uma vale 10 s de jogo)
subtick : var #1        ; 0 a 9: posicao na barra de ritmo
voltas : var #1         ; voltas do laco principal desde o ultimo subtick
venceu : var #1
cursorAceso : var #1    ; 1 = cursor mostrando o contorno
piscaVoltas : var #1    ; voltas desde a ultima troca do cursor

; Voltas do laco principal entre duas trocas do cursor (pisca). Metade de
; voltasPorSub: o cursor troca a cada ~0,5 s.
voltasPisca : var #1
static voltasPisca + #0, #8050

; Ritmo. Cada volta do laco principal custa cerca de 2 * esperaN + 31
; instrucoes. O simulador do professor roda ~32,7 milhoes de instrucoes por
; segundo (medido em 18/10/2026), entao 16100 voltas = 1 s = 1 subtick e
; 10 subticks = 1 atualizacao = 10 s. Calibrar: ver FERRAMENTAS.md.
esperaN : var #1
static esperaN + #0, #1000
voltasPorSub : var #1
static voltasPorSub + #0, #16100

; ----------------------------------------------------------------------------
;  Tabelas
; ----------------------------------------------------------------------------
custo : var #6          ; por tipo
static custo + #0, #0
static custo + #1, #40
static custo + #2, #60
static custo + #3, #150
static custo + #4, #400
static custo + #5, #2500

corTipo : var #6
static corTipo + #0, #3584      ; chao (a cor real vem de corTerreno)
static corTipo + #1, #2816      ; casa: amarelo
static corTipo + #2, #3328      ; comercio: rosa
static corTipo + #3, #2048      ; industria: cinza
static corTipo + #4, #2304      ; usinas: vermelho
static corTipo + #5, #2304

corTerreno : var #3     ; cor do chao por terreno
static corTerreno + #0, #3584   ; grama: aqua (verde claro)
static corTerreno + #1, #256    ; terra: marrom
static corTerreno + #2, #3584

capNivel : var #4       ; casas / servico / empregos por nivel, em dezenas
static capNivel + #0, #0
static capNivel + #1, #10       ; 100 pessoas
static capNivel + #2, #50       ; 500
static capNivel + #3, #300      ; 3000

energia : var #16       ; consumo por (tipo * 4 + nivel), tipos 0 a 3
static energia + #5, #1         ; casa
static energia + #6, #2
static energia + #7, #5
static energia + #9, #1         ; comercio
static energia + #10, #3
static energia + #11, #6
static energia + #13, #2        ; industria
static energia + #14, #5
static energia + #15, #10

; Desenho de cada bloco: 4 caracteres (sup. esq., sup. dir., inf. esq.,
; inf. dir.) em glifo + (tipo * 4 + nivel) * 4. Os desenhos ficam em
; arte/blocos.txt; arte/gera_arte.py gera o charmap.mif e a tabela abaixo.
; >>> glifos (gerado por arte/gera_arte.py a partir de arte/blocos.txt)
glifo : var #96
static glifo + #0, #1          ; grama
static glifo + #1, #2
static glifo + #2, #3
static glifo + #3, #4
static glifo + #4, #9          ; terra
static glifo + #5, #10
static glifo + #6, #11
static glifo + #7, #12
static glifo + #8, #5          ; grama2
static glifo + #9, #6
static glifo + #10, #7
static glifo + #11, #8
static glifo + #20, #17          ; casa1
static glifo + #21, #18
static glifo + #22, #19
static glifo + #23, #20
static glifo + #24, #21          ; casa2
static glifo + #25, #22
static glifo + #26, #23
static glifo + #27, #24
static glifo + #28, #25          ; casa3
static glifo + #29, #26
static glifo + #30, #27
static glifo + #31, #28
static glifo + #36, #29          ; comercio1
static glifo + #37, #30
static glifo + #38, #31
static glifo + #39, #97
static glifo + #40, #98          ; comercio2
static glifo + #41, #99
static glifo + #42, #100
static glifo + #43, #101
static glifo + #44, #102          ; comercio3
static glifo + #45, #103
static glifo + #46, #104
static glifo + #47, #105
static glifo + #52, #106          ; industria1
static glifo + #53, #107
static glifo + #54, #108
static glifo + #55, #109
static glifo + #56, #110          ; industria2
static glifo + #57, #111
static glifo + #58, #112
static glifo + #59, #113
static glifo + #60, #114          ; industria3
static glifo + #61, #115
static glifo + #62, #116
static glifo + #63, #117
static glifo + #68, #118          ; usina_pequena
static glifo + #69, #119
static glifo + #70, #120
static glifo + #71, #121
static glifo + #84, #122          ; usina_grande
static glifo + #85, #123
static glifo + #86, #124
static glifo + #87, #125
glifoSel : var #4
static glifoSel + #0, #13          ; cursor
static glifoSel + #1, #14
static glifoSel + #2, #15
static glifoSel + #3, #16
; <<< glifos

; Nomes da roleta: 6 nomes de 12 letras + '\0' (13 posicoes cada)
nomes : string "CASA        "
        string "COMERCIO    "
        string "INDUSTRIA   "
        string "USINA PEQ.  "
        string "USINA GRANDE"
        string "DEMOLIR     "

; ----------------------------------------------------------------------------
;  Textos
; ----------------------------------------------------------------------------
txtLinha  : string "----------------------------------------"
txtHud1   : string "DINHEIRO $         POPULACAO           "
txtHud2   : string "CASA         SERV         EMPR         "
txtHud3   : string "ENERGIA     /       TEMPO   :          "
txtHud4   : string "J <              $        > K  ESPACO "
txtHud5   : string "RITMO [          ]                     "

msgLimpa    : string "                    "
msgOcupado  : string "LOTE OCUPADO        "
msgVazio    : string "LOTE VAZIO          "
msgDinheiro : string "SEM DINHEIRO        "
msgLibera   : string "PRECISA 20000 HAB.  "
msgApagao   : string "APAGAO! FACA USINA  "

ini1  : string "C I D A D E   I C M C"
ini2  : string "VOCE E O PREFEITO. LEVE A CIDADE A"
ini3  : string "100 MIL HABITANTES NO MENOR TEMPO."
ini4  : string "CASA       LUGAR PARA MORAR"
ini5  : string "COMERCIO   SEM ELE O POVO VAI EMBORA"
ini6  : string "INDUSTRIA  SEM EMPREGO O POVO SAI"
ini7  : string "USINA      ENERGIA, MAS TEM LIMITE"
ini8  : string "QUEM MORA E TRABALHA PAGA A LUZ:"
ini9  : string "E DAI QUE VEM O DINHEIRO."
ini10 : string "WASD OU SETAS  ANDAR"
ini11 : string "J / K          ESCOLHER A ACAO"
ini12 : string "ESPACO         CONSTRUIR"
ini13 : string "+              ADIANTAR O TEMPO"
ini14 : string "ENTER PARA COMECAR"

fim1 : string "1 0 0   M I L   H A B I T A N T E S"
fim2 : string "TEMPO:   :"
fim3 : string "ENTER PARA JOGAR DE NOVO"

; ============================================================================
;  Programa principal
; ============================================================================
main:
    call TelaInicio
    call NovoJogo
    call DesenhaTudo

Laco:
    inchar r0                   ; 255 = nenhuma tecla
    loadn r1, #255
    cmp r0, r1
    jeq Laco_semTecla
    call TrataTecla
Laco_semTecla:
    call Espera
    call Pisca
    load r0, voltas
    inc r0
    store voltas, r0
    load r1, voltasPorSub
    cmp r0, r1
    jne Laco_fim
    loadn r0, #0
    store voltas, r0
    call Subtick
Laco_fim:
    load r0, venceu
    loadn r1, #0
    cmp r0, r1
    jeq Laco
    call TelaFim
    jmp main

; ----------------------------------------------------------------------------
;  Espera: atraso curto em cada volta do laco principal
; ----------------------------------------------------------------------------
Espera:
    push r0
    load r0, esperaN
Espera_loop:
    dec r0
    jnz Espera_loop
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Pisca: a cada voltasPisca voltas troca o cursor entre contorno e bloco
; ----------------------------------------------------------------------------
Pisca:
    push r0
    push r1
    load r0, piscaVoltas
    inc r0
    load r1, voltasPisca
    cmp r0, r1
    jne Pisca_fim
    load r0, cursorAceso
    loadn r1, #1
    xor r0, r0, r1
    store cursorAceso, r0
    load r0, sel
    call DesenhaBloco
    loadn r0, #0
Pisca_fim:
    store piscaVoltas, r0
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Subtick: avanca a barra de ritmo; a cada 10 subticks faz uma atualizacao
; ----------------------------------------------------------------------------
Subtick:
    push r0
    push r1
    push r2
    load r0, subtick
    loadn r1, #167             ; posicao do primeiro '=' da barra (linha 4)
    add r1, r1, r0
    loadn r2, #'='
    outchar r2, r1
    inc r0
    store subtick, r0
    loadn r1, #10
    cmp r0, r1
    jne Subtick_fim
    call Tick
Subtick_fim:
    pop r2
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  NovoJogo: zera o mapa, poe a vila inicial e os valores de partida
; ----------------------------------------------------------------------------
NovoJogo:
    push r0
    push r1
    push r2
    push r3
    loadn r0, #0
    loadn r1, #240
    loadn r3, #0
NovoJogo_zera:
    loadn r2, #tipo
    add r2, r2, r0
    storei r2, r3
    loadn r2, #nivel
    add r2, r2, r0
    storei r2, r3
    loadn r2, #luz
    add r2, r2, r0
    storei r2, r3
    inc r0
    cmp r0, r1
    jne NovoJogo_zera

    store popul, r3
    store ticks, r3
    store subtick, r3
    store voltas, r3
    store venceu, r3
    store ferr, r3
    store piscaVoltas, r3
    loadn r0, #1
    store cursorAceso, r0
    loadn r0, #500
    store dinheiro, r0
    loadn r0, #130              ; selecao logo abaixo da vila
    store sel, r0

    call GeraTerreno

    ; vila inicial na linha 5 do grid: usina, casa, comercio, industria
    loadn r3, #1
    loadn r0, #108
    loadn r1, #4
    call PoeBloco
    loadn r0, #109
    loadn r1, #1
    call PoeBloco
    loadn r0, #110
    loadn r1, #2
    call PoeBloco
    loadn r0, #111
    loadn r1, #3
    call PoeBloco

    pop r3
    pop r2
    pop r1
    pop r0
    rts

; PoeBloco: r0 = bloco, r1 = tipo; nivel vira 1
PoeBloco:
    push r2
    push r3
    loadn r2, #tipo
    add r2, r2, r0
    storei r2, r1
    loadn r2, #nivel
    add r2, r2, r0
    loadn r3, #1
    storei r2, r3
    pop r3
    pop r2
    rts

; ----------------------------------------------------------------------------
;  DesenhaTudo: tela do jogo completa (painel fixo, mapa e valores)
; ----------------------------------------------------------------------------
DesenhaTudo:
    push r0
    push r1
    push r2
    call ApagaTela
    loadn r2, #0
    loadn r0, #200
    loadn r1, #txtLinha
    call ImprimeStr
    loadn r0, #0
    loadn r1, #txtHud1
    call ImprimeStr
    loadn r0, #40
    loadn r1, #txtHud2
    call ImprimeStr
    loadn r0, #80
    loadn r1, #txtHud3
    call ImprimeStr
    loadn r0, #120
    loadn r1, #txtHud4
    call ImprimeStr
    loadn r0, #160
    loadn r1, #txtHud5
    call ImprimeStr
    call Recalcula
    call DesenhaMapa
    call DesenhaHud
    call DesenhaRoleta
    pop r2
    pop r1
    pop r0
    rts

; DesenhaMapa: redesenha os 240 blocos
DesenhaMapa:
    push r0
    push r1
    loadn r0, #0
    loadn r1, #240
DesenhaMapa_loop:
    call DesenhaBloco
    inc r0
    cmp r0, r1
    jne DesenhaMapa_loop
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  DesenhaBloco: desenha o bloco r0 (2 x 2 caracteres)
;    cor: rosa se selecionado, cinza se esta sem luz, senao a cor do tipo
; ----------------------------------------------------------------------------
DesenhaBloco:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r5
    push r6

    ; r2 = posicao na tela do canto superior esquerdo
    ;    = 240 + (bloco / 20) * 80 + (bloco % 20) * 2
    loadn r1, #20
    div r2, r0, r1
    mod r3, r0, r1
    loadn r1, #80
    mul r2, r2, r1
    add r2, r2, r3
    add r2, r2, r3
    loadn r1, #240              ; o mapa comeca na linha 6
    add r2, r2, r1

    loadn r1, #tipo
    add r1, r1, r0
    loadi r3, r1                ; r3 = tipo
    loadn r1, #nivel
    add r1, r1, r0
    loadi r4, r1                ; r4 = nivel
    loadn r1, #0                ; chao: o "nivel" e' o terreno (grama/terra)
    cmp r3, r1
    jne DesenhaBloco_temNivel
    loadn r1, #terreno
    add r1, r1, r0
    loadi r4, r1
DesenhaBloco_temNivel:

    ; r5 = glifo + (tipo * 4 + nivel) * 4
    loadn r1, #4
    mul r5, r3, r1
    add r5, r5, r4
    mul r5, r5, r1
    loadn r1, #glifo
    add r5, r5, r1

    ; cursor: o bloco selecionado alterna entre o contorno branco e o
    ; proprio bloco (cada caractere tem uma cor so, entao nao da para
    ; desenhar o contorno por cima do bloco)
    load r1, sel
    cmp r0, r1
    jne DesenhaBloco_naoSel
    load r1, cursorAceso
    loadn r6, #0
    cmp r1, r6
    jeq DesenhaBloco_naoSel
    loadn r5, #glifoSel
    loadn r6, #0                ; branco
    jmp DesenhaBloco_desenha

DesenhaBloco_naoSel:
    loadn r1, #corTipo
    add r1, r1, r3
    loadi r6, r1
    loadn r1, #0
    cmp r3, r1
    jne DesenhaBloco_predio
    loadn r1, #corTerreno       ; chao: cor do terreno, nao depende de luz
    add r1, r1, r4
    loadi r6, r1
    jmp DesenhaBloco_desenha
DesenhaBloco_predio:
    loadn r1, #luz
    add r1, r1, r0
    loadi r1, r1
    loadn r4, #0
    cmp r1, r4
    jne DesenhaBloco_desenha
    loadn r6, #1024             ; sem luz: azul marinho (apagado)

DesenhaBloco_desenha:
    loadi r1, r5
    add r1, r1, r6
    outchar r1, r2
    inc r5
    inc r2
    loadi r1, r5
    add r1, r1, r6
    outchar r1, r2
    inc r5
    loadn r1, #39               ; desce uma linha e volta uma coluna
    add r2, r2, r1
    loadi r1, r5
    add r1, r1, r6
    outchar r1, r2
    inc r5
    inc r2
    loadi r1, r5
    add r1, r1, r6
    outchar r1, r2

    pop r6
    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  TrataTecla: r0 = tecla lida
;    setas do simulador: 14 esquerda, 15 direita, 16 cima, 17 baixo
; ----------------------------------------------------------------------------
TrataTecla:
    push r0
    push r1

    loadn r1, #16
    cmp r0, r1
    jeq TrataTecla_cima
    loadn r1, #17
    cmp r0, r1
    jeq TrataTecla_baixo
    loadn r1, #14
    cmp r0, r1
    jeq TrataTecla_esq
    loadn r1, #15
    cmp r0, r1
    jeq TrataTecla_dir

    loadn r1, #32               ; letra maiuscula vira minuscula (bit 5)
    or r0, r0, r1

    loadn r1, #'w'
    cmp r0, r1
    jeq TrataTecla_cima
    loadn r1, #'s'
    cmp r0, r1
    jeq TrataTecla_baixo
    loadn r1, #'a'
    cmp r0, r1
    jeq TrataTecla_esq
    loadn r1, #'d'
    cmp r0, r1
    jeq TrataTecla_dir
    loadn r1, #'j'
    cmp r0, r1
    jeq TrataTecla_ant
    loadn r1, #'k'
    cmp r0, r1
    jeq TrataTecla_prox
    loadn r1, #32
    cmp r0, r1
    jeq TrataTecla_aplica
    loadn r1, #'+'
    cmp r0, r1
    jeq TrataTecla_tempo
    jmp TrataTecla_fim

TrataTecla_cima:
    call MoveCima
    jmp TrataTecla_fim
TrataTecla_baixo:
    call MoveBaixo
    jmp TrataTecla_fim
TrataTecla_esq:
    call MoveEsq
    jmp TrataTecla_fim
TrataTecla_dir:
    call MoveDir
    jmp TrataTecla_fim
TrataTecla_ant:
    load r0, ferr               ; ferr = (ferr + 5) % 6
    loadn r1, #5
    add r0, r0, r1
    loadn r1, #6
    mod r0, r0, r1
    store ferr, r0
    call DesenhaRoleta
    jmp TrataTecla_fim
TrataTecla_prox:
    load r0, ferr               ; ferr = (ferr + 1) % 6
    inc r0
    loadn r1, #6
    mod r0, r0, r1
    store ferr, r0
    call DesenhaRoleta
    jmp TrataTecla_fim
TrataTecla_aplica:
    call Aplica
    jmp TrataTecla_fim
TrataTecla_tempo:
    call Tick
TrataTecla_fim:
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Movimento da selecao. NovaSel troca a selecao para r1 e redesenha os dois
;  blocos.
; ----------------------------------------------------------------------------
MoveCima:
    push r0
    push r1
    load r0, sel
    loadn r1, #20
    cmp r0, r1
    jle MoveCima_fim            ; ja esta na primeira linha
    sub r1, r0, r1
    call NovaSel
MoveCima_fim:
    pop r1
    pop r0
    rts

MoveBaixo:
    push r0
    push r1
    load r0, sel
    loadn r1, #220
    cmp r0, r1
    jeg MoveBaixo_fim           ; ja esta na ultima linha
    loadn r1, #20
    add r1, r0, r1
    call NovaSel
MoveBaixo_fim:
    pop r1
    pop r0
    rts

MoveEsq:
    push r0
    push r1
    push r2
    load r0, sel
    loadn r1, #20
    mod r2, r0, r1
    loadn r1, #0
    cmp r2, r1
    jeq MoveEsq_fim             ; ja esta na primeira coluna
    mov r1, r0
    dec r1
    call NovaSel
MoveEsq_fim:
    pop r2
    pop r1
    pop r0
    rts

MoveDir:
    push r0
    push r1
    push r2
    load r0, sel
    loadn r1, #20
    mod r2, r0, r1
    loadn r1, #19
    cmp r2, r1
    jeq MoveDir_fim             ; ja esta na ultima coluna
    mov r1, r0
    inc r1
    call NovaSel
MoveDir_fim:
    pop r2
    pop r1
    pop r0
    rts

; NovaSel: r0 = selecao antiga, r1 = selecao nova
NovaSel:
    push r0
    push r2
    store sel, r1
    loadn r2, #1                ; cursor aparece na hora e recomeca a piscar
    store cursorAceso, r2
    loadn r2, #0
    store piscaVoltas, r2
    call DesenhaBloco           ; antiga volta a cor normal
    mov r0, r1
    call DesenhaBloco           ; nova com o contorno
    pop r2
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Aplica: executa a acao da roleta no bloco selecionado
; ----------------------------------------------------------------------------
Aplica:
    push r0
    push r1
    push r2
    push r3
    push r4

    load r0, sel
    loadn r1, #tipo
    add r1, r1, r0
    loadi r2, r1                ; r2 = tipo atual do bloco
    load r3, ferr
    loadn r4, #5
    cmp r3, r4
    jeq Aplica_demolir

    ; construir: so em bloco vazio
    loadn r4, #0
    cmp r2, r4
    jne Aplica_ocupado
    inc r3                      ; r3 = tipo novo (ferr + 1)
    loadn r4, #5
    cmp r3, r4
    jne Aplica_preco
    load r4, popul                ; usina grande pede 20 mil habitantes
    loadn r2, #2000
    cmp r4, r2
    jle Aplica_libera
Aplica_preco:
    loadn r4, #custo
    add r4, r4, r3
    loadi r4, r4                ; r4 = custo
    load r2, dinheiro
    cmp r2, r4
    jle Aplica_semDinheiro
    sub r2, r2, r4
    store dinheiro, r2
    mov r1, r3
    call PoeBloco
    jmp Aplica_redesenha

Aplica_demolir:
    loadn r4, #0
    cmp r2, r4
    jeq Aplica_vazio
    loadn r4, #custo            ; devolve metade do custo
    add r4, r4, r2
    loadi r1, r4
    loadn r4, #2
    div r1, r1, r4
    push r0
    load r0, dinheiro
    call SomaSat
    store dinheiro, r0
    pop r0
    loadn r1, #tipo
    add r1, r1, r0
    loadn r4, #0
    storei r1, r4
    loadn r1, #nivel
    add r1, r1, r0
    storei r1, r4

Aplica_redesenha:
    call Recalcula
    call DesenhaBloco
    call DesenhaHud
    loadn r1, #msgLimpa
    call Mensagem
    jmp Aplica_fim

Aplica_ocupado:
    loadn r1, #msgOcupado
    call Mensagem
    jmp Aplica_fim
Aplica_vazio:
    loadn r1, #msgVazio
    call Mensagem
    jmp Aplica_fim
Aplica_libera:
    loadn r1, #msgLibera
    call Mensagem
    jmp Aplica_fim
Aplica_semDinheiro:
    loadn r1, #msgDinheiro
    call Mensagem

Aplica_fim:
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Recalcula: producao, consumo e totais de casas, servico e empregos.
;    Os blocos sao atendidos em ordem (de cima para baixo, da esquerda para a
;    direita) enquanto houver energia; os que sobram ficam sem luz. Bloco que
;    muda de estado de luz e' redesenhado.
; ----------------------------------------------------------------------------
Recalcula:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r5
    push r6
    push r7

    loadn r0, #0
    store prod, r0
    store cons, r0
    store apagao, r0
    store totR, r0
    store totC, r0
    store totI, r0
    store eR, r0
    store eC, r0
    store eI, r0
    store candR, r0
    store candC, r0
    store candI, r0

    ; 1a passada: energia produzida
    loadn r1, #0
    loadn r7, #240
Recalcula_prod:
    loadn r2, #tipo
    add r2, r2, r1
    loadi r3, r2
    loadn r4, #40
    loadn r2, #4
    cmp r3, r2
    jeq Recalcula_somaProd
    loadn r4, #300
    loadn r2, #5
    cmp r3, r2
    jne Recalcula_prodProx
Recalcula_somaProd:
    load r2, prod
    add r2, r2, r4
    store prod, r2
Recalcula_prodProx:
    inc r1
    cmp r1, r7
    jne Recalcula_prod

    ; 2a passada: distribui a energia. r0 = energia ja entregue
    loadn r0, #0
    loadn r1, #0
Recalcula_bloco:
    loadn r2, #tipo
    add r2, r2, r1
    loadi r3, r2                ; r3 = tipo
    loadn r6, #1                ; r6 = luz nova (vazio e usina contam como 1)
    loadn r2, #0
    cmp r3, r2
    jeq Recalcula_grava
    loadn r2, #4
    cmp r3, r2
    jeg Recalcula_grava

    loadn r2, #nivel
    add r2, r2, r1
    loadi r4, r2                ; r4 = nivel
    loadn r2, #4                ; r5 = energia[tipo * 4 + nivel]
    mul r5, r3, r2
    add r5, r5, r4
    loadn r2, #energia
    add r5, r5, r2
    loadi r5, r5

    load r2, cons               ; demanda total
    add r2, r2, r5
    store cons, r2

    add r2, r0, r5              ; cabe na producao?
    load r6, prod
    cmp r2, r6
    loadn r6, #0
    jgr Recalcula_grava         ; nao cabe: fica sem luz
    mov r0, r2
    loadn r6, #1

    push r0                     ; tot[tipo] += capNivel[nivel] (saturado)
    push r1
    loadn r2, #totR
    add r2, r2, r3
    dec r2
    loadi r0, r2
    loadn r1, #capNivel
    add r1, r1, r4
    loadi r1, r1
    call SomaSat
    storei r2, r0
    pop r1
    pop r0

    loadn r2, #eR               ; e[tipo] += energia
    add r2, r2, r3
    dec r2
    loadi r7, r2
    add r7, r7, r5
    storei r2, r7

    loadn r2, #3                ; nivel < 3: candidato a subir
    cmp r4, r2
    jeq Recalcula_grava
    loadn r2, #candR
    add r2, r2, r3
    dec r2
    loadi r7, r2
    inc r7
    storei r2, r7

Recalcula_grava:
    loadn r2, #luz
    add r2, r2, r1
    loadi r7, r2
    cmp r7, r6
    jeq Recalcula_prox
    storei r2, r6               ; mudou: grava e redesenha
    push r0
    mov r0, r1
    call DesenhaBloco
    pop r0
Recalcula_prox:
    inc r1
    loadn r7, #240
    cmp r1, r7
    jne Recalcula_bloco

    load r0, cons
    load r1, prod
    cmp r0, r1
    jel Recalcula_fim
    loadn r0, #1
    store apagao, r0

Recalcula_fim:
    pop r7
    pop r6
    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Tick: uma atualizacao da cidade (a cada 10 s)
;    1. populacao anda em direcao a min(casas, servico, empregos)
;    2. quem esta ocupado paga a luz: receita = 3 * energia * ocupacao
;    3. sem apagao, tipo com 80% de ocupacao sobe 40% dos seus blocos de nivel
; ----------------------------------------------------------------------------
Tick:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r5
    push r6
    push r7

    call Recalcula

    ; r0 = sustentavel = min(totR, totC, totI)
    load r0, totR
    load r1, totC
    cmp r1, r0
    jeg Tick_min2
    mov r0, r1
Tick_min2:
    load r1, totI
    cmp r1, r0
    jeg Tick_pop
    mov r0, r1

Tick_pop:
    load r1, popul
    cmp r1, r0
    jeg Tick_sai
    sub r2, r0, r1              ; chega metade do que falta (no minimo 1)
    loadn r3, #2
    div r2, r2, r3
    loadn r3, #0
    cmp r2, r3
    jne Tick_chega
    loadn r2, #1
Tick_chega:
    add r1, r1, r2
    jmp Tick_popOk
Tick_sai:
    sub r2, r1, r0              ; sai um quarto do excesso
    loadn r3, #4
    div r2, r2, r3
    sub r1, r1, r2
Tick_popOk:
    store popul, r1

    ; receita: para cada tipo, energia * (ocupacao em dezesseis avos) / 16
    loadn r7, #0                ; r7 = receita
    loadn r6, #0                ; r6 = tipo - 1
Tick_rec:
    loadn r2, #totR
    add r2, r2, r6
    loadi r2, r2                ; r2 = total do tipo
    loadn r3, #0
    cmp r2, r3
    jeq Tick_recProx
    load r1, popul                ; r1 = min(pop, total)
    cmp r1, r2
    jel Tick_ocup
    mov r1, r2
Tick_ocup:
    loadn r3, #4096             ; evita estourar 16 bits em r1 * 16
    cmp r2, r3
    jeg Tick_ocupGrande
    loadn r3, #16
    mul r1, r1, r3
    div r1, r1, r2
    jmp Tick_ocupOk
Tick_ocupGrande:
    loadn r3, #16
    div r3, r2, r3
    div r1, r1, r3
Tick_ocupOk:
    loadn r3, #16
    cmp r1, r3
    jel Tick_ocupMax
    mov r1, r3
Tick_ocupMax:
    loadn r2, #eR
    add r2, r2, r6
    loadi r2, r2
    mul r1, r1, r2
    loadn r3, #16
    div r1, r1, r3
    add r7, r7, r1
Tick_recProx:
    inc r6
    loadn r3, #3
    cmp r6, r3
    jne Tick_rec

    loadn r3, #3
    mul r1, r7, r3
    load r0, dinheiro
    call SomaSat
    store dinheiro, r0

    ; crescimento
    load r0, apagao
    loadn r1, #0
    cmp r0, r1
    jne Tick_avisaApagao
    loadn r6, #0
Tick_cresce:
    loadn r2, #totR
    add r2, r2, r6
    loadi r2, r2                ; r2 = total do tipo
    loadn r3, #0
    cmp r2, r3
    jeq Tick_cresceProx
    loadn r3, #5                ; limiar = total - total / 5 (80%)
    div r3, r2, r3
    sub r3, r2, r3
    load r1, popul
    cmp r1, r3
    jle Tick_cresceProx
    loadn r2, #candR
    add r2, r2, r6
    loadi r1, r2                ; r1 = candidatos
    loadn r3, #0
    cmp r1, r3
    jeq Tick_cresceProx
    loadn r3, #2                ; quantos sobem = candidatos * 2 / 5 (min 1)
    mul r1, r1, r3
    loadn r3, #5
    div r1, r1, r3
    loadn r3, #0
    cmp r1, r3
    jne Tick_sobe
    loadn r1, #1
Tick_sobe:
    mov r0, r6
    inc r0
    call SobeNivel
Tick_cresceProx:
    inc r6
    loadn r3, #3
    cmp r6, r3
    jne Tick_cresce
    call Recalcula
    loadn r1, #msgLimpa
    call Mensagem
    jmp Tick_fimCidade

Tick_avisaApagao:
    loadn r1, #msgApagao
    call Mensagem

Tick_fimCidade:
    load r0, ticks
    inc r0
    store ticks, r0
    load r0, popul
    loadn r1, #10000
    cmp r0, r1
    jle Tick_hud
    loadn r0, #1
    store venceu, r0
Tick_hud:
    loadn r0, #0                ; zera a barra de ritmo
    store subtick, r0
    loadn r0, #167
    loadn r1, #msgLimpa
    loadn r2, #0
    call ImprimeStr10
    call DesenhaHud
    pop r7
    pop r6
    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; SobeNivel: r0 = tipo, r1 = quantos blocos sobem. Percorre o mapa em ordem
; e sobe um nivel nos blocos desse tipo com luz e nivel < 3.
SobeNivel:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r5
    loadn r2, #0
SobeNivel_loop:
    loadn r3, #tipo
    add r3, r3, r2
    loadi r3, r3
    cmp r3, r0
    jne SobeNivel_prox
    loadn r3, #luz
    add r3, r3, r2
    loadi r3, r3
    loadn r4, #0
    cmp r3, r4
    jeq SobeNivel_prox
    loadn r3, #nivel
    add r3, r3, r2
    loadi r4, r3
    loadn r5, #3
    cmp r4, r5
    jeq SobeNivel_prox
    inc r4
    storei r3, r4
    push r0
    mov r0, r2
    call DesenhaBloco
    pop r0
    dec r1
    jz SobeNivel_fim
SobeNivel_prox:
    inc r2
    loadn r3, #240
    cmp r2, r3
    jne SobeNivel_loop
SobeNivel_fim:
    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Painel
; ----------------------------------------------------------------------------
; DesenhaHud: numeros do painel. O menor entre casas, servico e empregos
; (o gargalo) sai em vermelho; energia em vermelho no apagao.
DesenhaHud:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r5

    load r0, dinheiro
    loadn r1, #14
    loadn r2, #5
    loadn r3, #0
    call ImprimeNum
    load r0, popul
    loadn r1, #33
    call ImprimeNum0

    ; r4 = gargalo
    load r4, totR
    load r5, totC
    cmp r5, r4
    jeg DesenhaHud_g2
    mov r4, r5
DesenhaHud_g2:
    load r5, totI
    cmp r5, r4
    jeg DesenhaHud_casas
    mov r4, r5

DesenhaHud_casas:
    load r0, totR
    loadn r1, #49
    call CorGargalo
    call ImprimeNum0
    load r0, totC
    loadn r1, #62
    call CorGargalo
    call ImprimeNum0
    load r0, totI
    loadn r1, #75
    call CorGargalo
    call ImprimeNum0

    loadn r3, #0
    load r0, apagao
    loadn r1, #0
    cmp r0, r1
    jeq DesenhaHud_energia
    loadn r3, #2304
DesenhaHud_energia:
    load r0, cons
    loadn r1, #91
    loadn r2, #4
    call ImprimeNum
    load r0, prod
    loadn r1, #96
    call ImprimeNum

    loadn r3, #0                ; tempo = ticks * 10 s
    loadn r2, #2
    load r0, ticks
    loadn r1, #10
    mul r0, r0, r1
    loadn r1, #60
    div r5, r0, r1
    mod r0, r0, r1
    loadn r1, #110
    call ImprimeNum
    mov r0, r5
    loadn r1, #107
    call ImprimeNum

    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; CorGargalo: r3 = vermelho se r0 == r4 (gargalo), senao branco; r2 = 5
CorGargalo:
    loadn r2, #5
    loadn r3, #0
    cmp r0, r4
    jne CorGargalo_fim
    loadn r3, #2304
CorGargalo_fim:
    rts

; DesenhaRoleta: nome e preco da acao escolhida
DesenhaRoleta:
    push r0
    push r1
    push r2
    push r3
    load r0, ferr
    loadn r1, #13
    mul r1, r0, r1
    loadn r2, #nomes
    add r1, r1, r2
    loadn r0, #124
    loadn r2, #2816             ; amarelo
    call ImprimeStr
    load r0, ferr               ; preco = custo[ferr + 1] (demolir mostra 0)
    inc r0
    loadn r1, #6
    cmp r0, r1
    jne DesenhaRoleta_preco
    loadn r0, #0
DesenhaRoleta_preco:
    loadn r1, #custo
    add r1, r1, r0
    loadi r0, r1
    loadn r1, #142
    loadn r2, #5
    loadn r3, #0
    call ImprimeNum
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; Mensagem: r1 = texto de 20 letras, impresso no canto do painel
Mensagem:
    push r0
    push r2
    loadn r0, #180
    loadn r2, #2304
    call ImprimeStr
    pop r2
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Rotinas de impressao
; ----------------------------------------------------------------------------
; ImprimeStr: r0 = posicao, r1 = texto (termina em '\0'), r2 = cor
ImprimeStr:
    push r0
    push r1
    push r3
    push r4
    loadn r3, #0
ImprimeStr_loop:
    loadi r4, r1
    cmp r4, r3
    jeq ImprimeStr_fim
    add r4, r4, r2
    outchar r4, r0
    inc r0
    inc r1
    jmp ImprimeStr_loop
ImprimeStr_fim:
    pop r4
    pop r3
    pop r1
    pop r0
    rts

; ImprimeStr10: imprime so os 10 primeiros caracteres (r0, r1, r2 como acima)
ImprimeStr10:
    push r0
    push r1
    push r3
    push r4
    loadn r3, #10
ImprimeStr10_loop:
    loadi r4, r1
    add r4, r4, r2
    outchar r4, r0
    inc r0
    inc r1
    dec r3
    jnz ImprimeStr10_loop
    pop r4
    pop r3
    pop r1
    pop r0
    rts

; ImprimeNum: r0 = valor, r1 = posicao do ULTIMO digito, r2 = digitos,
; r3 = cor. Completa com zeros a esquerda.
ImprimeNum:
    push r0
    push r1
    push r2
    push r4
    push r5
    loadn r4, #10
ImprimeNum_loop:
    mod r5, r0, r4
    div r0, r0, r4
    push r4
    loadn r4, #'0'
    add r5, r5, r4
    pop r4
    add r5, r5, r3
    outchar r5, r1
    dec r1
    dec r2
    jnz ImprimeNum_loop
    pop r5
    pop r4
    pop r2
    pop r1
    pop r0
    rts

; ImprimeNum0: valor em dezenas: imprime r0 com 5 digitos terminando em r1
; e um '0' depois (r3 = cor)
ImprimeNum0:
    push r1
    push r2
    push r4
    loadn r2, #5
    call ImprimeNum
    inc r1
    loadn r4, #'0'
    add r4, r4, r3
    outchar r4, r1
    pop r4
    pop r2
    pop r1
    rts

; ApagaTela: 1200 espacos
ApagaTela:
    push r0
    push r1
    push r2
    loadn r0, #0
    loadn r1, #1200
    loadn r2, #32
ApagaTela_loop:
    outchar r2, r0
    inc r0
    cmp r0, r1
    jne ApagaTela_loop
    pop r2
    pop r1
    pop r0
    rts

; SomaSat: r0 = min(r0 + r1, 60000), para nao estourar 16 bits
SomaSat:
    push r2
    loadn r2, #60000
    sub r2, r2, r1
    cmp r0, r2
    jgr SomaSat_cheio
    add r0, r0, r1
    pop r2
    rts
SomaSat_cheio:
    loadn r0, #60000
    pop r2
    rts

; Rand: r0 = numero sorteado de 0 a 255
;   gerador congruente: semente = (semente * 25173 + 13849) mod 65536;
;   usa os 8 bits de cima, que variam mais que os de baixo
Rand:
    push r1
    load r0, semente
    loadn r1, #25173
    mul r0, r0, r1
    loadn r1, #13849
    add r0, r0, r1
    loadn r1, #65535
    and r0, r0, r1
    store semente, r0
    shiftr0 r0, #8
    pop r1
    rts

; GeraTerreno: grama em todo o mapa (1 em 4 com o outro desenho) e 6
; manchas de terra de ate 3 x 3 blocos em lugares sorteados
GeraTerreno:
    push r0
    push r1
    push r2
    push r3
    push r4
    push r5
    push r6
    push r7

    loadn r1, #0
GeraTerreno_grama:
    call Rand
    loadn r2, #4
    mod r0, r0, r2
    loadn r3, #0                ; grama
    loadn r2, #0
    cmp r0, r2
    jne GeraTerreno_grava
    loadn r3, #2                ; grama com o outro desenho
GeraTerreno_grava:
    loadn r2, #terreno
    add r2, r2, r1
    storei r2, r3
    inc r1
    loadn r2, #240
    cmp r1, r2
    jne GeraTerreno_grama

    loadn r7, #6                ; r7 = manchas que faltam
GeraTerreno_mancha:
    call Rand                   ; centro sorteado: r5 = linha, r6 = coluna
    loadn r2, #240
    mod r0, r0, r2
    loadn r2, #20
    div r5, r0, r2
    mod r6, r0, r2
    loadn r3, #0                ; r3 = dl (0 a 2: linha - 1 a linha + 1)
GeraTerreno_dl:
    loadn r4, #0                ; r4 = dc
GeraTerreno_dc:
    add r1, r5, r3              ; r1 = linha + dl (1 a 12 = dentro do mapa)
    loadn r2, #0
    cmp r1, r2
    jeq GeraTerreno_pula
    loadn r2, #13
    cmp r1, r2
    jeq GeraTerreno_pula
    add r2, r6, r4              ; r2 = coluna + dc (1 a 20 = dentro)
    push r3
    loadn r3, #0
    cmp r2, r3
    pop r3
    jeq GeraTerreno_pula
    push r3
    loadn r3, #21
    cmp r2, r3
    pop r3
    jeq GeraTerreno_pula
    dec r1                      ; r1 = bloco = (linha - 1) * 20 + (coluna - 1)
    dec r2
    push r3
    loadn r3, #20
    mul r1, r1, r3
    add r1, r1, r2
    pop r3
    loadn r2, #1                ; o centro sempre vira terra, os vizinhos
    cmp r3, r2                  ; so com chance de 1/2
    jne GeraTerreno_sorteia
    cmp r4, r2
    jeq GeraTerreno_terra
GeraTerreno_sorteia:
    call Rand
    loadn r2, #2
    mod r0, r0, r2
    loadn r2, #0
    cmp r0, r2
    jne GeraTerreno_pula
GeraTerreno_terra:
    loadn r2, #terreno
    add r2, r2, r1
    loadn r0, #1
    storei r2, r0
GeraTerreno_pula:
    inc r4
    loadn r2, #3
    cmp r4, r2
    jne GeraTerreno_dc
    inc r3
    cmp r3, r2
    jne GeraTerreno_dl
    dec r7
    jnz GeraTerreno_mancha

    pop r7
    pop r6
    pop r5
    pop r4
    pop r3
    pop r2
    pop r1
    pop r0
    rts

; EsperaEnter: espera a tecla ENTER (13)
EsperaEnter:
    push r0
    push r1
    loadn r1, #13
EsperaEnter_loop:
    load r0, semente            ; quanto tempo o jogador demora muda a semente
    inc r0
    store semente, r0
    inchar r0
    cmp r0, r1
    jne EsperaEnter_loop
    pop r1
    pop r0
    rts

; ----------------------------------------------------------------------------
;  Telas de inicio e de fim
; ----------------------------------------------------------------------------
TelaInicio:
    push r0
    push r1
    push r2
    call ApagaTela
    loadn r2, #2816
    loadn r0, #129
    loadn r1, #ini1
    call ImprimeStr
    loadn r2, #0
    loadn r0, #283
    loadn r1, #ini2
    call ImprimeStr
    loadn r0, #323
    loadn r1, #ini3
    call ImprimeStr
    loadn r2, #2816
    loadn r0, #403
    loadn r1, #ini4
    call ImprimeStr
    loadn r2, #3328
    loadn r0, #443
    loadn r1, #ini5
    call ImprimeStr
    loadn r2, #2048
    loadn r0, #483
    loadn r1, #ini6
    call ImprimeStr
    loadn r2, #2304
    loadn r0, #523
    loadn r1, #ini7
    call ImprimeStr
    loadn r2, #0
    loadn r0, #603
    loadn r1, #ini8
    call ImprimeStr
    loadn r0, #643
    loadn r1, #ini9
    call ImprimeStr
    loadn r2, #1792
    loadn r0, #723
    loadn r1, #ini10
    call ImprimeStr
    loadn r0, #763
    loadn r1, #ini11
    call ImprimeStr
    loadn r0, #803
    loadn r1, #ini12
    call ImprimeStr
    loadn r0, #843
    loadn r1, #ini13
    call ImprimeStr
    loadn r2, #3328
    loadn r0, #1011
    loadn r1, #ini14
    call ImprimeStr
    call EsperaEnter
    pop r2
    pop r1
    pop r0
    rts

TelaFim:
    push r0
    push r1
    push r2
    push r3
    push r5
    call ApagaTela
    loadn r2, #2816
    loadn r0, #402
    loadn r1, #fim1
    call ImprimeStr
    loadn r2, #0
    loadn r0, #575
    loadn r1, #fim2
    call ImprimeStr
    loadn r3, #0                ; tempo mm:ss nas colunas 22-23 e 25-26
    loadn r2, #2
    load r0, ticks
    loadn r1, #10
    mul r0, r0, r1
    loadn r1, #60
    div r5, r0, r1
    mod r0, r0, r1
    loadn r1, #586
    call ImprimeNum
    mov r0, r5
    loadn r1, #583
    call ImprimeNum
    loadn r2, #3328
    loadn r0, #848
    loadn r1, #fim3
    call ImprimeStr
    call EsperaEnter
    pop r5
    pop r3
    pop r2
    pop r1
    pop r0
    rts
