# Feature: Batalha por turnos

Documento da dinâmica de combate do BotBattle — o que o jogador vive, as regras que
sustentam isso e onde cada peça mora no código.

---

## 1. A experiência

A batalha acontece numa arena vista de trás do personagem do jogador. O **R-7**
(azul) ocupa o primeiro plano, de costas, ocultando parcialmente os pés atrás do
painel de comandos; a **Sentinela V-9** (vermelha) está à frente, na plataforma
distante. A profundidade vem da diferença de escala, das linhas de fuga do piso e do
fato de o herói passar por cima da UI de fundo.

O jogador nunca controla o corpo do personagem — ele **dá ordens**. Quando é a vez do
R-7, os botões da base acendem e o log pergunta *"Sua vez. O que R-7 deve fazer?"*.
Escolhido um ataque, um segundo toque decide **onde** acertar (ou dispensa a mira). Aí
os botões desligam, o personagem executa, os números aparecem e o turno passa.

Leitura da tela, de cima para baixo:

| Região | Conteúdo |
| --- | --- |
| Topo | Nome e barra de vida do oponente |
| Abaixo do topo | Painel de hitboxes do oponente — só com o debug ligado (seção 4) |
| Em seguida | Log de combate (uma linha por evento) |
| Meio | Arena com os dois lutadores |
| Base | Vida e energia do R-7 + os três botões de ação |

---

## 2. O ciclo de um turno

```
              ┌──────────────────────────────────────────┐
              │  Nova rodada: fila ordenada por VELOC.   │
              └────────────────────┬─────────────────────┘
                                   ▼
                       ┌───────────────────────┐
                       │  next_turn()          │
                       │  guarding = false     │
                       └───────┬───────────────┘
                     jogador?  │
                  ┌────────────┴────────────┐
                  ▼ sim                     ▼ não
        awaiting_input                 IA escolhe ação e mira
        (botões acendem)                       │
        + escolha do alvo                      │
                  │                            │
                  └────────────┬───────────────┘
                               ▼
                       perform()  → calcula o resultado (ainda não aplica)
                               ▼
                       a cena ANIMA o golpe
                               ▼
                       commit()   → aplica dano/cura/defesa no impacto
                               ▼
                       números flutuantes + log + barras
                               ▼
                    fim de batalha?  ── sim ──▶  banner VITÓRIA / DERROTA
                               │ não
                               └──▶ next_turn()
```

**Ordem de iniciativa.** No começo de cada rodada a fila é montada com todos os
lutadores vivos, embaralhada e então ordenada por `speed` decrescente — o embaralhar
antes faz o desempate ser aleatório em vez de sempre favorecer o mesmo lado. Com os
valores atuais (R-7 com 14, Sentinela com 12), o jogador abre todas as rodadas.

**Guarda dura um turno.** `guarding` é zerado no início do próprio turno de quem
defendeu, ou seja: defender protege exatamente contra o que vier até você agir de novo.

**Por que dois passos (`perform` → `commit`).** `perform()` decide o resultado e o
anuncia; a cena roda a animação; só então `commit()` altera o estado. É isso que faz o
número de dano nascer no momento do impacto — a 0,22 s do avanço no ataque corpo a
corpo, a 0,14 s do disparo no plasma — e não antes de o golpe encostar.

---

## 3. Hitboxes: o corpo em seis pedaços

Cada combatente é feito de **seis hitboxes independentes** — cabeça, tórax, braço
esquerdo, braço direito, perna esquerda e perna direita. Cada uma tem vida própria, e
a **vida total do combatente é a soma das seis**. A barra do topo da tela não é um
número separado: ela é o somatório das partes.

| Hitbox | Vida (R-7) | Vida (V-9) | Chance de ser atingida | Dano recebido | Arma |
| --- | --- | --- | --- | --- | --- |
| Cabeça | 14 | 16 | 9% | +50% | — |
| Tórax | 34 | 38 | 27% | normal | — |
| Braço esq. | 22 | 24 | 14% | −15% | canhão de plasma |
| Braço dir. | 22 | 24 | 14% | −15% | lâmina (ataque normal) |
| Perna esq. | 14 | 14 | 18% | −10% | — |
| Perna dir. | 14 | 14 | 18% | −10% | — |
| **Total** | **120** | **130** | | | |

Os braços são as hitboxes mais grossas de propósito: são elas que carregam as armas
(seção 5), e um braço frágil demais pularia de "inteiro" para "destruído" num golpe só,
sem o jogador nunca ver a fase de arma degradada.

