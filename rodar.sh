#!/bin/bash
# Monta o jogo e abre no simulador grafico (como o buildandrun do professor).
# Uso: ./rodar.sh [escala]   escala padrao 4 (o original do professor e' 2)
# Na janela: Home liga/para a execucao, Insert reseta, Esc fecha.
# O simulador abre separado do terminal; a saida dele fica em /tmp/sim-oac.log.
#
# Procura montador e simulador em ../material/bin (central de estudos) ou no
# PATH (montador, sim). Sem montador, usa o jogo.mif que ja vem no repositorio.
cd "$(dirname "$0")"
BIN=../material/bin
MONTADOR="$BIN/montador"; [ -x "$MONTADOR" ] || MONTADOR="$(command -v montador)"
SIM="$BIN/sim-escala"
[ -x "$SIM" ] || SIM="$BIN/sim"
[ -x "$SIM" ] || SIM="$(command -v sim)"
if [ -n "$MONTADOR" ]; then
  "$MONTADOR" jogo.asm | tail -c 300 | grep -o "Erro.*" && exit 1
else
  echo "Sem montador: usando o jogo.mif ja montado."
fi
if [ -z "$SIM" ]; then
  echo "Nao achei o simulador (sim). Ver README.md, secao Linux."
  exit 1
fi
export DISPLAY="${DISPLAY:-:0}"
export ICMC_ESCALA="${1:-4}"
setsid "$SIM" jogo.mif charmap.mif > /tmp/sim-oac.log 2>&1 < /dev/null &
echo "Simulador aberto (pid $!, escala $ICMC_ESCALA). Na janela: Home liga a execucao, depois Enter."
