"""Roda um .mif do Processador ICMC no terminal, com teclado e cores.

Substitui o simulador grafico quando ele nao esta instalado. Usa o emulador
de icmc.py (mesma semantica do simulador oficial).

Uso: python3 jogar.py ../jogo.mif     (Esc ou Ctrl+C sai)
Teclas: letras, numeros, espaco, Enter (13) e setas (14 a 17, como no
simulador oficial).
"""
import curses
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from icmc import CPU, le_mif

# cor do Processador ICMC (0 a 15) -> (cor do curses, negrito)
CORES = [
    (curses.COLOR_WHITE, True), (curses.COLOR_YELLOW, False), (curses.COLOR_GREEN, False),
    (curses.COLOR_YELLOW, False), (curses.COLOR_BLUE, False), (curses.COLOR_MAGENTA, False),
    (curses.COLOR_CYAN, False), (curses.COLOR_WHITE, False), (curses.COLOR_BLACK, True),
    (curses.COLOR_RED, True), (curses.COLOR_GREEN, True), (curses.COLOR_YELLOW, True),
    (curses.COLOR_BLUE, True), (curses.COLOR_MAGENTA, True), (curses.COLOR_CYAN, True),
    (curses.COLOR_BLACK, False),
]
SETAS = {curses.KEY_LEFT: 14, curses.KEY_RIGHT: 15, curses.KEY_UP: 16, curses.KEY_DOWN: 17,
         10: 13, curses.KEY_ENTER: 13}


def main(tela, mif):
    curses.curs_set(0)
    tela.nodelay(True)
    curses.start_color()
    curses.use_default_colors()
    for i, (c, _) in enumerate(CORES):
        curses.init_pair(i + 1, c, -1)
    cpu = CPU(le_mif(mif))
    antes = [None] * 1200
    fatia = 20000
    while True:
        t0 = time.time()
        k = tela.getch()
        if k == 27:
            return
        if k != -1:
            cpu.key = SETAS.get(k, k if k < 256 else 255)
        cpu.roda(cpu.passos + fatia)
        for i, v in enumerate(cpu.tela):
            if v != antes[i]:
                antes[i] = v
                c = v & 0x7f
                ch = chr(c) if 32 <= c < 127 else ('#' if c else ' ')
                cor = (v >> 8) & 15
                attr = curses.color_pair(cor + 1) | (curses.A_BOLD if CORES[cor][1] else 0)
                try:
                    tela.addstr(i // 40, i % 40, ch, attr)
                except curses.error:
                    pass
        tela.refresh()
        dt = time.time() - t0
        if dt < 0.02:
            time.sleep(0.02 - dt)


if __name__ == '__main__':
    curses.wrapper(main, sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'jogo.mif'))
