# Ferramentas e como rodar

## Resumo

| Para quê | Comando |
|---|---|
| **Montar e jogar na janela do simulador do professor** | `./rodar.sh` (na janela: Home liga) |
| Montar o jogo | `../material/bin/montador jogo.asm` (gera `jogo.mif`) |
| Jogar no terminal (reserva, sem GTK) | `python3 ferramentas/jogar.py jogo.mif` (Esc sai) |
| Ver a tela depois de N instruções | `python3 ferramentas/icmc.py jogo.mif --passos 800000 --teclas "100000:enter"` |
| Print da tela como o simulador desenha | `python3 ferramentas/print_tela.py tela.png --passos 900000 --teclas "100000:enter"` |
| Regerar o charmap depois de mudar `arte/blocos.txt` | `python3 arte/gera_arte.py` (reescreve `charmap.mif` e a tabela `glifo` no `jogo.asm`) |
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

É o jeito do professor: `montador` gera o `.mif` e `sim jogo.mif charmap.mif` abre a janela com a tela do processador. Código em `Simulator_Source/` do repo dele; precisa de GTK2 e SDL2.

**GTK2 no Arch** (saiu dos repositórios; `yay -S gtk2` falhou no meio em 16/10/2026). Compilado sem sudo numa pasta local, a partir do código que o yay baixou:
```
cp -r ~/.cache/yay/gtk2/src/gtk /tmp/gtk2 && cd /tmp/gtk2
make distclean
CFLAGS="-O2 -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration -Wno-error=int-conversion -std=gnu17" \
  ./configure --prefix=$HOME/.local/opt/gtk2 --with-xinput=yes --disable-gtk-doc --disable-introspection
make -j$(nproc) && make install
```

**Compilar o simulador** contra esse GTK2 (o rpath dispensa `LD_LIBRARY_PATH`):
```
cd oac/material/Processador-ICMC/Simulator_Source
export PKG_CONFIG_PATH=$HOME/.local/opt/gtk2/lib/pkgconfig
g++ main.cpp View.cpp Controller.cpp Sound.cpp Model.cpp -O3 -march=native -o ../../bin/sim \
  $(pkg-config --libs --cflags gtk+-2.0) -pthread -lgthread-2.0 -lSDL2 -Wl,-rpath,$HOME/.local/opt/gtk2/lib
```

- Teclas da janela: Home liga e para a execução, Insert reseta, End executa um passo, Esc fecha. O jogo não deve usar essas.
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

**Cores** (somar ao caractere) e o RGB que o simulador pinta (`View.cpp`):

| Valor | Nome | RGB | Observação |
|---|---|---|---|
| 0 | branco | 255, 255, 255 | |
| 256 | marrom | 165, 42, 42 | na prática vermelho escuro; não há marrom claro |
| 512 | verde | 0, 255, 0 | verde puro, forte |
| 768 | oliva | 107, 142, 35 | verde grama escuro |
| 1024 | marinho | 35, 35, 142 | |
| 1280 | roxo | 135, 31, 120 | |
| 1536 | teal | 0, 128, 128 | |
| 1792 | prata | 230, 232, 250 | quase branco |
| 2048 | cinza | 190, 190, 190 | cinza claro |
| 2304 | vermelho | 255, 0, 0 | |
| 2560 | lima | 50, 205, 50 | |
| 2816 | amarelo | 255, 255, 0 | |
| 3072 | azul | 0, 0, 255 | |
| 3328 | rosa | 255, 28, 174 | |
| 3584 | aqua | 122, 219, 147 | verde menta claro |
| 3840 | preto | 0, 0, 0 | a tabela do Hello4 diz "branco", mas o simulador define 15 como preto |

O fundo de todo caractere é preto: não há como pôr duas cores no mesmo caractere nem desenhar um por cima do outro.

## Charmap

- `charmap.mif`: 128 caracteres de 8×8, um bit por ponto, uma cor por caractere.
- O padrão traz 0 a 31 em branco: 32 desenhos livres sem perder letras.
- O jogo usa 1 a 31 e as minúsculas (97 a 122) para os blocos; por isso todo texto do jogo é em maiúsculas. São 13 blocos × 4 = 52 de 57 caracteres livres.
- Não editar `charmap.mif` à mão: mudar `arte/blocos.txt` e rodar `arte/gera_arte.py`. A base com as letras do professor fica em `arte/charmap_padrao.mif`.
- O simulador exige cada linha do conteúdo começando com tabulação (o gerador já escreve assim).
- O simulador procura o charmap passado na linha de comando; deixar na mesma pasta do `.asm`.

## Calibrar o ritmo (10 s por atualização)

O jogo conta voltas do laço principal: `voltasPorSub` (início do `jogo.asm`) voltas = 1 subtick; 10 subticks = 1 atualização. Para calibrar no simulador usado:

1. Rodar o jogo e cronometrar 10 atualizações (10 voltas completas da barra RITMO).
2. `voltasPorSub novo = 3000 × 100 s / tempo medido`.

Cada volta tem cerca de 220 instruções. No `jogar.py` (até 1 milhão de instruções por segundo) 3000 voltas dão uma atualização a cada 6 a 7 s.
