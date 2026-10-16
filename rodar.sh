#!/bin/bash
# Monta o jogo e abre no simulador grafico do professor (como o buildandrun dele).
# Na janela: Home liga/para a execucao, Insert reseta, Esc fecha.
cd "$(dirname "$0")"
BIN=../material/bin
"$BIN/montador" jogo.asm | tail -c 300 | grep -o "Erro.*" && exit 1
exec "$BIN/sim" jogo.mif charmap.mif
