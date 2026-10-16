# Ferramentas e como rodar

## Resumo

| Para quê | Comando |
|---|---|
| Montar o jogo | `../material/bin/montador jogo.asm` (gera `jogo.mif`) |
| Jogar no terminal | `python3 ferramentas/jogar.py jogo.mif` (Esc sai) |
| Ver a tela depois de N instruções | `python3 ferramentas/icmc.py jogo.mif --passos 800000 --teclas "100000:enter"` |
| Partida automática (teste) | `python3 ferramentas/joga_teste.py --acoes 4` |
| Testar números da mecânica | `python3 balanceamento/sim.py` |

Comandos a partir de `oac/usp-oac-trabalho/`.

## Montador

- Código: repo do professor, `NovoMontadorLinux/Montador_Ultimo_Beta_64Kb/`. Clone local em `oac/material/Processador-ICMC/` (fora do git).
- Compilar (sem dependências):
  ```
  cd oac/material/Processador-ICMC/NovoMontadorLinux/Montador_Ultimo_Beta_64Kb
  gcc -O2 -o ../../../bin/montador main.c montador.c parser.c structs.c
  ```
- `montador jogo.asm` gera `jogo.mif` com 65536 linhas; o simulador lê só as primeiras 32768.
- A saída é um monte de `SUCESSO` ou `ERRO`. A linha útil vem no fim: `Erro (linha N): ...`. Para ver só ela: `montador jogo.asm | tail -c 300`.

**Armadilhas do montador:**
- Nome de instrução não pode ser label nem variável: `pop` deu erro na linha da declaração. Outros proibidos: `sub`, `add`, `inc`, `load`, `store`, `mov`, `push`, `call`, `rts`, `halt`...
- `MUL` (não `MULT`), `MOD`, `DIV`; saltos `JGR` (maior), `JLE` (menor, estrito), `JEG` (maior ou igual), `JEL` (menor ou igual).
- Endereço de label como número: `loadn r1, #tipo`.
- Caractere: `loadn r1, #'w'`.
- `var #N` reserva N palavras no ponto onde aparece; `static x + #i, #v` só preenche, não ocupa espaço novo.
- O montador novo aceita instruções que o simulador não tem (`STOREN`, `INPUT`, `BRA`, `JSR`...). Usar só as de `material/MaterialAulaDistancia/instrucoes.txt`.

## Simulador gráfico oficial

- Código: `Simulator_Source/` do repo do professor. Precisa de GTK2 e SDL2:
  ```
  cd oac/material/Processador-ICMC/Simulator_Source && ./compila.sh
  ./sim ../../../usp-oac-trabalho/jogo.mif ../../../usp-oac-trabalho/charmap.mif
  ```
- No Arch o GTK2 saiu dos repositórios oficiais: `yay -S gtk2` (AUR, compila por alguns minutos). Em 16/10/2026 a primeira tentativa não terminou de instalar.
- Teclas do simulador: Home liga e para a execução, Insert reseta, End executa um passo, Esc fecha. O jogo não deve usar essas.
- Alternativa sem instalar nada: simulador web https://proc.giroto.dev/ (beta).

## Emulador em Python (`ferramentas/icmc.py`)

Escrito para testar sem janela. Segue `Simulator_Source/Model.cpp` instrução por instrução. Roda cerca de 1,2 milhão de instruções por segundo. `jogar.py` usa o mesmo emulador com curses.

## Como o simulador oficial se comporta

| Ponto | Comportamento |
|---|---|
| Memória | 32768 palavras; PC começa em 0; SP começa em 0x7FFC (32764) e desce |
| Tela | 40×30; `outchar rX, rY` desenha o caractere `rX & 127` com a cor `(rX >> 8) & 15` na posição `rY` (0 a 1199) |
| Teclado | `inchar` devolve a tecla uma vez e depois 255 até a próxima (segurar repete pelo autorepeat do sistema) |
| Teclas especiais | Enter = 13, ← 14, → 15, ↑ 16, ↓ 17 (só no simulador gráfico; o Simple Simulator lê do terminal e não tem setas) |
| Registradores | são `int` de 32 bits no simulador, não 16 |
| `SUB` negativo | resultado vira 0 (e liga a flag de negativo) |
| `ADD` acima de 65535 | subtrai 0xFFFF (não 0x10000) e liga o carry |
| `DEC` abaixo de 0 | fica -1 de verdade (int) |
| `MUL` | não corta em 16 bits |
| Velocidade | roda o mais rápido que o computador deixa; não há relógio |

Consequência: conta que estoura 16 bits pode funcionar no simulador e falhar na FPGA. O jogo evita estourar (soma saturada em 60000, população em dezenas).

**Cores** (somar ao caractere): 0 branco, 256 marrom, 512 verde, 768 oliva, 1024 marinho, 1280 roxo, 1536 teal, 1792 prata, 2048 cinza, 2304 vermelho, 2560 lima, 2816 amarelo, 3072 azul, 3328 rosa, 3584 aqua, 3840 **preto** (a tabela do Hello4 diz "branco", mas o simulador define 15 como preto).

## Charmap

- `charmap.mif`: 128 caracteres de 8×8, um bit por ponto, uma cor por caractere.
- O padrão traz 0 a 31 em branco: 32 desenhos livres sem perder letras.
- O simulador procura o charmap passado na linha de comando; deixar na mesma pasta do `.asm`.

## Calibrar o ritmo (10 s por atualização)

O jogo conta voltas do laço principal: `voltasPorSub` (início do `jogo.asm`) voltas = 1 subtick; 10 subticks = 1 atualização. Para calibrar no simulador usado:

1. Rodar o jogo e cronometrar 10 atualizações (10 voltas completas da barra RITMO).
2. `voltasPorSub novo = 3000 × 100 s / tempo medido`.

Cada volta tem cerca de 220 instruções. No `jogar.py` (até 1 milhão de instruções por segundo) 3000 voltas dão uma atualização a cada 6 a 7 s.
