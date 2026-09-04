# Plano de execução: montagem

Plano operacional para implementar o [feature_montagem.md](feature_montagem.md). Cada
fase é uma tarefa fechada, com arquivos nomeados, invariantes explícitos e um comando que
prova que ela terminou.

**Leia o [feature_montagem.md](feature_montagem.md) antes de começar qualquer fase.** Este
documento diz *como fazer*; aquele diz *por quê*, e é ele que resolve as dúvidas de
desenho que aparecerem no caminho.

Este é o maior refactor do projeto até aqui: ele troca o modelo de dados que `Loadout`,
`Body`, `Combatant`, `RobotSprite` e o hangar consomem. A ordem das fases existe para que
**o jogo continue rodando ao fim de cada uma**.

---

## Regras válidas para todas as fases

1. **Uma fase por vez.** Termine, verifique, pare e reporte. Não emende a fase seguinte.
2. **Não faça commit** a menos que o usuário peça.
3. **Não refatore fora do escopo da fase.** Se encontrar algo errado que não está na
   lista da fase, anote no relatório e siga.
4. **Estilo da casa.** Comentários e nomes de exibição em português. Indentação com
   **tabs**. Todo `class_name` e toda função pública ganham um comentário `##` que
   explica *por que* aquilo existe, não o que a linha faz — leia `combat/body.gd` e
   `combat/loadout.gd` como referência de tom antes de escrever.
5. **Não apague o desenho procedural** do `RobotSprite` em nenhuma fase. Ele é o
   fallback de toda peça que ainda não tem arte.
6. **Não adicione addons nem dependências.**
7. **Nada é apagado antes da Fase 7.** O modelo antigo convive com o novo até a limpeza —
   é isso que permite verificar cada passo contra o comportamento anterior.

### Pré-requisito

`git status` limpo na branch `feature/fix_trash_and_refactor_code`, com o commit da
reorganização de `content/` já aplicado.

### As duas verificações

**Simulador** — o placar de 200 batalhas:

```
BOTBATTLE_SEED=1 godot --headless --path . -s tools/simulate.gd
```

**Smoke test** — prova que a batalha inteira ainda termina:

```
godot --headless --path . -s tools/smoke_test.gd 2>&1 | grep "Fim da batalha"
```

Em headless as capturas de tela falham com `Cannot call method 'save_png' on a null
value` — **isso é esperado e não é falha**. Não confie no código de saída depois de um
pipe.

### A neutralidade dos atributos

Este refactor **muda regras de combate de propósito** (camadas, blindagem, derrota
funcional), então o placar vai andar. O que **não** pode andar é a aritmética dos
atributos. A invariante que substitui o "placar idêntico" das outras fases é:

> Com a montagem completa e nenhuma peça destruída, `Loadout.resolve()` devolve
> exatamente os mesmos números que devolvia antes do refactor.

Isso é possível porque a migração é desenhada para ser neutra: o que hoje é
`Chassis.base_stats` vira atributo distribuído entre os ossos do esqueleto e as peças de
fábrica, somando o mesmo total. A divergência só aparece quando uma peça cai — que é
exatamente a feature.

Vale o mesmo para a vida: `Chassis.bone_resistance` se divide entre o osso e a peça que o
cobre, **preservando a soma**. Assim a mudança de placar vem só das regras novas, e não
de números que andaram sem querer.

### Quando o placar mudar

O placar muda **em duas fases, e só nelas**: Fase 3 (camadas e blindagem) e Fase 4
(derrota funcional). Nessas duas, registre a nova linha-base no relatório e siga.

Em **qualquer outra fase**, placar diferente é bug. Pare, compare `body.parts` antes e
depois com um script descartável que imprima `key` e `max_hp` na ordem, e ache a
divergência antes de continuar.

---

## Decisões que este plano fecha

O [feature_montagem.md](feature_montagem.md) deixou quatro pontos implícitos que precisam
de resposta para o plano ser executável. Os defaults abaixo estão escolhidos e
justificados — **vetar agora é barato; depois da Fase 2 é migração de conteúdo.**

**1. O quadril ganha vida.** Hoje `hip` tem `hitbox = false` (osso só de transformação).
O modelo novo diz que tudo que está montado tem vida, e um osso sem vida vira exceção no
código que percorre a árvore. O `hip` passa a ter `resistance` e a aparecer no painel de
hitboxes. *É uma hitbox nova, e parte do porquê o placar muda na Fase 3.*

