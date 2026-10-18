# Design do jogo

Cidade simplificada no estilo SimCity (SNES). O objetivo é chegar a 100 mil habitantes antes do dia 999.

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

**Construções:** o preço é progressivo: começa no valor inicial e sobe a cada unidade daquele tipo que já existe no mapa (demolir baixa de novo).

| Tipo | Papel | Preço inicial | + por unidade no mapa |
|---|---|---|---|
| Residencial | casa: onde as pessoas moram | $40 | $5 |
| Comércio | serviço: sem ele as pessoas vão embora | $60 | $10 |
| Indústria | emprego: sem ele as pessoas vão embora | $150 | $25 |
| Usina pequena | produz 40 de energia (a primeira é de graça) | $400 | $200 |
| Usina grande | produz 300; liberada com 20 mil habitantes | $2500 | $1000 |

**População:** a cidade comporta `mín(casas, empregos, serviço + empregos / 10)`. A indústria atrai um pouco de gente mesmo sem comércio (quem vem atrás de emprego): 10% dos empregos contam como serviço. Com 1 casa e 1 indústria e nenhum comércio, chegam umas 10 pessoas. A cada atualização chega metade do que falta até esse limite; se a população está acima, sai um quarto do excesso. Construir casa não traz gente sozinho.

**Dinheiro, sem imposto:** quem está ocupado paga a conta de luz. A receita do dia é `3 × Σ (energia consumida × fração ocupada)`, com a ocupação em dezesseis avos. Casa vazia e fábrica sem trabalhador não pagam; a indústria consome mais e paga mais. A conta é feita em dezesseis avos de real, e o que não fecha $1 fica guardado (variável escondida `centavos`) para os dias seguintes: uma cidade que rende $0,20 por dia recebe $1 no quinto dia. Ex.: 1 casa e 1 indústria de nível 1 com 20 pessoas rendem ~$1,70 por dia.

**Níveis:** construir põe o bloco no nível 1. A cada atualização, se um tipo está com 80% ou mais de ocupação e há energia sobrando, até 40% dos blocos dele sobem um nível.

| Nível | Pessoas (casa, emprego ou serviço) | Energia R / C / I |
|---|---|---|
| 1 | 100 | 1 / 1 / 2 |
| 2 | 500 | 2 / 3 / 5 |
| 3 | 3000 | 5 / 6 / 10 |

**Energia:** se o consumo passa da produção, há apagão: tudo funciona na proporção `produção / consumo`, ninguém sobe de nível e a receita cai.

**Início:** $500, mapa vazio (só o terreno) e a primeira usina pequena de graça (o preço aparece $00000 até ela ser construída). Dá para casa, comércio e indústria ($250) logo de cara.

**Dificuldade (18/10/2026):** primeiro os custos fixos subiram (50/100/300/600); depois viraram o preço progressivo acima. Pela conta do `sim.py`, o jogador rápido vence por volta do dia 78; o mais lento, por volta do dia 128. Ninguém fica sem saída.

**Fim:** 100 mil habitantes é vitória: a população pisca em amarelo por ~2 s, toca a música de vitória e vem a tela "100 MIL HABITANTES / EM ddd DIAS". Cada atualização (10 s) é um dia; no dia 999 sem a meta, o mandato acaba ("SEU MANDATO ACABOU", com a população alcançada). Enter recomeça. Com 1 dia a cada 10 s, o prazo dá ~2h45 de jogo: na prática só limita quem deixa o jogo parado.

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

## Tela e controles

- Painel no topo: linha 0 em branco (borda), linha 1 com os números, linha 2 em branco, linha 3 com a roleta. Cidade em grid de blocos de 2×2 caracteres: 20×13 = 260 blocos nas linhas 4 a 29. Não existe meia linha: a tela é uma grade de caracteres de 8 pontos de altura.
- Cursor: pisca a cada ~0,5 s (aparece na hora ao mover). Cada caractere tem uma cor só, sobre preto, então um contorno branco por cima com o miolo visível não existe. No chão, o cursor recorta uma borda preta de 2 pontos e o miolo fica na cor do terreno; no prédio, o desenho acende em branco (recortar a borda em cada prédio custaria 44 caracteres; só sobram 15).
- WASD ou setas movem a seleção. J e K giram a roleta (casa, comércio, indústria, usina pequena, usina grande, demolir); as teclas não aparecem escritas no painel, só na tela inicial. Espaço aplica. R reinicia tudo (volta à tela de título, com som). `+` liga e desliga o tempo acelerado (4×: um dia a cada 2,5 s); enquanto acelerado, o número do dia fica amarelo.
- Demolir devolve metade do custo.
- Apagão: a energia é entregue aos blocos em ordem (de cima para baixo, da esquerda para a direita); quem passa da produção fica sem luz, em azul-escuro, e não conta para casas, serviço, empregos nem receita.

