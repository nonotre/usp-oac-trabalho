# usp-oac-trabalho

Jogo em Assembly para o Processador ICMC (SSC0513, ICMC-USP, 2026).

## Requisitos do professor

1. Implementar um jogo em Assembly (tema livre).
2. Apresentar o jogo rodando no simulador do Processador ICMC.
3. Apresentar o processador implementado no Simple Simulator.

O repositório deve ter:

- este README explicando o projeto;
- o `JOGO.ASM`, muito bem comentado, e o `CHARMAP.MIF` se for alterado;
- o código C completo do Simple Simulator;
- o link para um vídeo do grupo explicando o projeto (YouTube ou Drive, o vídeo não entra no repo).

Sem data de entrega marcada: a apresentação é presencial, na sala, nas últimas semanas do semestre, para todos os alunos do grupo. O grupo se inscreve na planilha do professor com título, nomes e link do repo.

## Jogo

Cidade simplificada no estilo SimCity: chegar a 100 mil habitantes equilibrando casas, comércio, indústria e energia. Regras e balanceamento em [`DESIGN.md`](DESIGN.md).

## Arquivos

| Arquivo | O quê |
|---|---|
| `jogo.asm` | o jogo |
| `charmap.mif` | caracteres (por enquanto o padrão do professor) |
| `DESIGN.md` | regras, números e controles |
| `FERRAMENTAS.md` | como montar, rodar e testar; comportamento do simulador |
| `balanceamento/sim.py` | simulação da economia |
| `rodar.sh` | monta e abre no simulador gráfico |
| `ferramentas/` | emulador em Python, modo de jogar no terminal, partida automática |

Jogar: `./rodar.sh` monta e abre no simulador do professor; na janela, Home liga a execução. Instalação em `FERRAMENTAS.md`.

## Ferramentas

| Para quê | O quê |
|---|---|
| Escrever e rodar o jogo (tela 40×30, cores, teclado) | Montador + simulador gráfico do [Processador-ICMC](https://github.com/simoesusp/Processador-ICMC) (`NovoMontadorLinux/`, `Install_Packages/`) ou o simulador web https://proc.giroto.dev/ |
| Requisito 3 | `Simple_Simulator/simple_simulator_template.c`: o processador em C com a máquina de estados incompleta (LOAD, STORE e outras instruções vazias). Completar e mostrar rodando o `cpuram.mif` do jogo. Grupos anteriores também acrescentaram uma instrução nova (POW, MED) |
| Testar números da mecânica | `balanceamento/sim.py` |

## Grupo

A definir.