**O sorteio.** Por enquanto o golpe cai numa parte aleatória — mas não uniforme: o peso
de cada hitbox é a sua área aparente, então o tórax é atingido três vezes mais que a
cabeça. Só partes ainda intactas entram no sorteio. Quando a mira por toque existir,
é este sorteio que dá lugar à escolha do jogador; o resto da mecânica não muda.

**O bônus da parte.** A hitbox atingida ajusta o dano: um acerto na cabeça soma 50%, um
no braço desconta 15%. A média ponderada dá ≈0,97, ou seja, o sistema de hitboxes
**não** alterou o equilíbrio da batalha — ele adicionou variância e leitura.

O bônus da hitbox e o do crítico **somam**, não se multiplicam. Empilhados, um crítico
na cabeça com o canhão de plasma tirava quase toda a vida do oponente de um golpe;
somados, o mesmo golpe continua devastador sem decidir a batalha sozinho.

**O transbordo.** Um golpe de 37 numa hitbox de 15 não desperdiça 22 pontos: a parte
absorve o que cabe e o excedente se dissipa pelas outras hitboxes intactas, na ordem
tórax → pernas → braços → cabeça. Mas o respingo **fere sem mutilar**: ele para em 1 de
vida em cada parte vizinha. Só o golpe direto — ou o mirado — arranca um membro.

Três consequências, e as três importam:

- nenhum ponto de dano se perde, então a vida total cai exatamente o quanto o golpe
  valeu — é o que mantém a duração da batalha previsível;
- uma parte destruída não vira escudo. Sem o transbordo, os golpes sorteados em membros
  já destruídos não fariam nada e a batalha poderia nunca terminar;
- perder um braço ou uma perna é sempre consequência de acertar *aquela* parte. Antes do
  piso de 1, um golpe forte na cabeça varria o tórax e as duas pernas de uma vez e
  imobilizava de raspão — o que tornava o desarme (seção 6) quase um acidente.

A exceção é o golpe que excede o corpo inteiro: quando não há mais onde ferir
respeitando o piso, o excedente leva o que restar. É o que garante que um golpe letal
seja letal.

**Não há cura.** Nenhuma ação recupera vida, então todo dano é definitivo: a batalha
só anda numa direção. Uma hitbox destruída fica destruída até o fim do combate — o que
torna perder um braço uma perda real, não um contratempo. (A maquinaria de reparo
continua no código, em `Body.repair()`, à espera de um item ou de um aliado médico.)

**A morte** acontece quando o total zera — não quando a cabeça ou o tórax caem. Perder
um membro hoje é só perder vida; consequências por membro (braço destruído reduzindo o
ataque, perna reduzindo a velocidade) são o próximo passo natural desta feature.

**Onde o jogador vê isso.** No log (*"R-7 acertou o braço direito: 21 de dano"*,
*"Sentinela V-9 perdeu o braço direito!"*) e no número flutuante, que traz o nome da
hitbox embaixo do valor. O detalhamento parte a parte fica no painel de depuração.

---

## 4. O painel de depuração

O app tem uma **flag global de debug** (autoload `Debug`, em `globals/debug.gd`).
Enquanto ela está ligada, aparece logo abaixo da barra de vida do oponente um painel
com uma linha por hitbox: nome, barra e `atual/máximo`. A barra muda de cor conforme a
parte se desgasta (verde → amarelo → vermelho) e fica cinza quando é destruída; a linha
pisca em vermelho quando aquela hitbox é atingida.

Como ligar:

| Como | Quando |
| --- | --- |
| **F3** (ou toque com três dedos) | a qualquer momento, durante o jogo |
| `-- --debug-on` na linha de comando | já na abertura |
| `botbattle/debug/enabled` em `project.godot` | padrão do projeto |

`Debug` emite o sinal `changed(enabled)`, então qualquer ferramenta futura de inspeção
pode se pendurar nele e aparecer/sumir junto — é a flag geral do app, não uma opção
específica das hitboxes.

---

## 5. As armas: uma em cada braço

Cada braço empunha uma arma, e o estado do braço manda na arma:

| Braço | Arma | Ação |
| --- | --- | --- |
| Direito | Lâmina | **Atacar** |
| Esquerdo | Canhão de plasma | **Plasma** |

**O braço degrada, a arma enfraquece.** O dano da ação é multiplicado pela integridade
do braço que a empunha:

```
eficiência = 0,5 + 0,5 × (vida do braço ÷ vida máxima do braço)
```

Braço inteiro entrega 100%; braço em frangalhos entrega 50%. O piso é deliberado: sem
ele, a arma viraria inútil bem antes de o braço cair, o que na prática seria perder a
arma duas vezes.

