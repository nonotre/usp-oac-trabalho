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

**Fim:** 100 mil habitantes é vitória ("100 MIL HABITANTES EM ddd DIAS"). Cada atualização (10 s) é um dia; no dia 999 sem a meta, o prazo acaba ("O PRAZO ACABOU", com a população alcançada). Enter recomeça. Com 1 dia a cada 10 s, o prazo dá ~2h45 de jogo: na prática só limita quem deixa o jogo parado.

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
- WASD ou setas movem a seleção. J e K giram a roleta (casa, comércio, indústria, usina pequena, usina grande, demolir); as teclas não aparecem escritas no painel, só na tela inicial. Espaço aplica. `+` adianta uma atualização (para testar e apresentar).
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

**Tela inicial:** título, objetivo numa linha (com a pessoinha), legenda com o desenho de cada construção ao lado do nome (na cor dela) e de uma frase curta, a regra do dinheiro ("quem mora e trabalha paga a luz"), os controles em duas linhas (tecla em verde, ação em branco) e "APERTE ENTER" piscando. A tela final também pisca o "APERTE ENTER". Os textos ficam numa tabela (posição, cor, texto) lida por `ImprimeTabela`.

## Conferência com a simulação

`ferramentas/joga_teste.py` joga o `jogo.mif` no emulador com a estratégia do `sim.py` (1 atualização = 1 dia):

| Jogador | `sim.py` | `jogo.asm` | Dia da vitória |
|---|---|---|---|
| 4 construções a cada 10 s | 9,0 min | 9,2 min | 56 |
| 2 construções | 12,2 min | 12,3 min | ~75 |
| 1 construção | 18,5 min | 18,7 min | ~113 |