**2. Os sockets de acessório ficam na peça, não no osso.** Os antigos encaixes
`back_1`, `back_2`, `chest_1`, `chest_2` e `head_top` passam a ser publicados pela
**carcaça** e pelo **capacete** — não pelo osso do tronco e da cabeça. É a leitura
recursiva pura: acessório monta em peça. O efeito de jogo é bom — tirar a carcaça para
economizar peso custa também os quatro pontos de montagem.

**3. As classes de socket da família `mk`.** Cinco padrões, seguindo
`<FAMÍLIA>-<CLASSE><REVISÃO>`:

| Padrão | Classe | Onde é publicado |
| --- | --- | --- |
| `MK-A1` | braço | ossos `arm_left`, `arm_right` |
| `MK-B1` | tronco | osso `torso` |
| `MK-C1` | cabeça | osso `head` |
| `MK-D1` | perna | ossos `leg_left`, `leg_right` |
| `MK-E1` | quadril | osso `hip` |
| `RAIL-1` | acessório | publicado **por peças**, universal |

Braço e perna têm padrões distintos de propósito: uma peça de braço encaixando na perna
seria combinação, mas não é a combinação que o jogo quer nesta primeira leva.

**4. A distribuição dos atributos de `mk1`.** `base_stats` de hoje é
`{strength 12, agility 10, defense 4, energy 18, capacity 120}`. A migração distribui:

| Atributo | Vai para | Por quê |
| --- | --- | --- |
| `capacity` 120 | `hip` e `torso`, 60 cada | carga é estrutura — é o que resolve o laço |
| `strength` 12 | braços de fábrica, 6 cada | perder um braço custa metade da força |
| `agility` 10 | pernas de fábrica, 5 cada | perder uma perna custa metade da agilidade |
| `defense` 4 | carcaça | blindagem é do que cobre |
| `energy` 18 | carcaça | o reator mora no tronco |

`capacity` fica só no quadril e no tronco — o par que forma a espinha — e não nos quatro
membros: um braço ou perna a menos muda quanto o robô *pesa*, não quanto ele *aguenta
carregar*. Dividir por sete ossos dava fração; concentrar na espinha é o que evita isso
sem inventar arredondamento.

Com tudo montado a soma é idêntica. Com uma perna a menos, não — e é esse o ponto.

---

## Fase 0 — Linha-base

**Objetivo.** Registrar o comportamento de hoje, para que as fases seguintes tenham contra
o que comparar. Nenhum arquivo muda.

**Passos.**

1. Rodar o simulador com `BOTBATTLE_SEED=1` e copiar as três linhas do placar.
2. Rodar o smoke test e copiar a linha `Fim da batalha`.
3. Escrever um script descartável que carregue `content/units/r7.tres`, chame `resolve()`
   e imprima **todos** os atributos resolvidos, mais `body.parts` com `key` e `max_hp` na
   ordem. Guardar a saída no relatório — é a linha-base da neutralidade.

**Pronto quando.** As três saídas estão no relatório.

---

## Fase 1 — Os recursos, sem consumidor

**Objetivo.** Criar as classes do modelo novo. Fase de puro acréscimo: nada existente
muda de comportamento.

**Arquivos.** Criar `combat/socket_def.gd`, `combat/form.gd`, `combat/skeleton.gd`,
`combat/kit.gd`. Editar `combat/part.gd` e `combat/bone_def.gd`.

**Passos.**

1. Criar as quatro classes novas exatamente como o [feature_montagem.md](feature_montagem.md)
   §5 as define, com todos os campos — inclusive os de pose que ninguém lê ainda.
2. Em `Part`, **acrescentar** `fits: Array[String]` e `sockets: Array[SocketDef]`. O campo
   `slot` continua existindo e continua sendo o que o jogo usa.
3. Em `BoneDef`, **acrescentar** `modifiers: Dictionary[String, int]` e
   `sockets: Array[SocketDef]`. O campo `hitbox` continua existindo.

**Invariantes.** Nenhum consumidor lê os campos novos. `Part.slot`, `SlotDef` e
`MountDef` seguem intactos e em uso.

**Verificação.** Simulador e smoke test **idênticos** à Fase 0.

**Pronto quando.** O projeto abre no editor sem erro e o placar não andou.

---

