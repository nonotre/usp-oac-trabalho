# Design do jogo

Cidade simplificada no estilo SimCity (SNES). O objetivo é chegar a 100 mil habitantes no menor tempo.

## Limites do Processador ICMC que moldam o jogo

| Limite | Consequência |
|---|---|
| Tela 40×30 caracteres, 16 cores (`caractere + cor*256`) | A cidade é desenhada com caracteres |
| `charmap.mif` com 128 desenhos 8×8 de uma cor; 0 a 31 vêm em branco | Cerca de 32 desenhos próprios sem perder letras |
| `inchar` lê 1 código por vez, 255 se nada foi apertado | Setas não funcionam (chegam como 3 códigos); só letras, números, espaço, Enter |
| Sem timer nem interrupção | O ritmo é contado em voltas do laço principal, calibrado no simulador |
| Sem gerador aleatório | Tabela de números ou contador amostrado nas teclas |
| 16 bits sem sinal (0 a 65535) | População guardada em dezenas (100 mil = 10000), impressa com um "0" no fim |
| Redesenhar a tela inteira é lento | Só se redesenha o bloco que mudou |
| Memória de 32K palavras para código e dados | Cada tela cheia ocupa 1200 palavras: no máximo umas 10 telas |

## Mecânica

**Ritmo:** uma atualização a cada 10 s, sem dia nem mês.

**Construções:**

| Tipo | Papel | Custo |
|---|---|---|
| Residencial | casa: onde as pessoas moram | $40 |
| Comércio | serviço: sem ele as pessoas vão embora | $60 |
| Indústria | emprego: sem ele as pessoas vão embora | $150 |
| Usina pequena | produz 40 de energia | $400 |
| Usina grande | produz 300; liberada com 20 mil habitantes | $2500 |

**População:** a cidade comporta `mín(casas, empregos, serviço)`. A cada atualização chega metade do que falta até esse limite; se a população está acima, sai um quarto do excesso. Construir casa não traz gente sozinho.

**Dinheiro, sem imposto:** quem está ocupado paga a conta de luz. A receita de cada tipo é `3 × energia consumida × fração ocupada`. Casa vazia e fábrica sem trabalhador não pagam. A indústria consome mais e paga mais.

**Níveis:** construir põe o bloco no nível 1. A cada atualização, se um tipo está com 80% ou mais de ocupação e há energia sobrando, até 40% dos blocos dele sobem um nível.

| Nível | Pessoas (casa, emprego ou serviço) | Energia R / C / I |
|---|---|---|
| 1 | 100 | 1 / 1 / 2 |
| 2 | 500 | 2 / 3 / 5 |
| 3 | 3000 | 5 / 6 / 10 |

**Energia:** se o consumo passa da produção, há apagão: tudo funciona na proporção `produção / consumo`, ninguém sobe de nível e a receita cai.

**Início:** $500 e uma vila pronta (1 casa, 1 comércio, 1 indústria, 1 usina pequena). Sem a vila a cidade não arranca: ninguém fica sem os três tipos, e o dinheiro não paga os três mais a usina.

**Fim:** 100 mil habitantes. Sem limite de tempo; o placar é o tempo gasto.

## Balanceamento

Simulação agregada (sem mapa) em `balanceamento/sim.py`, com um jogador guloso:

| Jogador | Vitória | Blocos usados |
|---|---|---|
| 4 construções a cada 10 s | 9,0 min | 135 |
| 2 construções | 12,2 min | 121 |
| 1 construção | 18,5 min | 111 |

Pontos fracos conhecidos:

- A regra do mínimo leva a construir R, C e I em rodízio 1:1:1.
- A partir de uns 6 min sobra dinheiro (cerca de $14 mil no fim): o limite passa a ser a velocidade do jogador. Correções possíveis: nível 4 caro ou terceira usina.

Fica para depois: poluição.

## Tela e controles (proposta, em discussão)

- Cidade em grid de blocos de 2×2 caracteres: 20×12 = 240 blocos nas linhas 0 a 23; painel nas linhas 24 a 29.
- Bloco selecionado destacado por troca de cor; WASD move a seleção.
- Roleta circular de ações: J volta, K avança, espaço aplica no bloco selecionado.
