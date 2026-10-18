"""Gera um PNG da tela do emulador como o simulador grafico desenharia.

Usa o charmap.mif e as cores RGB do Simulator_Source/View.cpp do professor
(cada ponto do caractere vira 2x2 pixels, fundo preto).

Uso: python3 print_tela.py saida.png [--passos N] [--teclas "100000:enter,400000:enter"]
"""
import argparse
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from icmc import CPU, le_mif, le_teclas

AQUI = os.path.dirname(os.path.abspath(__file__))
RGB = [(255, 255, 255), (165, 42, 42), (0, 255, 0), (107, 142, 35), (35, 35, 142),
       (135, 31, 120), (0, 128, 128), (230, 232, 250), (190, 190, 190), (255, 0, 0),
       (50, 205, 50), (255, 255, 0), (0, 0, 255), (255, 28, 174), (122, 219, 147), (0, 0, 0)]


def le_charmap(caminho):
    sys.path.insert(0, os.path.join(AQUI, '..', 'arte'))
    from gera_arte import le_charmap as lc
    return lc(caminho)


def desenha(tela, charmap, escala=2):
    img = Image.new('RGB', (320 * escala, 240 * escala))
    px = img.load()
    for pos, v in enumerate(tela):
        c, cor = v & 0x7f, RGB[(v >> 8) & 15]
        if c == 4:          # o simulador do professor nunca desenha o 4
            continue
        x0, y0 = (pos % 40) * 8, (pos // 40) * 8
        for y in range(8):
            linha = charmap[c * 8 + y]
            for x in range(8):
                if linha & (0x80 >> x):
                    for dy in range(escala):
                        for dx in range(escala):
                            px[(x0 + x) * escala + dx, (y0 + y) * escala + dy] = cor
    return img


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('saida')
    ap.add_argument('--mif', default=os.path.join(AQUI, '..', 'jogo.mif'))
    ap.add_argument('--charmap', default=os.path.join(AQUI, '..', 'charmap.mif'))
    ap.add_argument('--passos', type=int, default=1200000)
    ap.add_argument('--teclas', default='100000:enter,400000:enter')
    a = ap.parse_args()
    cpu = CPU(le_mif(a.mif))
    cpu.roda(a.passos, le_teclas(a.teclas))
    desenha(cpu.tela, le_charmap(a.charmap)).save(a.saida)