## Fase 2 — O conteúdo novo, em paralelo

**Objetivo.** Escrever o esqueleto `mk`, as peças de fábrica e o kit `mk1` — sem ninguém
consumindo. É a fase que decide os números, e a mais fácil de verificar isoladamente.

**Arquivos.** Criar `content/forms/humanoid.tres`, `content/skeletons/mk.tres`,
`content/kits/mk1.tres`, seis peças de fábrica em `content/catalog/parts/`. Editar as 11
peças existentes.

**Passos.**

1. **A forma.** `content/forms/humanoid.tres`: `bone_keys` na ordem de hoje
   (`head`, `torso`, `hip`, `arm_left`, `arm_right`, `leg_left`, `leg_right`), o mapa
   `parents` transcrito de `content/anatomy/humanoid.tres`, e a `AnimationLibrary` apontando
   para `content/anatomy/humanoid_animations.tres`.
2. **O esqueleto.** `content/skeletons/mk.tres`: um `BoneDef` por chave da forma, com a
   pose copiada de `humanoid.tres`, `capacity` distribuída nos `modifiers` somando **120**,
   e `resistance` valendo a **fração de osso** da tabela abaixo. Cada osso publica um
   `SocketDef` `main` com o padrão da sua classe (§Decisões 3).
3. **As peças de fábrica.** Seis `.tres` novos — `mk1_head`, `mk1_torso`,
   `mk1_arm_left`, `mk1_arm_right`, `mk1_leg_left`, `mk1_leg_right` — com `fits` no padrão
   do osso que cobrem, os `modifiers` da tabela §Decisões 4, e `resistance` valendo a
   **fração de peça**:

   | Osso | `bone_resistance` hoje | Osso (30%) | Peça de fábrica (70%) |
   | --- | --- | --- | --- |
   | `head` | 14 | 4 | 10 |
   | `torso` | 34 | 10 | 24 |
   | `arm_left` / `arm_right` | 20 | 6 | 14 |
   | `leg_left` / `leg_right` | 18 | 5 | 13 |
   | `hip` | — (sem vida) | 8 | *(sem peça — ver nota)* |

   **O quadril não tem peça de fábrica.** Nenhum `SlotDef` de hoje o cobre — ele já é
   estrutura pura, sem equipamento. O osso `hip` publica o socket `main` (`MK-E1`, ver
   §Decisões 3) igual aos outros, mas o kit `mk1` não preenche esse socket: ele existe
   para uma peça futura (uma "saia" de quadril, por exemplo), e até lá o quadril é o único
   osso que nasce exposto. Os 8 pontos de resistência dele são o valor **integral**, não
   uma fração — não há peça para dividir com ele.

   A carcaça (`mk1_torso`) publica quatro sockets `RAIL-1` (`back_1`, `back_2`,
   `chest_1`, `chest_2`); o capacete (`mk1_head`) publica um (`top_1`); cada braço publica
   um (`rail_1`). A pose de cada socket sai do `SlotDef` correspondente de hoje.
4. **As 11 peças existentes** ganham `fits`, mantendo `slot` intacto:

   | Peça | `slot` hoje | `fits` |
   | --- | --- | --- |
   | `laser_cannon`, `sensor` | `HEAD_TOP` | `["RAIL-1"]` |
   | `dorsal_armor`, `generator` | `BACK` | `["RAIL-1"]` |
   | `power_cell` | `CHEST` | `["RAIL-1"]` |
   | `plasma_cannon`, `short_sword` | `ARM_MOUNT` | `["RAIL-1"]` |
   | `blade_forearm` | `FOREARM` | `["MK-A1"]` |
   | `heavy_arm` | `ARM_FULL` | `["MK-A1"]` |
   | `agile_leg`, `heavy_leg` | `LEG_FULL` | `["MK-D1"]` |

5. **O kit.** `content/kits/mk1.tres`: aponta para o esqueleto `mk` e lista as seis peças
   de fábrica por caminho de socket (`"head/main"`, `"torso/main"`, `"arm_left/main"`…) —
   `"hip/main"` fica de fora, vazio de propósito.

**Invariantes.** Nenhum arquivo `.gd` existente muda de comportamento. `mk2_goliath` e
`mk3_strider` **não** são migrados nesta fase — eles continuam `Chassis` e continuam
funcionando pelo caminho antigo.

