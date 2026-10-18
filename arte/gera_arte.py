"""Gera charmap.mif e a tabela de glifos do jogo.asm a partir de blocos.txt.

Cada bloco 16x16 vira 4 caracteres (sup. esq., sup. dir., inf. esq., inf. dir.)
e cada icone 8x8 vira 1 caractere. Caracteres iguais sao reaproveitados (o chao
liso usa um caractere so, quatro vezes). Os codigos vem dos livres do charmap:
1 a 31 (menos o 4), as minusculas (97 a 122) e simbolos que o jogo nao imprime.
Letras maiusculas, numeros e os simbolos dos textos continuam os do professor.

Uso: python3 arte/gera_arte.py   (a partir de oac/usp-oac-trabalho/)
"""
import os
import re

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.join(AQUI, '..')
# O 4 fica de fora: o simulador do professor nunca desenha o caractere 4
# (View.cpp testa sym != 32, mas sym e' o codigo * 8).
LIVRES = ([c for c in range(1, 32) if c != 4] + list(range(97, 123))
          + [123, 124, 125, 126, 127, 64, 94, 95, 96, 35, 37, 38])

# (tipo, nivel) de cada bloco no vetor glifo do jogo.asm. O chao serve aos dois
# terrenos (grama e terra): o "nivel" do chao e' o terreno.
POSICAO = {'chao': [(0, 0), (0, 1)], 'casa1': [(1, 1)], 'casa2': [(1, 2)], 'casa3': [(1, 3)],
           'comercio1': [(2, 1)], 'comercio2': [(2, 2)], 'comercio3': [(2, 3)],
           'industria1': [(3, 1)], 'industria2': [(3, 2)], 'industria3': [(3, 3)],
           'usina_pequena': [(4, 1)], 'usina_grande': [(5, 1)]}
CHAO = {'chao'}   # sem a linha preta do grid


def le_blocos():
    blocos, nome, linhas = {}, None, []
    for l in open(os.path.join(AQUI, 'blocos.txt')):
        l = l.rstrip('\n')
        if nome is None and (l.startswith('#') or not l.strip()):
            continue
        if re.fullmatch(r'[a-z_0-9]+', l):
            nome, linhas = l, []
            continue
        if nome.startswith('icone_'):
            linhas.append((l + '.' * 8)[:8])
            if len(linhas) == 8:
                blocos[nome] = linhas
                nome = None
            continue
        if nome in CHAO:
            linhas.append((l + '#' * 16)[:16])
        else:
            linhas.append((l + '.' * 16)[:15] + '.')   # coluna 16 preta
        if len(linhas) == 16:
            if nome not in CHAO:
                linhas[15] = '.' * 16                   # linha 16 preta
            blocos[nome] = linhas
            nome = None
    return blocos


def le_charmap(caminho):
    linhas = [0] * 1024
    dentro = False
    for l in open(caminho):
        l = l.split('--')[0].strip()
        if l.upper().startswith('CONTENT BEGIN'):
            dentro = True
            continue
        if not dentro or ':' not in l:
            continue
        end, val = l.rstrip(';').split(':')
        end, val = end.strip(), int(val.strip(), 2)
        if end.startswith('['):
            a, b = map(int, end[1:-1].split('..'))
        else:
            a = b = int(end)
        for i in range(a, b + 1):
            linhas[i] = val
    return linhas


def quarto(bloco, qy, qx):
    return tuple(int(bloco[qy * 8 + y][qx * 8:qx * 8 + 8].replace('#', '1').replace('.', '0'), 2)
                 for y in range(8))


def main():
    blocos = le_blocos()
    cm = le_charmap(os.path.join(AQUI, 'charmap_padrao.mif'))
    livres = iter(LIVRES)
    ja = {}          # desenho 8x8 -> codigo (reaproveita caracteres iguais)

    def codigo(desenho):
        if desenho not in ja:
            c = next(livres)
            cm[c * 8:c * 8 + 8] = desenho
            ja[desenho] = c
        return ja[desenho]

    codigos = {}
    for nome, b in blocos.items():
        if nome.startswith('icone_'):
            codigos[nome] = [codigo(quarto(b, 0, 0))]
        else:
            codigos[nome] = [codigo(quarto(b, qy, qx)) for qy, qx in ((0, 0), (0, 1), (1, 0), (1, 1))]

    with open(os.path.join(RAIZ, 'charmap.mif'), 'w') as f:
        f.write('-- Charmap do Cidade ICMC: letras do professor e blocos de arte/blocos.txt\n')
        f.write('-- Gerado por arte/gera_arte.py\n\nWIDTH=8;\nDEPTH=1024;\n\n')
        f.write('ADDRESS_RADIX=UNS;\nDATA_RADIX=BIN;\n\nCONTENT BEGIN\n')
        for i, v in enumerate(cm):
            f.write(f'\t{i}  :   {v:08b};\n')
        f.write('END;\n')

    tab = ['; >>> glifos (gerado por arte/gera_arte.py a partir de arte/blocos.txt)',
           'glifo : var #96']
    for nome, posicoes in POSICAO.items():
        for t, n in posicoes:
            base = (t * 4 + n) * 4
            for k, c in enumerate(codigos[nome]):
                tab.append(f'static glifo + #{base + k}, #{c}' + (f'          ; {nome}' if k == 0 else ''))
    tab.append('glifoSel : var #4')
    for k, c in enumerate(codigos['cursor']):
        tab.append(f'static glifoSel + #{k}, #{c}' + ('          ; cursor' if k == 0 else ''))
    for nome in blocos:
        if nome.startswith('icone_'):
            rot = 'icone' + nome[6:].capitalize()
            tab.append(f'{rot} : var #1')
            tab.append(f'static {rot} + #0, #{codigos[nome][0]}')
    tab.append('; <<< glifos')

    asm = os.path.join(RAIZ, 'jogo.asm')
    s = open(asm).read()
    s = re.sub(r'; >>> glifos.*?; <<< glifos', '\n'.join(tab), s, flags=re.S)
    open(asm, 'w').write(s)
    print('blocos:', len(blocos), ' caracteres usados:', len(ja), 'de', len(LIVRES))


if __name__ == '__main__':
    main()
