"""Simulacao agregada da economia do jogo (sem mapa), para testar o balanceamento.

1 tick = 10 s. Populacao guardada em dezenas (100k = 10000), como no Assembly.
Uso: python3 sim.py
"""
P = dict(
    CAP=[0, 10, 50, 300],                       # dezenas de pessoas por nivel
    E={'R': [0, 1, 2, 5], 'C': [0, 1, 3, 6], 'I': [0, 2, 5, 10]},  # energia por nivel
    custo={'R': 40, 'C': 60, 'I': 150},            # preco inicial
    aumento={'R': 5, 'C': 10, 'I': 25, 'U': [200, 1000]},   # + a cada unidade no mapa
    usina=[(400, 40, 0), (2500, 300, 2000)],    # (custo, producao, populacao minima em dezenas)
    TAR=3,          # dinheiro por unidade de energia consumida por quem esta ocupado
    DIN0=500, META=10000, TICKS=120,
    ACOES=4,        # construcoes que o jogador faz por tick
    SUBIR=0.4,      # fracao dos lotes elegiveis que sobe de nivel por tick
    CHEGA=0.5,      # fracao do que falta que chega por tick
    SAI=0.25)       # fracao do excesso que vai embora por tick


def producao(s, P):
    return sum(P['usina'][k][1] * n for k, n in enumerate(s['U']))


def consumo(s, P):
    return sum(P['E'][t][l] for t in 'RCI' for l in s[t])


def tick(s, P):
    cap, cons = producao(s, P), consumo(s, P)
    luz = min(1, cap / cons) if cons else 1
    tot = {t: sum(P['CAP'][l] for l in s[t]) * luz for t in 'RCI'}   # casas, servico, empregos
    sust = min(tot['R'], tot['I'], tot['C'] + tot['I'] / 10)   # industria atrai um pouco
    p = s['pop']
    if p < sust:
        p += max(1, int((sust - p) * P['CHEGA']))
    else:
        p -= int((p - sust) * P['SAI'])
    s['pop'] = p
    rec = 0
    for t in 'RCI':
        occ = min(1, p / tot[t]) if tot[t] else 0
        rec += sum(P['E'][t][l] for l in s[t]) * occ * luz
    s['resto'] = s.get('resto', 0) + P['TAR'] * rec        # centavos guardados
    s['din'] = min(65535, s['din'] + int(s['resto']))
    s['resto'] -= int(s['resto'])
    if luz >= 1:
        for t in 'RCI':
            if tot[t] and p >= 0.8 * tot[t]:
                cand = [i for i, l in enumerate(s[t]) if l < 3]
                for i in cand[:max(1, int(len(cand) * P['SUBIR']))]:
                    s[t][i] += 1
    return cap, cons


def jogador(s, P):
    """Estrategia gulosa: garante energia e constroi o tipo que esta faltando."""
    for _ in range(P['ACOES']):
        if consumo(s, P) + 6 > producao(s, P):
            grande = s['pop'] >= P['usina'][1][2]
            if grande and s['din'] < P['usina'][1][0]:
                return
            k = 1 if grande else 0
            preco = 0 if k == 0 and s['gratis'] else P['usina'][k][0] + P['aumento']['U'][k] * s['U'][k]
            if s['din'] < preco:
                return
            s['din'] -= preco
            if k == 0:
                s['gratis'] = False
            s['U'][k] += 1
            continue
        tot = {t: sum(P['CAP'][max(l, 1)] for l in s[t]) for t in 'RCI'}
        t = min('RCI', key=lambda t: tot[t])
        preco = P['custo'][t] + P['aumento'][t] * len(s[t])
        if s['din'] < preco:
            return
        s['din'] -= preco
        s[t].append(1)


def jogar(P, verbose=False):
    s = dict(R=[], C=[], I=[], U=[0, 0], pop=0, din=P['DIN0'], gratis=True)   # mapa vazio
    for k in range(1, P['TICKS'] + 1):
        jogador(s, P)
        cap, cons = tick(s, P)
        if verbose and (k % 5 == 0 or k < 4):
            print(f"t{k:3} {k / 6:4.1f}min pop {s['pop'] * 10:6} $ {s['din']:5} "
                  f"R{len(s['R'])} C{len(s['C'])} I{len(s['I'])} usinas {s['U']} energia {cons}/{cap}")
        if s['din'] < 0:
            return 'falencia', k
        if s['pop'] >= P['META']:
            return 'vitoria', f"{k / 6:.1f} min", len(s['R']) + len(s['C']) + len(s['I']) + sum(s['U'])
    return 'tempo', k, s['pop'] * 10


if __name__ == '__main__':
    print(jogar(P, verbose=True))
    for a in (2, 1):
        print(f'jogador com {a} acao(oes) por tick:', jogar(dict(P, ACOES=a)))