**Verificação.** Simulador e smoke test **idênticos** à Fase 0. Mais um script
descartável que carregue `content/kits/mk1.tres` e imprima:

- a soma de `capacity` nos ossos → tem que dar **120**;
- a soma de `resistance` de cada osso com a peça que o cobre → tem que bater com o
  `bone_resistance` de `mk1` osso a osso;
- a soma de cada atributo entre ossos e peças de fábrica → idêntica ao `base_stats` de
  `mk1`.

**Pronto quando.** As três somas batem e o placar não andou.

---

## Fase 3 — A montagem e o corpo pelo modelo novo

**Objetivo.** Trocar o modelo que `Loadout` e `Body` consomem. É a fase de risco do plano.

**Arquivos.** `combat/loadout.gd`, `combat/body.gd`, `combat/body_part.gd`,
`combat/part_catalog.gd`, `combat/combatant.gd`. Criar `combat/kit_catalog.gd` e
`tools/migrate_montagem.gd`. Migrar `content/units/*.tres`.

`combat/combatant.gd` entrou depois de escrito: `available_actions()` monta a chave de
cada hitbox chamando `anatomy.hitbox_key(slot_key, piece)` direto — uma API só do modo
antigo. Sem ajustar isso, toda montagem no modelo novo perde `grants_actions` por
completo e a batalha nunca acaba (só "guard" continua disponível). O ajuste é a um
método novo em `Loadout` (`granting_parts()`, Passo 1.5) que os dois modos alimentam; a
função em si muda de ~15 linhas para uma chamada a ele.

**Passos.**

0. **`Loadout.chassis` NÃO é renomeado.** Descoberta ao desenhar esta fase: `Chassis` e
   `Kit` têm formas diferentes (`full_art_id`, `restricted_tags`… não existem em `Kit`), e
   quatro arquivos fora do escopo desta fase (`actors/robot_sprite.gd`,
   `scenes/hangar/hangar.gd`, `globals/player_loadout.gd`, mais o próprio
   `combat/combatant.gd`) leem `loadout.chassis` com o tipo `Chassis` estaticamente — um
   rename quebraria a compilação deles, não só o visual. Em vez disso, `Loadout` passa a
   ter **dois modos coexistindo**: `chassis: Chassis` + `slots` (como já é hoje,
   intocados) para quem ainda não migrou, e `kit: Kit` + `mounted: Dictionary[String,
   Part]` (chaveado por **caminho de socket**, `"arm_left/main/rail_1"`) para quem migrou.
   `kit` tem prioridade quando presente. `mk2_goliath`/`mk3_strider` seguem 100% no modo
   antigo, intocados. A Fase 7 é quem funde os dois campos em um só, quando o modo antigo
   for embora de vez.
1. Migrar `r7.tres` e `sentinel_v9.tres` com `tools/migrate_montagem.gd`: `kit` aponta
   para `content/kits/mk1.tres`, `mounted` começa de `kit.default_mounted()` (novo método
   em `combat/kit.gd`) e sobrescreve com o que cada unidade já tinha equipado, no
   caminho de socket certo. `chassis`/`slots` ficam vazios nas duas — não são apagados do
   `Loadout`, só não são mais usados por essas duas unidades.
1.5. `Loadout` ganha `mounted_parts()` (percorre a árvore em profundidade: osso → peça →
   peça…) e `granting_parts()` — uma função só, com um `if kit != null` por dentro, que
   devolve `{part, key}` para os dois modos. É o que `combat/combatant.gd` passa a chamar
   em vez de montar a chave à mão com `anatomy.hitbox_key()` — ver a nota em **Arquivos**.
2. `resolve()` ganha um branch `_resolve_kit()`: soma os `modifiers` dos ossos do
   esqueleto, depois os de cada `mounted_parts()`. A regra especial da `capacity`
   (`loadout.gd:236-242`) não é replicada — no modo novo a carga só vem dos ossos, o laço
   nunca existiu (§6 do feature). O branch antigo continua byte a byte.
3. `Body.from_loadout()` ganha um branch `_from_kit()`: um `BodyPart` por osso do
   esqueleto (`BodyPart.from_bone`, reaproveitado), e um por peça montada
   (`BodyPart.from_mounted`, novo em `body_part.gd`), pendurado em quem a sustenta. A
   peça direto no socket de um osso marca `covers_parent = true` — é o que esconde o
   osso da mira enquanto ela viver (novo campo em `BodyPart`, só em memória).