**O braço cai, a arma some.** Quando a hitbox do braço chega a zero, a ação que depende
dela deixa de existir — o botão fica desabilitado marcado como *perdido*, e a IA para de
escolher aquela ação. Perder o braço esquerdo é ficar sem plasma pelo resto da batalha;
perder o direito é ficar sem o ataque corpo a corpo.

Isso vale para os dois lados e **é definitivo** — não há reparo no jogo. É o que dá
objetivo ao acerto aleatório: **desarmar o oponente é uma vitória parcial e permanente**.
Uma Sentinela sem o braço esquerdo não dispara mais plasma pelo resto da batalha, e o
combate muda de ritmo na hora.

**O jogador vê isso em três lugares:** no corpo do robô (a arma é desenhada no
antebraço, e quando o braço cai o membro inteiro some do desenho — sobra o ombro, e a
silhueta assimétrica conta de longe o que aconteceu), no rótulo do botão
(`Plasma / 12 EN · 68%` → `Plasma / perdido`) e no log (*"Sentinela V-9 perdeu o braço
esquerdo! Sem canhão de plasma."*).

Note que esquerda e direita são do ponto de vista do robô: como o R-7 é visto de costas
e a Sentinela de frente, os lados aparecem espelhados na tela — e o desenho já leva isso
em conta.

---

## 6. Mobilidade: para que servem as pernas

Sem deslocamento não há investida. **Perder qualquer uma das pernas remove o ataque
corpo a corpo** — o braço da lâmina continua lá, intacto e ainda sendo uma hitbox, mas
a ação deixa de existir. Sobra o plasma, que dispara parado.

Isso obrigou a separar dois conceitos que antes viviam no mesmo campo do catálogo:

| Campo em `Actions.LIST` | O que faz | `attack` | `plasma` | `guard` |
| --- | --- | --- | --- | --- |
| `power_part` | a hitbox cuja integridade **escala o dano** | braço dir. | braço esq. | — |
| `requires` | as hitboxes que precisam existir para a **ação existir** | braço dir. + as duas pernas | braço esq. | — |

`Combatant.can_use()` checa `requires`; `missing_requirement()` devolve qual hitbox está
faltando, e é isso que faz o botão dizer `imobilizado` para a perna e `perdido` para o
braço. No desenho, a perna destruída some e o robô se escora ~7° para o lado que restou.

### A segunda forma de perder

Quem fica sem **nenhuma** forma de causar dano perde a batalha ali, com a vida que
tiver. É a consequência natural da regra: imobilizado e sem o canhão, não há o que
fazer — defender para sempre não é jogo.

`Combatant.has_offense()` responde se ainda existe alguma ação de dano com os requisitos
satisfeitos. Ele **ignora energia de propósito**: sem EN dá para defender e recarregar,
o que não é estar desarmado. `BattleManager._check_end()` checa isso depois da vida, e o
banner explica o motivo (`R-7 sem meios de atacar`).

---

## 7. Mira: escolher onde acertar

O golpe aleatório continua sendo o padrão. Mirar é um **segundo toque**: escolhida a
ação de ataque, os botões dão lugar às seis hitboxes do oponente, cada uma com a chance
de a mira pegar. **Aleatório** dispensa a mira, **Voltar** desfaz a escolha da ação.

A chance é proporcional à área da parte — mirar em alvo pequeno é aposta:

| Alvo | Chance de a mira pegar |
| --- | --- |
| Tórax | 100% |
| Perna esq. / dir. | 83% |
| Braço esq. / dir. | 75% |
| Cabeça | 67% |

Quando a mira falha, o golpe cai no sorteio ponderado de sempre — é assim que o ataque
aleatório continua existindo dentro do golpe mirado. O log conta os dois casos:
*"R-7 acertou a cabeça"* quando pega, *"R-7 mira a cabeça e acerta o tórax"* quando não.

`Body.aimed_target(preferred)` é o único ponto que decide isso, e `Body.aim_chance()`
calcula a probabilidade a partir do peso da hitbox — os mesmos pesos que já governavam
o sorteio.

**A Sentinela também mira**, em 40% dos golpes, e mira para desarmar: primeiro o braço
do plasma, depois uma perna, depois a cabeça. Nos outros 60% ataca sem mira. Ou seja,
ela vai atrás das suas pernas com a mesma intenção com que você vai atrás das dela.

---

## 8. As três ações

| Ação | Custo | Exige | Efeito |
| --- | --- | --- | --- |
| **Atacar** | — | braço dir. + as duas pernas | Avança e golpeia. 95% de acerto, 10% de crítico. |
| **Plasma** | 12 EN | braço esq. | Disparo à distância. Ignora **metade da defesa**, nunca erra, 15% de crítico, potência 1,85×. |
| **Defender** | — | — | Dobra a defesa e reduz o dano recebido em 45% até o próximo turno. Recupera **6 EN**. |

Sem cura no jogo, a energia serve só ao Plasma: 40 EN são três disparos. **Defender**
passa a acumular uma segunda função — além de aparar o golpe, devolve 6 EN, e é a única
forma de comprar um disparo a mais numa batalha longa.

Um botão fica desabilitado quando falta energia **ou quando o braço que empunha a arma
foi destruído** — o custo e a condição da arma aparecem na própria face do botão
(`Plasma / 12 EN · 68%`).

O catálogo vive em `combat/actions.gd`, em `Actions.LIST`. Cada entrada é um dicionário
com `kind` (`damage`, `heal` ou `guard`), custo, e os parâmetros que a fórmula lê:
`power`, `pierce`, `crit`, `accuracy`, `amount`, `mp_regen`. A frase do log também é
um campo (`log`), com `%s` para quem age e, opcionalmente, um segundo `%s` para o alvo.

---

## 9. A fórmula de dano

Em `BattleManager._roll_damage()`:

```gdscript
ofensiva = ataque_do_atacante * power * eficiência_do_braço_que_empunha
defesa   = defesa_do_alvo * (1 - pierce)
if alvo_defendendo:
    defesa *= 2

dano = max(1, ofensiva - defesa * 0.5) * aleatorio(0.90 … 1.12)

hitbox = sorteio_ponderado(partes_intactas_do_alvo)
bonus  = 1 + (hitbox.multiplicador - 1)      # +0,5 na cabeça … −0,15 num braço
if critico:  bonus += 0.75                   # chance = crit da ação
dano *= bonus

if alvo_defendendo:    dano *= 0.55
```

A defesa entra pela metade de propósito: ela **amortece** o golpe, não o anula, então
subir defesa nunca deixa um inimigo invulnerável. O piso de 1 garante que todo acerto
machuca. A variação de ±10% evita que a batalha vire uma conta fixa.

Números reais com as fichas atuais:

| Situação | Tórax | Cabeça | Braço |
| --- | --- | --- | --- |
| R-7 ataca a Sentinela | ~21 | ~31 | ~18 |
| R-7 usa Plasma | ~46 | ~68 | ~39 |
| Sentinela ataca o R-7 | ~16 | ~24 | ~14 |
| Sentinela ataca o R-7 **defendendo** | ~6 | ~8 | ~5 |

Com o braço do plasma pela metade, esses 46 caem para ~35 — a arma degradada entrega
75% (eficiência `0,5 + 0,5 × 0,5`).

Com 130 de vida na Sentinela, isso dá uma batalha de 6 a 8 rodadas se o jogador
alternar ataque e plasma — longa o bastante para as decisões importarem, curta o
bastante para uma sessão de celular.

---

## 10. As fichas

Uma unidade é um recurso `UnitStats` (`units/*.tres`), editável pelo Inspetor:

| Atributo | R-7 | Sentinela V-9 | Para que serve |
| --- | --- | --- | --- |
| `head_hp` / `torso_hp` / `arm_hp` / `leg_hp` | 14 / 34 / 22 / 14 | 16 / 38 / 24 / 14 | Vida de cada hitbox — o total (120 e 130) é a soma |
| `max_mp` | 40 | 30 | Energia das habilidades |
| `attack` | 26 | 22 | Base do dano |
| `defense` | 12 | 10 | Amortece o dano recebido |
| `speed` | 14 | 12 | Ordem dos turnos |
| `body_color` / `accent_color` | azul | vermelho | Cores do corpo e do reator |

O oponente é mais duro e mais lento; o herói bate mais forte e age primeiro, mas tem
menos vida. A energia é o recurso que separa uma batalha bem jogada de uma medíocre:
40 EN dão três plasmas, e cada turno defendendo devolve 6 — o suficiente para um quarto
disparo se você souber a hora de recuar.

---

## 11. A IA do oponente

Em `BattleManager._choose_ai_action()`, avaliada em ordem:

1. **Energia para o Plasma e braço esquerdo de pé** → dispara (45% de chance).
2. **Vida abaixo de 50%** → defende (18% de chance) — e recupera energia para o próximo disparo.
3. **Corpo permite o corpo a corpo** → ataque básico.
4. Sem nenhuma ofensiva possível → só resta defender (e a batalha acaba pela regra do desarme).

Em cada golpe, `_ai_aim()` decide se ela mira (40%) e em quê, na ordem braço do plasma →
perna → cabeça.

Cada opção passa por `Combatant.can_use()`, o mesmo teste que habilita os botões do
jogador: energia suficiente **e** o braço da arma intacto.

O resultado é um oponente que parece pensar: guarda o plasma para abrir vantagem e
recua para defender quando está em desvantagem, o que também recarrega a energia do
próximo disparo. As probabilidades impedem que o jogador decore o padrão.

---

## 12. Fim da batalha

Após cada `commit()` o manager verifica os dois lados, em duas condições. A primeira é a
vida: um lado sem lutadores vivos perde. A segunda é o **desarme**: um lado de pé, mas
sem ninguém capaz de causar dano, também perde — e `manager.end_reason` carrega o motivo
para o subtítulo do banner.

Em qualquer um dos casos `battle_finished(player_won)` é emitido: o derrotado tomba e desbota
(rotação + fade), e depois de ~0,9 s aparece o banner **VITÓRIA** ou **DERROTA** com o
botão *Lutar de novo*, que recarrega a cena.

---

## 13. Onde cada coisa mora

| Arquivo | Responsabilidade |
| --- | --- |
| `combat/battle_manager.gd` | **Regras.** Fila de turnos, fórmulas, IA, condição de vitória. Não conhece a UI. |
| `combat/actions.gd` | Catálogo de ações e seus parâmetros. |
| `combat/combatant.gd` | Vida, energia, estado de guarda e animações do corpo (avanço, tremor, flash, queda). |
| `combat/unit_stats.gd` | Ficha de atributos, com a vida de cada hitbox. |
| `combat/body.gd` | O corpo: sorteio de acerto, mira, transbordo do excedente e reparo. |
| `ui/target_picker.gd` | O segundo toque: onde atacar, com as chances de cada hitbox. |
| `combat/body_part.gd` | Uma hitbox isolada. |
| `combat/actions.gd` | Também define qual braço empunha cada arma e a curva de eficiência. |
| `globals/debug.gd` | Autoload `Debug`: a flag global de depuração. |
| `ui/hitbox_debug_panel.gd` | O painel de hitboxes do oponente. |
| `scenes/battle/battle.gd` | **Apresentação.** Escuta os sinais, anima, mostra números e cuida dos botões. |
| `ui/damage_number.gd` | Números flutuantes. |

O manager se comunica só por sinais: `message`, `round_started`, `awaiting_input`,
`action_performed`, `action_committed`, `battle_finished`. Qualquer outra interface
(um tutorial, um replay, um teste) pode escutar os mesmos sinais sem tocar nas regras
— é exatamente o que `tools/smoke_test.gd` faz para jogar uma partida inteira sozinho.

---

## 14. Como estender

**Nova ação.** Adicione uma entrada em `Actions.LIST` e um `Button` no `ActionGrid` de
`scenes/battle/battle.tscn` com `metadata/action` igual ao id. O botão se conecta
sozinho, mostra o custo e respeita a energia disponível.

**Novo tipo de efeito** (veneno, buff). Crie um `kind` novo e trate-o nos três lugares
que fazem o `match`: `perform()`, `commit()` e `_show_result_fx()`.

**Nova unidade.** Duplique um `.tres` em `units/` e aponte o `stats` de um `Combatant`.

**Mais de um inimigo.** O manager já opera sobre `Array[Combatant]`. Falta a UI:
trocar `first_target_for()` por uma seleção de alvo por toque e desenhar uma barra de
vida por oponente.

**Mira por toque.** Troque `Body.random_target()` por uma seleção feita pelo jogador —
é o único ponto que decide qual hitbox recebe o golpe.

**Devolver a cura ao jogo.** `Body.repair()`, `Combatant.heal()` e o `kind` HEAL do
manager continuam prontos; basta uma entrada nova em `Actions.LIST` e um botão. Note
que o reparo conserta primeiro a hitbox mais avariada, então ele devolveria braços
destruídos — e com eles as armas.

**Nova arma num braço.** Acrescente `"arm": BodyPart.Kind.ARM_*` e `"weapon": "nome"`
à ação em `Actions.LIST`. A eficiência, o bloqueio do botão, o filtro da IA e o aviso
no log passam a valer sem mais nenhuma linha.

**Consequências nas pernas.** Hoje só os braços têm função. Em `Body.apply_damage()`,
quando uma perna entra em `destroyed`, aplique o efeito (menos velocidade, chance de
perder o turno). O `Combatant` já reemite isso pelo sinal `part_hit`.

**Balancear.** Ajuste os `.tres` primeiro; só mexa em `_roll_damage()` se a *forma* da
curva estiver errada (por exemplo, se a defesa estiver pesando demais).
