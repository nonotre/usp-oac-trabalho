"""Emulador sem tela do Processador ICMC, para testar o jogo no terminal.

Segue a semantica do simulador oficial (Simulator_Source/Model.cpp do repo
Processador-ICMC), inclusive as esquisitices dele: registradores sao int,
SUB com resultado negativo vira 0, ADD acima de 65535 subtrai 0xffff.

Uso:
  python3 icmc.py jogo.mif [--passos N] [--teclas "1000000:k,2000000: "]
  Mostra a tela (40x30) no fim. Caractere fora de 32..126 aparece como '#'.
"""
import argparse
import sys

LOAD, STORE, LOADIMED, LOADINDEX, STOREINDEX, MOV = 48, 49, 56, 60, 61, 51
OUTCHAR, SOUND, INCHAR = 50, 52, 53
ADD, SUB, MULT, DIV, INC, LMOD = 32, 33, 34, 35, 36, 37
LAND, LOR, LXOR, LNOT, SHIFT, CMP = 18, 19, 20, 21, 16, 22
JMP, CALL, RTS, PUSH, POP, NOP, HALT, SETC, BREAKP = 2, 3, 4, 5, 6, 0, 15, 8, 14


def bits(v, hi, lo):
    return (v >> lo) & ((1 << (hi - lo + 1)) - 1)


def le_mif(caminho, tam=32768):
    mem = [0] * tam
    dentro = False
    for linha in open(caminho):
        linha = linha.split('--')[0].strip()
        if not dentro:
            dentro = linha.upper().startswith('CONTENT BEGIN')
            continue
        if ':' not in linha:
            continue
        end, val = linha.rstrip(';').split(':')
        end = end.strip()
        val = int(val.strip(), 2)
        if end.startswith('['):
            a, b = end[1:-1].split('..')
            rng = range(int(a), int(b) + 1)
        else:
            rng = [int(end)]
        for i in rng:
            if i < tam:
                mem[i] = val
    return mem