4. Blindagem e estouro (feature §7) em `Body`: `intact_parts()` passa a excluir todo osso
   com uma peça `covers_parent` intacta em cima (`_is_covered()`, novo). Em
   `apply_damage()`, um passo novo entre o golpe direto e o respingo nos vizinhos: se a
   peça atingida tinha `covers_parent` e morreu, o que sobrou do **mesmo golpe** perfura
   o osso exposto sem o piso de 1 que protege o resto do corpo — o piso existe entre
   vizinhos, não dentro da mesma pilha.
5. `part_catalog.gd` ganha `for_standard(standard)`, **ao lado de** `for_slot()` (que o
   hangar ainda usa pelo modo antigo até a Fase 6). Filtra por `part.fits.has(standard)`.

**Invariantes.** `Part.slot`, `SlotDef`, `MountDef`, `Chassis`, `Loadout.slots` e todo o
branch antigo de `resolve()`/`Body.from_loadout()` **continuam existindo e intocados** —
é o que mantém `mk2_goliath`/`mk3_strider` e os quatro arquivos fora do escopo
compilando. `Combatant` ainda usa `hp > 0`; a derrota funcional é a fase seguinte.

**Verificação.** A **neutralidade dos atributos** vale para o **kit vazio de fábrica**
(nada trocado): a soma de `modifiers` dos ossos do esqueleto `mk` com as 6 peças de
fábrica tem que bater exatamente com o `base_stats` antigo de `mk1` — é o que o script da
Fase 2 já confirmou (`strength 12, agility 10, defense 4, energy 18, capacity 120`); rodar
de novo aqui é só confirmar que `resolve()` chega no mesmo número por outro caminho.

**Isso NÃO vale para `r7`/`sentinel_v9` depois de migradas, e não é regressão.** As duas
têm pernas trocadas por `agile_leg`, e a distribuição da Fase 2 (§Decisões 4) pôs a
`agility` de fábrica **nas pernas** (5 cada) — trocar a perna troca o que ela contribui,
igual trocar qualquer outra peça. `agile_leg` só dá `agility 4`, não 5, então o total sobe
de 8 (2×4) em vez dos 18 de antes (10 de base fixa do chassi + 2×4). A base de 10
"sumiu" porque ela nunca devia ter sido fixa — era o chassi inteiro escondendo que a
perna é quem carrega esse número. **Isso é o efeito que a Fase 3 existe para introduzir**,
não um desvio a corrigir. `strength`/`defense`/`energy`/`capacity` de `r7` **continuam
idênticos** aos de antes (nada os move para um encaixe trocável), e são esses quatro que
valem como neutralidade de verdade para as unidades reais — não a `agility`, que muda por
design assim que uma perna troca de dono.

**`max_hp` não bate, e não deveria**: o osso agora soma vida por baixo da peça que o
cobre — o `adopt()` de hoje descarta a resistência do osso ao mesclar num hitbox só; o
modelo em camadas soma as duas. Um osso com peça em cima tem estritamente mais vida
agregada do que tinha fundido. Registre o novo total como parte da linha-base, não como
divergência.

**O placar muda aqui** — registre as três linhas novas como linha-base.

**Pronto quando.** Atributos idênticos, batalha termina, nova linha-base (placar e HP)
registrada.

---

## Fase 4 — Derrota funcional

**Objetivo.** Trocar `hp > 0` por "não consegue mais lutar".

**Arquivos.** `combat/combatant.gd`, `combat/battle_manager.gd`, `scenes/battle/battle.gd`,
`tools/smoke_test.gd`.

Descoberta ao abrir `battle_manager.gd`: o jogo **já tem** uma condição de derrota
funcional — `_check_end()` já chama `_side_can_fight()` → `Combatant.has_offense()`, que
já é "existe ação de dano com os requisitos satisfeitos (inclusive pernas, via
`Actions.needs_legs()`)?". É por isso que `motivo: desarme` já aparecia antes desta fase.
`is_alive() := has_offense()` faz os dois caminhos de fim de batalha (o de `hp>0` e o de
`has_offense()`) convergirem — e isso muda a forma de `_check_end()` mais do que os
Passos abaixo (da versão anterior deste plano) previam.

