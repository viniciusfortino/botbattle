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
| `capacity` 120 | ossos do esqueleto `mk` | carga é estrutura — é o que resolve o laço |
| `strength` 12 | braços de fábrica, 6 cada | perder um braço custa metade da força |
| `agility` 10 | pernas de fábrica, 5 cada | perder uma perna custa metade da agilidade |
| `defense` 4 | carcaça | blindagem é do que cobre |
| `energy` 18 | carcaça | o reator mora no tronco |

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
peças existentes. Criar `tools/migrate_montagem.gd`.

**Passos.**

1. **A forma.** `content/forms/humanoid.tres`: `bone_keys` na ordem de hoje
   (`head`, `torso`, `hip`, `arm_left`, `arm_right`, `leg_left`, `leg_right`), o mapa
   `parents` transcrito de `content/anatomy/humanoid.tres`, e a `AnimationLibrary` apontando
   para `content/anatomy/humanoid_animations.tres`.
2. **O esqueleto.** `content/skeletons/mk.tres`: um `BoneDef` por chave da forma, com a
   pose copiada de `humanoid.tres`, `capacity` distribuída nos `modifiers` somando **120**,
   e `resistance` valendo a **fração de osso** da tabela abaixo. Cada osso publica um
   `SocketDef` `main` com o padrão da sua classe (§Decisões 3).
3. **As peças de fábrica.** Seis `.tres` novos — `mk1_head`, `mk1_torso`, `mk1_hip`,
   `mk1_arm_left`, `mk1_arm_right`, `mk1_leg_left`, `mk1_leg_right` — com `fits` no padrão
   do osso que cobrem, os `modifiers` da tabela §Decisões 4, e `resistance` valendo a
   **fração de peça**:

   | Osso | `bone_resistance` hoje | Osso (30%) | Peça de fábrica (70%) |
   | --- | --- | --- | --- |
   | `head` | 14 | 4 | 10 |
   | `torso` | 34 | 10 | 24 |
   | `arm_left` / `arm_right` | 20 | 6 | 14 |
   | `leg_left` / `leg_right` | 18 | 5 | 13 |
   | `hip` | — (sem vida) | 8 | — |

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

5. **O kit.** `content/kits/mk1.tres`: aponta para o esqueleto `mk` e lista as sete peças
   de fábrica por caminho de socket (`"head/main"`, `"torso/main"`, `"arm_left/main"`…).

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
`combat/part_catalog.gd`. Criar `combat/kit_catalog.gd`. Migrar `content/units/*.tres`.

**Passos.**

1. `Loadout.slots` passa a ser chaveado por **caminho de socket**
   (`"arm_left/main/rail_1"`), e `Loadout.chassis` vira `Loadout.kit`. Migrar `r7.tres` e
   `sentinel_v9.tres` com um script em `tools/`.
2. `resolve()` percorre a árvore: ossos do esqueleto, depois cada peça montada em
   profundidade. A regra especial da `capacity` (`loadout.gd:236-242`) **é apagada** — a
   carga agora vem só dos ossos e não participa mais do laço.
3. `Body` monta as hitboxes em camadas: cada osso é uma hitbox, cada peça montada é uma
   hitbox filha. `BodyPart.adopt()` some — não existe mais peça que *vira* osso.
4. Implementar a blindagem e o estouro (feature §7): o dano para na peça de fora; se
   supera a vida da pilha inteira, a pilha cai.
5. `part_catalog.gd` passa a filtrar por `fits`/`standard` em vez de por `Part.Slot`.

**Invariantes.** `Part.slot`, `SlotDef` e `MountDef` **continuam existindo** — só deixam
de ser lidos. `Combatant` ainda usa `hp > 0`; a derrota funcional é a fase seguinte.

**Verificação.** A **neutralidade dos atributos**: o script da Fase 0 rodado de novo tem
que imprimir os mesmos atributos resolvidos com a montagem completa. A soma de `max_hp`
de todas as hitboxes também tem que bater.
**O placar muda aqui** — registre as três linhas novas como linha-base.

**Pronto quando.** Atributos idênticos, HP total idêntico, batalha termina, nova
linha-base registrada.

---

## Fase 4 — Derrota funcional

**Objetivo.** Trocar `hp > 0` por "não consegue mais lutar".

**Arquivos.** `combat/combatant.gd`, `combat/battle_manager.gd`.

**Passos.**

1. `is_alive()` passa a perguntar: existe alguma ação disponível que alcance o inimigo?
   `available_actions()` (`combatant.gd:66`) já dá a lista — falta o critério de alcance.
2. `Combatant.hp` / `max_hp` deixam de ser o critério de derrota. Manter as propriedades
   por enquanto (o HUD ainda lê) e anotar no relatório o que passou a ser decorativo.
3. Tratar o empate conforme o [feature_montagem.md](feature_montagem.md) §11.2 — **se a
   decisão ainda não tiver sido tomada, pare e pergunte**, não escolha sozinho.

**Verificação.** Smoke test termina. **O placar muda** — registre a nova linha-base.

**Pronto quando.** Nenhuma batalha entra em laço infinito nas 200 do simulador.

---

## Fase 5 — `RobotSprite` recursivo

**Objetivo.** A árvore de nós sai da árvore de montagem, em profundidade arbitrária.

**Arquivos.** `actors/robot_sprite.gd`, `actors/part_node.gd`.

**Passos.**

1. `_build()` percorre os ossos do esqueleto e, para cada socket ocupado, cria o nó da
   peça — e repete recursivamente nos sockets dela.
2. O caminho do nó passa a ser o caminho do socket, para as animações continuarem
   encontrando os alvos.
3. Resolver o espelhamento conforme o [feature_montagem.md](feature_montagem.md) §11.1 —
   **se a decisão ainda não tiver sido tomada, pare e pergunte.**

**Verificação.** `tools/verify_hangar_swap.gd` e `tools/verify_no_crop.gd` passam.
Placar idêntico ao da Fase 4.

**Pronto quando.** O robô desenha montado, e uma peça sobre peça aparece no lugar certo.

---

## Fase 6 — Hangar em profundidade

**Objetivo.** Deixar o jogador montar acessório sobre peça.

**Arquivos.** `scenes/hangar/hangar.gd`, `scenes/hangar/hangar.tscn`.

**Passos.**

1. A lista de encaixes passa a ser a árvore de sockets da montagem atual, não uma lista
   achatada — um socket que só existe porque uma peça está montada aparece e some com ela.
2. As opções de cada socket saem de `PartCatalog` filtrado por `standard`.
3. Tirar uma peça tem que **derrubar junto** o que estava montado nela; avisar o jogador,
   como `revalidate()` já faz com o que não cabe.

**Verificação.** `tools/capture_hangar.gd` gera a captura sem erro. Montar, desmontar e
remontar não deixa peça órfã em `loadout.slots`.

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
