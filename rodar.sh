#!/bin/bash
# Monta o jogo e abre no simulador grafico (como o buildandrun do professor).
# Uso: ./rodar.sh [escala]   escala padrao 4 (o original do professor e' 2)
# Na janela: Home liga/para a execucao, Insert reseta, Esc fecha.
# O simulador abre separado do terminal; a saida dele fica em /tmp/sim-oac.log.
cd "$(dirname "$0")"
BIN=../material/bin
"$BIN/montador" jogo.asm | tail -c 300 | grep -o "Erro.*" && exit 1
export DISPLAY="${DISPLAY:-:0}"
SIM="$BIN/sim-escala"
[ -x "$SIM" ] || SIM="$BIN/sim"         # sem a copia ampliada, usa o original
export ICMC_ESCALA="${1:-4}"
setsid "$SIM" jogo.mif charmap.mif > /tmp/sim-oac.log 2>&1 < /dev/null &
echo "Simulador aberto (pid $!, escala $ICMC_ESCALA). Na janela: Home liga a execucao, depois Enter."