`scenes/battle/battle.gd` e `tools/smoke_test.gd` entraram porque a decisão do empate
(Passo 3) precisa de um sinal novo (`battle_tied`) **ao lado de** `battle_finished` — e os
dois únicos lugares que escutam `battle_finished` ficariam sem notificação nenhuma para
esse caso. Em `tools/smoke_test.gd` isso não é só falta de log: sem a conexão nova, uma
batalha empatada nunca dispara `_on_finished`, e o teste trava até o timeout de 90s —
exatamente o tipo de travamento que a Verificação desta fase existe para pegar.

**Passos.**

1. `is_alive()` vira `has_offense()`, sem checar `hp` — `available_actions()`
   (`combatant.gd:66`) já dá a lista de ações, e `has_offense()` já aplica o critério de
   alcance (a exigência de pernas incluída). `hp`/`max_hp` continuam existindo, só
   decorativos agora — o HUD lê, a derrota não.
2. Empate de verdade (decidido, ver acima): `_check_end()` checa os dois lados **antes**
   de decidir quem ganhou — um duplo desarme na mesma checagem não vira mais "o jogador
   ganha porque `foes` foi checado primeiro", vira `battle_tied`. Os dois caminhos que
   existiam (`living().is_empty()` e `_side_can_fight()`/`_finish_by_disarm()`) colapsam
   num só (`_finish()`), porque virou a mesma pergunta duas vezes.
3. `battle.gd` ganha um banner "EMPATE" (cor `NEUTRAL_COLOR`, já existia); `smoke_test.gd`
   ganha um `_on_tied()` que fecha o teste do mesmo jeito que `_on_finished()`.

**Verificação.** Smoke test termina. **O placar muda** — registre a nova linha-base.

**Pronto quando.** Nenhuma batalha entra em laço infinito nas 200 do simulador.

---

## Fase 5 — `RobotSprite` recursivo

**Objetivo.** A árvore de nós sai da árvore de montagem, em profundidade arbitrária.

**Arquivos.** `actors/robot_sprite.gd`. `actors/part_node.gd` acabou não precisando de
nenhuma mudança — a API que já tinha (`set_art_resolver`, `set_condition`, `key`,
`art_offset`, `art_height`, `fallback`) já cobria o que o modo `kit` precisava.

Três campos pequenos, em arquivos já abertos desde fases anteriores, fecharam lacunas que
os relatórios das Fases 1/2/3 já tinham sinalizado como "vai doer na Fase 5": `SocketDef`
ganhou `art_height` (faltava desde a Fase 1 — o §5 do feature não previu, e sem ele todo
nó de peça montada desenharia num tamanho fixo errado); `Skeleton` ganhou
`bones_in_order()`/`bone()` (mesmo algoritmo de `Anatomy`, para a árvore de nós poder
criar cada osso já dentro do pai certo); `Kit` ganhou `full_art_id` (sem ele nenhuma
unidade em modo `kit` teria visão fullbody — o herói voltaria para a silhueta montada
mesmo tendo retrato). `Loadout.mounted_parts()` também ganhou uma quarta chave
(`socket`) em cada entrada — o `SocketDef` que a peça ocupa, resolvido durante a própria
travessia, para o `RobotSprite` não precisar re-procurar.

**Passos.**

1. `_build()` percorre os ossos do esqueleto e, para cada socket ocupado, cria o nó da
   peça — e repete recursivamente nos sockets dela, via `Loadout.mounted_parts()`.
2. O caminho do nó passa a ser o caminho do socket (`node.key = path`), o mesmo que
   `Body` já usa como `BodyPart.key` — as duas árvores (visual e de combate) enxergam a
   mesma chave, sem tradução.
3. Espelhamento (decidido, ver acima): nenhum. O código novo nunca seta `flip_h` — cada
   lado desenha a própria arte, sem tentar virar a do outro. `PartNode.flip_h` continua
   existindo e em uso — é o modo `chassis` (mk2/mk3) que ainda depende dele, intocado.
4. O osso só é visível quando nada o cobre — a peça direto no socket dele (`main`,
   qualquer que seja o nome) esconde a silhueta, e reaparece sozinho quando ela cai,
   sem precisar de código extra: a hitbox do osso já reflete isso (§7 do feature).