class CPU:
    def __init__(self, mem):
        self.mem = mem
        self.reg = [0] * 8
        self.FR = [0] * 16
        self.pc = 0
        self.sp = 0x7FFC
        self.key = 255
        self.tela = [0] * 1200      # caractere + cor*256
        self.passos = 0
        self.parado = False

    def cond(self, la):
        F = self.FR
        return (la == 0 or (F[0] and la == 7) or ((F[2] or F[0]) and la == 9)
                or (F[1] and la == 8) or ((F[2] or F[1]) and la == 10)
                or (F[2] and la == 1) or (not F[2] and la == 2)
                or (F[3] and la == 3) or (not F[3] and la == 4)
                or (F[4] and la == 5) or (not F[4] and la == 6)
                or (F[5] and la == 11) or (not F[5] and la == 12)
                or (F[6] and la == 14) or (F[9] and la == 13))

    def passo(self):
        m, r, F = self.mem, self.reg, self.FR
        ir = m[self.pc]
        if self.pc > 32767:
            raise RuntimeError('PC passou do fim da memoria')
        self.pc += 1
        self.passos += 1
        rx, ry, rz = bits(ir, 9, 7), bits(ir, 6, 4), bits(ir, 3, 1)
        op = bits(ir, 15, 10)
        if op == INCHAR:
            r[rx] = self.key & 0xff
            self.key = 255
        elif op == OUTCHAR:
            if 0 <= r[ry] <= 1199:
                self.tela[r[ry]] = (r[rx] & 0x7f) + bits(r[rx], 11, 8) * 256
            else:
                print(f'ERRO outchar na posicao {r[ry]} (pc {self.pc - 1})', file=sys.stderr)
        elif op == MOV:
            s = bits(ir, 1, 0)
            if s == 0:
                r[rx] = r[ry]
            elif s == 1:
                r[rx] = self.sp
            else:
                self.sp = r[rx]
        elif op == STORE:
            m[m[self.pc]] = r[rx]; self.pc += 1
        elif op == STOREINDEX:
            m[r[rx]] = r[ry]
        elif op == LOAD:
            r[rx] = m[m[self.pc]]; self.pc += 1
        elif op == LOADIMED:
            r[rx] = m[self.pc]; self.pc += 1
        elif op == LOADINDEX:
            r[rx] = m[r[ry]]
        elif op in (LAND, LOR, LXOR, LNOT):
            a, b = r[ry], r[rz]
            r[rx] = {LAND: a & b, LOR: a | b, LXOR: a ^ b, LNOT: ~a}[op]
            F[3] = int(r[rx] == 0)
        elif op == CMP:
            a, b = r[rx], r[ry]
            F[0], F[1], F[2] = int(a > b), int(a < b), int(a == b)
        elif op == JMP:
            if self.cond(bits(ir, 9, 6)):
                self.pc = m[self.pc]
            else:
                self.pc += 1
        elif op == CALL:
            if self.cond(bits(ir, 9, 6)):
                m[self.sp] = self.pc; self.sp -= 1; self.pc = m[self.pc]
            else:
                self.pc += 1
        elif op == RTS:
            self.sp += 1; self.pc = m[self.sp] + 1
        elif op == PUSH:
            if not bits(ir, 6, 6):
                m[self.sp] = r[rx]
            else:
                m[self.sp] = sum(F[i] << i for i in range(16))
            self.sp -= 1
        elif op == POP:
            self.sp += 1
            if not bits(ir, 6, 6):
                r[rx] = m[self.sp]
            else:
                for i in range(16):
                    F[i] = bits(m[self.sp], i, i)
        elif op == ADD:
            r[rx] = r[ry] + r[rz] + (F[4] if bits(ir, 0, 0) else 0)
            F[3] = F[4] = 0
            if r[rx] == 0:
                F[3] = 1
            elif r[rx] > 0xffff:
                F[4] = 1; r[rx] -= 0xffff
        elif op == SUB:
            r[rx] = r[ry] - r[rz] + (F[4] if bits(ir, 0, 0) else 0)
            F[3] = F[9] = 0
            if r[rx] == 0:
                F[3] = 1
            elif r[rx] < 0:
                F[9] = 1; r[rx] = 0
        elif op == MULT:
            r[rx] = r[ry] * r[rz] + (F[4] if bits(ir, 0, 0) else 0)
            F[3] = F[5] = 0
            if r[rx] == 0:
                F[3] = 1
            elif r[rx] > 0xffff:
                F[5] = 1
        elif op == DIV:
            if r[rz] == 0:
                F[6] = 1; r[rx] = 0; F[3] = 1
            else:
                F[6] = 0
                r[rx] = int(r[ry] / r[rz]) + (F[4] if bits(ir, 0, 0) else 0)
                F[3] = int(r[rx] == 0)
        elif op == LMOD:
            r[rx] = r[ry] % r[rz] if r[rz] else 0
            F[3] = int(r[rx] == 0)
        elif op == INC:
            r[rx] += 1
            if bits(ir, 6, 6):
                r[rx] -= 2
            F[3] = int(r[rx] == 0)
        elif op == SHIFT:
            F[3] = int(r[rx] == 0)
            n, t = bits(ir, 3, 0), bits(ir, 6, 4)
            v = r[rx]
            if t == 0: r[rx] = v << n
            elif t == 1: r[rx] = ~((~v) << n)
            elif t == 2: r[rx] = v >> n
            elif t == 3: r[rx] = ~((~v) >> n)
            else:
                n %= 16; v &= 0xffff
                if bits(ir, 6, 5) == 2: r[rx] = ((v << n) | (v >> (16 - n))) & 0xffff
                else: r[rx] = ((v >> n) | (v << (16 - n))) & 0xffff
        elif op == SETC:
            F[4] = bits(ir, 9, 9)
        elif op == HALT:
            self.parado = True
        # NOP, BREAKP, SOUND: nada

    def roda(self, n, teclas=()):
        teclas = sorted(teclas)
        i = 0
        while self.passos < n and not self.parado:
            while i < len(teclas) and teclas[i][0] <= self.passos:
                self.key = ord(teclas[i][1]); i += 1
            self.passo()

    def mostra(self, cor=False):
        out = []
        for y in range(30):
            linha = ''
            for x in range(40):
                c = self.tela[y * 40 + x] & 0x7f
                linha += chr(c) if 32 <= c < 127 else ('#' if c else ' ')
            out.append(linha)
        return '\n'.join(out)


def le_teclas(txt):
    res = []
    for item in txt.split(',') if txt else []:
        t, k = item.split(':', 1)
        k = {'enter': '\r', 'espaco': ' '}.get(k, k)
        res.append((int(t), k))
    return res


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('mif')
    ap.add_argument('--passos', type=int, default=2_000_000)
    ap.add_argument('--teclas', default='')
    a = ap.parse_args()
    cpu = CPU(le_mif(a.mif))
    cpu.roda(a.passos, le_teclas(a.teclas))
    print(cpu.mostra())
    print(f'passos {cpu.passos}  pc {cpu.pc}  sp {cpu.sp}  regs {cpu.reg}')
