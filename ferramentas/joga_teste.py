"""Joga uma partida automatica do jogo.mif no emulador, pelo teclado.

Usa a mesma estrategia gulosa de balanceamento/sim.py e o atalho '+' para
adiantar o tempo. Serve para conferir se o Assembly se comporta como a
simulacao.

Uso: python3 joga_teste.py [jogo.mif] [--acoes 4]
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from icmc import CPU, le_mif

AQUI = os.path.dirname(os.path.abspath(__file__))
ASM = os.path.join(AQUI, '..', 'jogo.asm')


def enderecos(asm):
    """Enderecos das variaveis declaradas logo apos o 'jmp main' (2 palavras)."""
    end, tab = 2, {}
    for linha in open(asm):
        m = re.match(r'\s*(\w+)\s*:\s*var\s*#(\d+)', linha)
        if m:
            tab[m.group(1)] = end
            end += int(m.group(2))
        elif re.match(r'\s*\w+\s*:\s*string', linha) or linha.strip().startswith('main:'):
            break
    return tab


CAP = [0, 10, 50, 300]
CUSTO = [0, 40, 60, 150, 400, 2500]


class Jogador:
    def __init__(self, mif, acoes):
        self.cpu = CPU(le_mif(mif))
        self.v = enderecos(ASM)
        self.acoes = acoes
        self.cpu.roda(100000)
        self.tecla('\r')
        self.cpu.roda(self.cpu.passos + 300000)   # NovoJogo e desenho da tela

    def m(self, nome, i=0):
        return self.cpu.mem[self.v[nome] + i]

    def tecla(self, k):
        c = self.cpu
        c.key = ord(k)
        while c.key != 255:
            c.passo()
        while c.sp == 0x7FFC:          # entra no TrataTecla
            c.passo()
        while c.sp != 0x7FFC:          # e volta ao laco principal
            c.passo()

    def vai(self, alvo):
        while self.m('sel') != alvo:
            s = self.m('sel')
            if alvo // 20 < s // 20: self.tecla('w')
            elif alvo // 20 > s // 20: self.tecla('s')
            elif alvo % 20 < s % 20: self.tecla('a')
            else: self.tecla('d')

    def escolhe(self, ferr):
        while self.m('ferr') != ferr:
            self.tecla('k')

    def constroi(self, tipo):
        livre = [b for b in range(240) if self.m('tipo', b) == 0]
        if not livre:
            return False
        antes = self.m('dinheiro')
        self.escolhe(tipo - 1)
        self.vai(livre[0])
        self.tecla(' ')
        return self.m('dinheiro') < antes

    def turno(self):
        for _ in range(self.acoes):
            din, pop = self.m('dinheiro'), self.m('popul')
            if self.m('cons') + 6 > self.m('prod'):
                if pop >= 2000:
                    if din < CUSTO[5]: return
                    self.constroi(5)
                elif din >= CUSTO[4]:
                    self.constroi(4)
                else:
                    return
                continue
            pot = {t: sum(CAP[max(self.m('nivel', b), 1)] for b in range(240) if self.m('tipo', b) == t)
                   for t in (1, 2, 3)}
            t = min(pot, key=pot.get)
            if din < CUSTO[t]:
                return
            self.constroi(t)

    def partida(self, max_ticks=150, verbose=True):
        for _ in range(max_ticks):
            self.turno()
            self.tecla('+')
            k = self.m('ticks')
            if verbose and k % 5 == 0:
                print(f"t{k:3} {k / 6:4.1f}min pop {self.m('popul') * 10:6} $ {self.m('dinheiro'):5} "
                      f"energia {self.m('cons')}/{self.m('prod')}")
            if self.m('venceu'):
                return k
        return None


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('mif', nargs='?', default=os.path.join(AQUI, '..', 'jogo.mif'))
    ap.add_argument('--acoes', type=int, default=4)
    a = ap.parse_args()
    j = Jogador(a.mif, a.acoes)
    k = j.partida()
    print('VITORIA em', f'{k / 6:.1f} min de jogo' if k else 'nao veio')
    print(j.cpu.mostra())