5. Arte de uma peça montada: se ela tem `art_id` próprio, usa `CharacterArt.part_texture`
   (qualquer peça real de equipamento). Se está direto no socket "main" de um osso e
   **não** tem `art_id` (as 6 peças de fábrica do kit, que não geraram arte própria na
   Fase 2), cai em `CharacterArt.bone_texture(kit.id, osso, ...)` — o mesmo endereço de
   sempre (`characters/mk1/arm_left/…`), só que enderaçado pelo `kit`, não mais pelo
   `chassis`.

**Verificação.** `tools/verify_no_crop.gd` passa sem tocar em `Loadout` (só usa
`CharacterArt` bruto). `tools/verify_hangar_swap.gd` roda sem travar nem lançar erro
fora do esperado em headless — mas **não prova troca visual de verdade** para `r7`: o
`hangar.gd` ainda escreve em `slots` (modo `chassis`), que o modo `kit` ignora. Isso é
esperado — o hangar só passa a mexer em `mounted` na Fase 6. A prova real da árvore
recursiva foi um script dedicado (descartado ao fim, como de praxe): construiu `r7` e
`sentinel_v9` em modo `kit`, forçou visão montada, confirmou as 7+8 e 7+8 chaves
esperadas em `_bone_nodes`/`_mount_nodes`, confirmou textura resolvida em toda peça
montada (`has_art() == true`), e aplicou um golpe de 20 em `arm_left/main` (14 hp) via
`Body.apply_damage()` de verdade — não hp zerado na mão — confirmando o estouro
(`arm_left/main` + `arm_left` destruídos juntos, 14+6=20 exato), o osso reaparecendo
exposto, e o canhão pendurado no rail caindo em cascata.

Placar idêntico ao da Fase 4.

**Pronto quando.** O robô desenha montado, e uma peça sobre peça aparece no lugar certo.

---

## Fase 6 — Hangar em profundidade

**Objetivo.** Deixar o jogador montar acessório sobre peça.

**Arquivos.** `scenes/hangar/hangar.gd`, `combat/loadout.gd`, `combat/socket_def.gd`.
`scenes/hangar/hangar.tscn` acabou não precisando de nada — as linhas da árvore de
sockets são `Button`s criados em código, no mesmo `content: VBoxContainer` que a lista
achatada já usava.

`Loadout` ganhou `available_sockets()` (a árvore inteira, ocupada ou não —
`mounted_parts()` virou um filtro em cima dela) e `mount(path, part)` (equipa ou esvazia,
derruba em cascata o que estava por baixo, devolve o que caiu). `SocketDef` ganhou
`label` — faltava desde a Fase 1, mesmo motivo do `art_height` na Fase 5: o hangar
precisou de um rótulo pros sockets de acessório que não têm osso nenhum pra emprestar o
nome (`SocketDef.label` fica vazio nos sockets "main" — esses usam o `display_name` do
osso, sem duplicar texto).

**Um bug real, achado e corrigido nesta fase, fora do que os Passos previam:** a peça
montada direto no socket de um osso é filha do nó do osso na árvore do Godot (para herdar
a transformação certa). Eu escondia o osso (`node.visible = false`) sempre que uma peça o
cobria — mas no Godot **um nó invisível esconde os filhos junto**, mesmo que o filho
tenha o próprio `visible = true`. Resultado: toda peça no socket "main" desaparecia,
porque o pai dela (o osso "coberto") estava escondido. Não apareceu em nenhuma verificação
de dado (`has_art()`, `visible` do próprio nó, tudo reportava certo) — só apareceu numa
captura de tela de verdade, com GPU real (`capture_hangar.gd` sem `--headless`, que é como
ele já era documentado para rodar — headless usa o renderer *dummy*, que não reproduz
esse tipo de problema). Comparei contra o hangar antigo (`git stash`) pra confirmar que o
robô sempre apareceu ali, e só sumiu no modo `kit` — isolando que era regressão minha, não
comportamento pré-existente. Correção: o osso nunca mais fica invisível; coberto, ele só
troca o próprio `fallback` para vazio (não desenha nada), sem arrastar os filhos.

**Passos.**

1. A lista de encaixes passa a ser a árvore de sockets da montagem atual
   (`available_sockets()`), não uma lista achatada — um socket que só existe porque uma
   peça está montada aparece e some com ela (indentado visualmente por profundidade).
2. As opções de cada socket saem de `PartCatalog.for_standard(socket.standard)`.
3. Tirar uma peça **derruba junto** o que estava montado nela (`Loadout.mount()`); o
   jogador é avisado do que caiu, mesmo texto de aviso que `revalidate()`/troca de
   chassi já usa.

