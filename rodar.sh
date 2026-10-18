#!/bin/bash
# Monta o jogo e abre no simulador grafico do professor (como o buildandrun dele).
# Na janela: Home liga/para a execucao, Insert reseta, Esc fecha.
# O simulador abre separado do terminal; a saida dele fica em /tmp/sim-oac.log.
cd "$(dirname "$0")"
BIN=../material/bin
"$BIN/montador" jogo.asm | tail -c 300 | grep -o "Erro.*" && exit 1
export DISPLAY="${DISPLAY:-:0}"
setsid "$BIN/sim" jogo.mif charmap.mif > /tmp/sim-oac.log 2>&1 < /dev/null &
echo "Simulador aberto (pid $!). Na janela: Home liga a execucao, depois Enter."