**Painel:**
- Linha 1: dinheiro, pessoinha branca com a população, raio amarelo com a energia `consumo/produção` (vermelha no apagão) e `DIA` (1 a 999).
- Linha 3: `CONSTRUIR: ◀ AÇÃO ▶ VALOR: $preço`. As setas ficam em posição fixa e piscam rápido (somem ~0,12 s) ao apertar J (esquerda) ou K (direita). O preço fica vermelho quando não dá para construir: falta dinheiro ou a usina grande ainda está travada.
- Sem mensagens de texto: construir onde não pode simplesmente não faz nada; o preço vermelho e a energia vermelha já avisam.

**Visual:** o chão é liso: grama (aqua, o verde mais claro da paleta) com manchas de terra (marrom, o único da paleta; tons pastel não existem nas 16 cores fixas do simulador). Grama e terra usam o mesmo caractere cheio, só muda a cor. Os prédios são lotes quadrados de 15×15 pontos na cor do tipo, com o desenho em preto e uma linha preta separando os lotes. Desenhos em `arte/blocos.txt`.

**Mapa aleatório:** a cada partida, grama em tudo e 6 manchas de terra de até 3×3 blocos (centro sempre, vizinhos com chance de 1/2). A semente muda com o tempo que o jogador leva para apertar Enter na tela inicial. A terra é só visual: dá para construir em cima e, ao demolir, ela volta.

| Bloco | Cor | Níveis |
|---|---|---|
| Grama | aqua (verde menta claro), liso | |
| Terra | marrom (avermelhado), liso | |
| Casa | amarelo | casinha, duas casas, prédio |
| Comércio | rosa | loja, galeria, torre |
| Indústria | cinza | fábrica pequena, média, grande |
| Usina pequena / grande | vermelho | |
| Sem luz | azul-escuro | |

Marrom claro não existe na paleta: o "marrom" do simulador é vermelho escuro (165, 42, 42).

**Telas iniciais (duas):**
1. Título: "CIDADE ICMC", uma fileira de prédios desenhados e a história ("CONQUISTE CEM MIL PESSOAS / ANTES QUE SEU MANDATO ACABE"). Pisca "APERTE ENTER PARA TUTORIAL".
2. Tutorial: mini-título LEGENDA (desenho de cada construção, nome na cor dela, frase curta) e mini-título CONTROLES (tecla em verde, ação em branco). Pisca "APERTE ENTER PARA JOGAR".

Textos e desenhos das telas ficam em tabelas lidas por `ImprimeTabela` (posição, cor, texto) e `DesenhaTabGlifos` (posição, desenho, cor). A tela final também pisca o "APERTE ENTER"

## Conferência com a simulação

`ferramentas/joga_teste.py` joga o `jogo.mif` no emulador com a estratégia do `sim.py` (1 atualização = 1 dia):

| Jogador | `sim.py` | `jogo.asm` | Dia da vitória |
|---|---|---|---|
| 4 construções a cada 10 s | 9,2 min | 9,7 min | 59 |
| 2 construções | 12,7 min | 12,8 min | 78 |
| 1 construção | 19,8 min | 20,3 min | 123 |

A regra da indústria atrair gente (empregos / 10 como serviço) entrou em 18/10/2026 sem nova rodada de balanceamento.

## Sons

Instrução `SOUND frequência, duração (ms), onda` do simulador do professor (como o `teste_som.asm` dele); onda 0 seno, 1 quadrada, 2 triângulo, 3 dente de serra. Cada som é uma tabela de notas tocada pela rotina `Som`.

| Quando | Som |
|---|---|
| Mover o cursor | toque grave curtíssimo (8 ms) |
| J / K na roleta | clique mais grave / mais agudo |
| Construir casa | duas notas subindo (triângulo) |
| Construir comércio | três notas subindo (quadrada) |
| Construir indústria | duas notas graves (dente de serra) |
| Construir usina pequena / grande | "liga" de 3 / 4 notas (quadrada) |
| Demolir | três notas descendo |
| Não dá para construir/demolir | nota grave curta |
| Algum bloco subiu de nível | duas notas rápidas |
| Gente indo embora | duas notas suaves descendo (seno) |
| Começou um apagão | dois tons graves |
| `+` liga / desliga o acelerado | três notas subindo / descendo |
| R (reiniciar) | três notas descendo |
| Enter nas telas | bipe |
| Vitória / mandato acabou | melodia de 4 / 3 notas |

**O simulador para enquanto o som toca** (tela e teclado congelam), então os sons do jogo têm 15 a 160 ms; só vitória e derrota são mais longos, quando o jogo já acabou.