**Verificação.** `tools/capture_hangar.gd` gera a captura sem erro — rodado **sem**
`--headless` (é assim que o próprio script documenta; com `--headless` ele trava
esperando `save_png` funcionar no renderer dummy, que não é bug desta fase). A captura
confirmada visualmente: robô completo, espada e canhão nos braços, idêntico ao modo
`chassis`. `verify_hangar_swap.gd` roda sem travar. A aba Exoesqueleto, em modo `kit`,
mostra um aviso em vez da lista de troca — trocar de chassi legado não teria efeito
nenhum (`kit` sempre vence sobre `chassis`), então a UI diz isso em vez de fingir que
funciona.

**Pronto quando.** Dá para montar o bracelete no braço e a mira no bracelete, pela UI.

---

## Fase 7 — A limpeza

**Objetivo.** Apagar o modelo antigo. Só agora — antes disso ele era a rede de segurança.

**Arquivos.** Apagar `combat/chassis.gd`, `combat/chassis_catalog.gd`,
`combat/slot_def.gd`, `combat/mount_def.gd`, `combat/anatomy.gd`, `actors/art_library.gd`,
`content/anatomy/humanoid.tres`, `content/catalog/chassis/`.

**Passos.**

1. Migrar `mk2_goliath` e `mk3_strider` para esqueleto + kit, como o `mk1` da Fase 2. O
   `mk35` do feature doc é o teste: publicar `MK3-A1` e confirmar que as peças `mk` não
   aparecem como opção.
2. Apagar `Part.slot` e o enum `Part.Slot`; apagar `Chassis.restricted_tags` e
   `disabled_slots` — o padrão do socket já faz o trabalho dos dois.
3. Apagar `BoneDef.hitbox` (§Decisões 1) e `BodyPart.Kind`, se nada mais os ler.
4. Atualizar o comentário de `combat/unit_stats.gd:3-4`, que ainda descreve a vida como
   "a soma das seis".
5. Marcar o [feature_anatomy.md](feature_anatomy.md) e o [feature_parts.md](feature_parts.md)
   como substituídos no modelo de dados, com um aviso no topo apontando para o
   [feature_montagem.md](feature_montagem.md).

**Verificação.** `grep -rn "Chassis\|SlotDef\|MountDef\|Part.Slot\|ArtLibrary" --include="*.gd" .`
não devolve nada fora de comentários históricos. Placar idêntico ao da Fase 4.

**Pronto quando.** O projeto abre limpo e os três kits funcionam.

---

## Fase 8 — `assets/` consolidado

**Objetivo.** Colapsar a separação de pastas que só existia porque o código tinha dois
conceitos. Depende do submódulo `assets/source`, então é commit separado lá dentro.

**Passos.**

1. Apagar os órfãos já mapeados: `characters/mk1/{left-arm,left-leg,right-leg,face,full}`
   e `sprites/` inteiro (o pipeline Aseprite morreu junto com o `ArtLibrary` na Fase 7).
2. Unificar `characters/<char_id>/<bone>` e `parts/<part_id>` num esquema só, agora que
   os dois são a mesma coisa: a arte de uma peça.
3. `actors/character_art.gd` passa a ter **um** caminho de resolução em vez de dois.

**Verificação.** `tools/verify_character_art.gd` e `tools/sprite_bench.gd` passam.

**Pronto quando.** Nenhuma referência a `sprites/` sobrou e o robô desenha igual.

---

## Relatório ao fim de cada fase

Responda nesta forma:

```
Fase N — <nome>

Placar (BOTBATTLE_SEED=1):
  <as três linhas>
  → idêntico à linha-base | MUDOU (esperado, Fase 3/4): <nova linha-base>

Neutralidade: <atributos resolvidos idênticos? soma de max_hp idêntica?>
Smoke test: <a linha "Fim da batalha">

Arquivos: criados <n>, editados <n>, apagados <n>
Removido: <as constantes/funções/campos que sumiram>

Fora do plano: <o que você encontrou e não consertou, ou "nada">
Decisões: <o que o plano não dizia e você teve que escolher, ou "nenhuma">
```

A linha **Decisões** é a mais importante: se o plano foi ambíguo em algum ponto, é ali
que isso aparece antes de virar dívida.
