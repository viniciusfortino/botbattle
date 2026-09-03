# Plano de execução: anatomia e atributos

Plano operacional para implementar o [feature_anatomy.md](feature_anatomy.md). Cada fase
é uma tarefa fechada, com arquivos nomeados, invariantes explícitos e um comando que
prova que ela terminou.

**Leia o [feature_anatomy.md](feature_anatomy.md) antes de começar qualquer fase.** Este
documento diz *como fazer*; aquele diz *por quê*, e é ele que resolve as dúvidas de
desenho que aparecerem no caminho.

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
7. **A ordem de `body.parts` é sagrada** (ver "Determinismo" abaixo).

### Pré-requisito

A árvore de trabalho tem alterações pendentes em `combat/`, `parts/` e `units/`. Elas
precisam estar commitadas ou revertidas antes da Fase 1 — este plano assume um `git
status` limpo como ponto de partida.

### As duas verificações

**Simulador** — prova que os números não andaram:

```
BOTBATTLE_SEED=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/simulate.gd
```

**Smoke test** — prova que a batalha inteira ainda termina:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/smoke_test.gd 2>&1 | grep "Fim da batalha"
```

Em headless as capturas de tela falham com `Cannot call method 'save_png' on a null
value` — **isso é esperado e não é falha**. O que importa é a linha `### Fim da batalha`
aparecer. Não confie no código de saída depois de um pipe.

### Determinismo

O simulador chama `randomize()` (`tools/simulate.gd:16`), então o placar varia entre
execuções. A Fase 0 troca isso por uma semente opcional, e a partir dali **o placar com
`BOTBATTLE_SEED=1` tem que ser idêntico caractere a caractere antes e depois de cada
fase de refatoração.**

Isso só funciona se a **ordem do array `body.parts` não mudar**, porque
`Body.random_target()` percorre esse array para gastar o sorteio. A ordem de hoje é:

```
head, torso, arm_left, arm_right, leg_left, leg_right,   ← as estruturais, na ordem do FRAME
part:head_top, part:back_1, part:back_2,                 ← as montadas, na ordem de SLOT_KEYS
part:chest_1, part:chest_2, part:arm_left, part:arm_right
```

Qualquer fase que reconstrua o `Body` tem que reproduzir essa ordem exata. Se o placar
mudar, **é bug, não balanceamento** — encontre a diferença de ordem antes de seguir.

### Quando o placar mudar

Pare. Não ajuste números para "consertar". Compare `body.parts` antes e depois com um
script descartável que imprima `key` e `max_hp` na ordem, e ache a divergência.

---

## Fase 0 — Semente para o simulador

**Objetivo.** Tornar o simulador determinístico sob demanda, para que todas as fases
seguintes tenham uma verificação de regressão real.

**Arquivo.** `tools/simulate.gd`

**Passos.**

1. Trocar `randomize()` (linha 16) por:

```gdscript
	# Com BOTBATTLE_SEED definido o placar é reproduzível, o que transforma este
	# simulador em teste de regressão: refatoração que muda o resultado é bug.
	var seed_value := OS.get_environment("BOTBATTLE_SEED")
	if seed_value.is_empty():
		randomize()
	else:
		seed(int(seed_value))
```

2. Acrescentar a variante com semente ao comentário de uso no topo do arquivo.

**Verificação.**

```
BOTBATTLE_SEED=1 ... -s tools/simulate.gd   # rode duas vezes
```

**Pronto quando.** As duas execuções com semente imprimem exatamente as mesmas três
linhas. Sem a variável de ambiente, o placar continua variando.

**Registre no relatório** as três linhas do placar com `BOTBATTLE_SEED=1` — é a
**linha-base** contra a qual todas as fases seguintes são comparadas.

---

## Fase 1 — `Condition` unificado

**Objetivo.** Uma única definição dos limiares de dano, hoje repetida em dois arquivos e
divergente num terceiro documento.

**Arquivos.** `combat/body_part.gd`, `actors/chassis_art.gd`, `ui/hitbox_debug_panel.gd`

**Passos.**

1. Em `combat/body_part.gd`, acrescentar (a implementação exata está no
   [feature_anatomy.md](feature_anatomy.md) §6.4):
   - `enum Condition { INTACT, DAMAGED, CRITICAL, DESTROYED }`
   - `const DAMAGED_AT := 0.6` e `const CRITICAL_AT := 0.3`
   - `func condition() -> Condition`
   - `static func condition_for(value: float) -> Condition`
2. Em `actors/chassis_art.gd`: apagar `DAMAGED_AT` e `CRITICAL_AT` (linhas 17-18); trocar
   a assinatura de `part_texture(chassis_id, part, ratio: float)` para receber
   `cond: BodyPart.Condition`; o mapa de sufixos vira
   `DAMAGED → "_damaged"`, `CRITICAL → "_critical"`, os outros → `""`.
3. Em `actors/robot_sprite.gd`: as duas chamadas (linhas 124-125) passam
   `BodyPart.condition_for(_torso_ratio)` e `BodyPart.condition_for(_head_ratio)`.
4. Em `ui/hitbox_debug_panel.gd:121-123`: trocar os dois `if part.ratio() <= …` por um
   `match part.condition()`.

**Invariantes.** Os limiares continuam 0,6 e 0,3. Nenhum comportamento visual muda.

**Verificação.** Simulador com semente = linha-base. Smoke test completa.

**Pronto quando.** `grep -rn "0\.6\|0\.3" actors/chassis_art.gd ui/hitbox_debug_panel.gd`
não acha mais limiar de dano nenhum.

---

## Fase 2 — `StatSchema`: os atributos declarados uma vez

**Objetivo.** Tirar o vocabulário de atributos de dentro de `Chassis`, `Part`,
`resolve()` e dos rótulos do hangar.

**Arquivos.** Criar `combat/stat_def.gd`, `combat/stat_schema.gd`, `stats/default.tres`,
`tools/migrate_stats.gd`. Editar `combat/chassis.gd`, `combat/part.gd`,
`combat/loadout.gd`, `combat/unit_stats.gd`, `scenes/hangar/hangar.gd`. Migrar os 11
`.tres` de `parts/` e os 3 de chassi.

Esta fase migra recursos, então ela se faz em **quatro passos separados** — nunca apague
um campo antigo antes de o novo estar gravado nos `.tres`.

**Passo 2a — campos novos ao lado dos velhos.**

1. Criar `StatDef` e `StatSchema` conforme o [feature_anatomy.md](feature_anatomy.md)
   §4.1.
2. Criar `stats/default.tres` com os cinco `StatDef` da tabela do §4.1, **nesta ordem**:
   `strength`, `agility`, `defense`, `energy`, `capacity`.
3. Em `Chassis`: acrescentar `schema: StatSchema` e
   `base_stats: Dictionary[String, int]`. **Manter** `strength`, `agility`, `defense`,
   `energy`, `capacity` por enquanto.
4. Em `Part`: acrescentar `modifiers: Dictionary[String, int]` e
   `scalers: Dictionary[String, float]`. **Manter** os quatro atributos antigos.

**Passo 2b — script de migração.** Criar `tools/migrate_stats.gd` (um `SceneTree` como
os outros de `tools/`) que, para cada id de `PartCatalog.IDS` e para
`chassis/mk1.tres`, `assets/chassis/mk2_goliath.tres` e
`assets/chassis/mk3_strider.tres`:

- carrega o recurso;
- copia os campos antigos para o dicionário novo, **omitindo os zeros** (uma peça com
  `strength = 0` não deve gravar `{"strength": 0}`);
- aponta `schema` para `res://stats/default.tres` nos chassis;
- grava com `ResourceSaver.save(recurso, caminho)`.

Deixar o Godot escrever o `.tres` evita errar a sintaxe de dicionário tipado. Rodar uma
vez, conferir o diff dos 14 arquivos, e **manter o script no repositório** — ele
documenta a migração.

**Passo 2c — passar a ler os campos novos.**

1. `Loadout.resolve()` vira o laço genérico do §4.3. A ordem — soma tudo, multiplica
   depois, piso por último — é a mesma de hoje (`loadout.gd:229-232`).
2. Acrescentar `Loadout.stat(key: String) -> int` e `Loadout.schema() -> StatSchema`
   (com `res://stats/default.tres` como fallback quando o chassi não aponta um).
3. `load_penalty()` passa a ser o multiplicador inicial de `agility`, como no §4.3.
4. `total_weight()`, `load_ratio()` e `is_valid()` **não mudam** — `weight` continua
   campo nomeado.
5. `hangar.gd:53` (`stats_label`) e `:198-206` (`_delta_text`) viram laços sobre
   `schema().stats`, usando `abbreviation` como rótulo. A linha `VIDA %d` sai de
   `body.max_total_hp()` e continua fora do laço; `PESO` continua vindo de
   `total_weight()`.

**Passo 2d — apagar o que sobrou.**

1. De `Chassis`: `strength`, `agility`, `defense`, `energy`, `capacity`.
   `capacity` passa a ser lido por `loadout.stat("capacity")` — ver o invariante abaixo.
2. De `Part`: `strength`, `agility`, `defense`, `energy`.
3. De `UnitStats`: `head_hp`, `torso_hp`, `arm_hp`, `leg_hp`, `hp_for()` e `total_hp()`
   — código morto, sem nenhum leitor (confirme com um `grep` antes de apagar).
4. Rodar `tools/migrate_stats.gd` de novo: ele tem que ser idempotente e não gerar diff.

**Invariantes.**

- `capacity` se resolve **sem os `scalers` e sem excluir peças perdidas**, uma vez, antes
  da penalidade de carga — senão a carga passa a depender das peças que ela limita
  (questão 3 do §10 do feature_anatomy).
- `weight` e `resistance` continuam campos nomeados em `Part`. **Não** os mova para
  `modifiers`.
- Pisos preservados: `strength` 1, `agility` 1, `defense` 0, `energy` 0.
- O `.tres` de uma peça sem modificador nenhum grava um dicionário vazio, não some.

**Verificação.** Simulador com semente = linha-base, **caractere a caractere**. Esta é a
fase com maior risco de mexer nos números; se o placar andar, o erro está na ordem
soma → multiplica → piso.

**Pronto quando.** `grep -rn "\.strength\|\.agility\|\.energy" --include=*.gd combat/
scenes/` não acha mais acesso a campo de atributo em `Part` nem em `Chassis`. O hangar
mostra os mesmos cinco números de antes.

---

## Fase 3 — Os recursos de anatomia

**Objetivo.** Criar a declaração do esqueleto, sem nenhum consumidor ainda. Fase de puro
acréscimo: nada existente muda.

**Arquivos.** Criar `combat/bone_def.gd`, `combat/mount_def.gd`, `combat/slot_def.gd`,
`combat/anatomy.gd`, `anatomy/humanoid.tres`.

**Passos.**

1. Criar as quatro classes exatamente como o [feature_anatomy.md](feature_anatomy.md)
   §3.1-3.4 as define, com todos os campos, inclusive os de pose que ninguém lê ainda.
2. Criar `anatomy/humanoid.tres` **transcrevendo o que existe hoje**:
   - **Ossos**, nesta ordem: `head`, `torso`, `arm_left`, `arm_right`, `leg_left`,
     `leg_right` — copiando `kind`, nomes, `hit_weight`, `damage_multiplier` e
     `absorb_priority` de `Body.FRAME` (`combat/body.gd:11-24`), e `resistance` dos
     valores de fábrica do MK-I (14 / 34 / 20 / 20 / 18 / 18).
   - Mais o osso **`hip`** com `hitbox = false`, `parent` vazio, que ninguém consome
     ainda. Os demais ossos ficam com `parent` **vazio** nesta fase — a hierarquia entra
     na Fase 7, junto com a árvore de nós que a usa.
   - **Encaixes**, na ordem de `Loadout.SLOT_KEYS`: `head_top`, `back_1`, `back_2`,
     `chest_1`, `chest_2`, `arm_left`, `arm_right`, `leg_left`, `leg_right`, com
     `host_bone` vindo de `Body.ATTACHMENT_PARENT` (`body.gd:27-32`) e `label` de
     `Loadout.slot_label` (`loadout.gd:75-85`).
   - **Modos**: um `MountDef` por encaixe, exceto os braços (três: `ARM_MOUNT` "braço de
     fábrica", `FOREARM` "antebraço trocado", `ARM_FULL` "braço completo"
     `replaces_host = true`) e as pernas (um: `LEG_FULL` "perna completa"
     `replaces_host = true`).
3. Implementar os métodos de consulta de `Anatomy` (§3.4). `node_path()` e
   `bones_in_order()` podem ficar para a Fase 7, mas escreva-os agora se for direto.

**Invariantes.** Nenhum arquivo existente é editado nesta fase. A ordem de `bones` e de
`slots` reproduz a ordem de hoje — é dela que sai a ordem de `body.parts` na Fase 4.

**Verificação.** Simulador e smoke test continuam iguais (nada os toca). Escreva um
script descartável que carregue `anatomy/humanoid.tres` e imprima
`hitbox_key("arm_left", peça)` para uma peça `ARM_MOUNT` e uma `ARM_FULL`: têm que sair
`part:arm_left` e `arm_left`.

**Pronto quando.** O `.tres` carrega sem erro e os métodos de consulta respondem.

---

## Fase 4 — `Body` e `Combatant` leem da anatomia

**Objetivo.** Apagar as cópias da anatomia em `body.gd` e `combatant.gd`.

**Arquivos.** `combat/body.gd`, `combat/body_part.gd`, `combat/combatant.gd`,
`combat/chassis.gd`, `combat/loadout.gd`, `chassis/mk1.tres` e os dois de
`assets/chassis/`.

**Passos.**

1. Em `Chassis`: acrescentar `anatomy: Anatomy` e
   `bone_resistance: Dictionary[String, int]`; apagar `head_resistance`,
   `torso_resistance`, `arm_resistance`, `leg_resistance`. Migrar os três `.tres` (o
   MK-I grava `{"head": 14, "torso": 34, "arm_left": 20, "arm_right": 20,
   "leg_left": 18, "leg_right": 18}`; os outros dois não gravam nada e herdam o
   `BoneDef.resistance`). Estenda `tools/migrate_stats.gd` ou faça à mão — são três
   arquivos.
2. Em `BodyPart`: acrescentar `from_bone(bone, resistance)`, `from_attachment(def, part,
   parent, name)` e `adopt(part)` como construtores nomeados. O `_init(config)` atual
   pode continuar existindo por baixo.
3. Em `Body`: reescrever `from_loadout()` conforme o §6.3. Apagar `FRAME`,
   `ATTACHMENT_PARENT`, `_frame_hp`, `_structural_replacement`, `_is_structural_slot`.
   **Todo o resto de `Body` fica intocado.**
4. Em `Loadout`: acrescentar `anatomy()`, `resistance_for(bone)`, `part_replacing(bone_key)`
   e `replaces_host(slot_key)`, todos delegando para `Anatomy`.
5. Em `Combatant`: apagar `_hitbox_key_for_slot` (linha 277) e chamar
   `anatomy.hitbox_key(slot_key, piece)`.
6. Em `RobotSprite._mounted` (linha 172): trocar a tentativa dupla `"part:%s"` → `"%s"`
   por uma chamada a `hitbox_key()`.

**Invariantes.**

- A **ordem de `body.parts`** tem que ser exatamente a de hoje (ver "Determinismo").
  Ossos primeiro na ordem de `bones`, depois os encaixes na ordem de `slots`.
- O osso `hip` tem `hitbox = false` e **não entra** em `body.parts`.
- `unused_names` / o desempate de nome duplicado de `body.gd:67-72` continua igual.

**Verificação.** Simulador com semente = linha-base. Se divergir, imprima `key` e
`max_hp` de `body.parts` na ordem, antes e depois, e compare.

**Pronto quando.** `grep -n "FRAME\|ATTACHMENT_PARENT" combat/body.gd` não acha nada, e o
painel de hitboxes em jogo lista as mesmas linhas de antes.

---

## Fase 5 — `Loadout` por dicionário

**Objetivo.** Acabar com os nove `@export` nomeados, os quatro `match` e o `ArmMode`.

**Arquivos.** `combat/loadout.gd`, `globals/player_loadout.gd`, `scenes/hangar/hangar.gd`,
`units/r7.tres`, `units/sentinel_v9.tres`, `tools/migrate_loadouts.gd` (novo).

**Passos.**

1. Em `Loadout`: acrescentar `slots: Dictionary[String, Part]` **ao lado** dos nove
   campos antigos.
2. `tools/migrate_loadouts.gd`: carrega `units/r7.tres` e `units/sentinel_v9.tres`,
   preenche `slots` a partir dos campos antigos, grava com `ResourceSaver`.
3. Apagar os nove `@export`, `SLOT_KEYS`, `enum ArmMode`, `arm_left_mode`,
   `arm_right_mode`, `set_arm_mode`, `arm_mode`, `arm_mode_label`, `_arm_slot`,
   `accepted_slot`, e o `slot_label` estático. Reescrever `get_part`, `set_part`,
   `options_for`, `equip` e `active_parts` sobre o dicionário e a anatomia (tabela do
   §6.2).
4. Em `player_loadout.gd`: `Loadout.SLOT_KEYS` (linhas 49 e 72) vira
   `loadout.slot_keys()`; tirar `arm_left_mode`/`arm_right_mode` de `_to_dict` e
   `_from_dict`. **Um save antigo com essas chaves tem que continuar carregando** — a
   chave extra é ignorada.
5. Em `hangar.gd`: `Loadout.SLOT_KEYS` (linha 123) vira `loadout.slot_keys()`;
   `Loadout.slot_label` (123, 144) vira o método de instância;
   `loadout.arm_mode_label(key)` (133) vira o `label` do `MountDef`; e **apagar o
   salva-e-restaura do modo** em `_delta_text` (linhas 187 e 192-195) — ele existia só
   por causa do campo que sumiu.
6. Em `combatant.gd:68` e `body.gd`: `Loadout.SLOT_KEYS` vira `loadout.slot_keys()`.

**Invariantes.**

- `slot_keys()` respeita a ordem da anatomia **menos** `chassis.disabled_slots`.
- Encaixe vazio não aparece no dicionário; `get_part` devolve `null`.
- Um save gravado antes desta fase carrega sem aviso e produz a mesma montagem.

**Verificação.** Simulador com semente = linha-base. Smoke test completa. Abra o hangar,
troque uma peça de braço nos três modos e confira que o rótulo do modo continua certo.

**Pronto quando.** `grep -rn "SLOT_KEYS\|ArmMode\|arm_left_mode" --include=*.gd .` não
acha nada fora de comentários.

---

## Fase 6 — `Part`: ações em lista, arte por id

**Objetivo.** Deixar de inferir a aparência e a ação de uma peça a partir dos números
dela.

**Arquivos.** `combat/part.gd`, `combat/combatant.gd`, `actors/chassis_art.gd` →
`actors/art_library.gd`, `actors/robot_sprite.gd`, `ui/hitbox_debug_panel.gd`,
`scenes/hangar/hangar.gd`, os 11 `.tres` de `parts/`.

**Passos.**

1. Em `Part`: `grants_action: String` → `grants_actions: Array[String]`; acrescentar
   `art_id: String` e `body_animation: String` (este último sem leitor até a Fase 8).
2. Migrar os 11 `.tres` (script ou à mão): a string vira lista de um elemento, ou lista
   vazia.
3. Atualizar os leitores: `combatant.gd:70,73,77,79` (o laço de `available_actions`
   passa a iterar a lista; o desempate por força continua), `hangar.gd:205-206`,
   `hitbox_debug_panel.gd:112,114`.
4. Renomear `ChassisArt` para `ArtLibrary` (arquivo e `class_name`), com os dois métodos
   do §6.6: `bone_texture(chassis_id, bone, cond)` e `part_texture(art_id, cond)`. A
   mecânica interna — cache, cascata de estado, rejeição de arquivo sem transparência
   real — **fica exatamente como está**.
5. Em `RobotSprite`: onde a peça tem `art_id` e existe textura, desenhar a textura;
   senão, o procedural de hoje. Apagar as adivinhações: `:182`
   (`grants_action.is_empty()`), `:201` (`piece.agility > 0`), `:215`
   (`piece.energy > 0`), `:243` (comparação com `"plasma"`/`"laser"`).

**Invariantes.** Nenhuma peça tem `art_id` ainda, então **o visual não muda nesta fase** —
tudo cai no procedural. A remoção das adivinhações significa que cada tipo de encaixe
passa a ter **uma** silhueta genérica; escolha a que hoje é o caso mais comum e anote no
relatório qual silhueta cada encaixe perdeu.

**Verificação.** Simulador com semente = linha-base. Smoke test completa. Abra o hangar e
confirme que o robô ainda desenha.

**Pronto quando.** `grep -rn "grants_action\b" --include=*.gd .` não acha nada.

---

## Fase 7 — `RobotSprite` gerado da anatomia

**Objetivo.** Trocar o `_draw()` monolítico por uma árvore de nós, que é o substrato que
as animações exigem. É a fase mais longa; leia o §5 do
[feature_anatomy.md](feature_anatomy.md) inteiro antes de começar.

**Arquivos.** `actors/robot_sprite.gd`, `actors/part_node.gd` + `actors/part_node.tscn`
(novos), `anatomy/humanoid.tres`, `combat/combatant.gd`.

**Passos.**

1. Preencher em `anatomy/humanoid.tres` os campos de pose que a Fase 3 deixou vazios:
   `parent` (a hierarquia do §5.1), `rest_position` **relativa ao pai**,
   `rest_rotation`, `pivot`, `z_index`, `z_index_back`. Os valores saem das constantes
   do `_draw()` atual (`side * 142.0`, `-258.0` etc.), convertidas de absolutas para
   relativas ao pai.
2. Criar `PartNode` conforme o [feature_parts.md](feature_parts.md) §5: sprite, material,
   âncora de VFX. Ele expõe `set_condition(cond)` e desenha o fallback procedural quando
   não tem textura.
3. `RobotSprite` monta a árvore no `_ready()` a partir da anatomia, um nó por osso e por
   encaixe, nomeados pela chave. Encaixe com `replaces_host` põe a arte **no nó do osso**.
4. `back_view` passa a ser: espelho da raiz em X, arte `_back`, e `z_index_back`. A
   inversão manual `left_side` (`robot_sprite.gd:113`) some.
5. A respiração (`breath`, hoje somada à mão em cada coordenada) vira deslocamento do nó
   `hip`. A escora de perna única continua na **raiz** (`combatant.gd:262-269`), acima da
   pose.

**Invariantes.** O robô tem que ficar **visualmente equivalente** ao de hoje —
reconhecível, mesmas proporções, mesma ordem de profundidade. Diferenças de alguns pixels
são aceitáveis; peça sumida ou trocada de lugar não é.

**Verificação.** Simulador com semente = linha-base (o visual não afeta o modelo, então
qualquer mudança aqui é bug em outro lugar). Rode o smoke test **com display** para
gerar os PNGs em `.captures/` e compare com capturas feitas antes da fase:

```
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/smoke_test.gd
```

**Pronto quando.** As capturas antes/depois mostram o mesmo robô, e o `_draw()` do
`RobotSprite` está vazio (o desenho procedural mudou de endereço, para dentro do
`PartNode` — não foi apagado).

---

## Fase 8 — Animações

**Objetivo.** Uma ação poder mover o corpo inteiro.

**Arquivos.** `anatomy/humanoid.tres`, `actors/robot_sprite.gd`, `combat/actions.gd`,
`combat/combatant.gd`, `combat/battle_manager.gd`.

**Passos.**

1. `Anatomy.animations: AnimationLibrary`, com as animações escritas contra os caminhos
   de nó (`hip`, `hip/torso`, …). Comece com duas: `idle` (a respiração em loop) e
   `recoil_heavy`.
2. `RobotSprite` ganha um `AnimationPlayer` que carrega a biblioteca da anatomia e toca
   `idle` por padrão.
3. `Actions.LIST` ganha `body_animation` por ação; `Part.body_animation` (já criado na
   Fase 6) sobrescreve quando aquela peça é a origem.
4. `BattleManager` dispara a animação de corpo junto com o `lunge`/`brace` que já existe,
   e espera pelo fim antes de aplicar o dano.

**Invariantes.** Uma ação sem `body_animation` se comporta exatamente como hoje. Pose,
escora e respiração compõem sem se cancelar (§5.3).

**Verificação.** Simulador com semente = linha-base — as animações não podem alterar o
modelo. Smoke test com display, olhando as capturas.

**Pronto quando.** Uma arma configurada com `body_animation` move o corpo ao disparar, e
uma sem ela não muda nada.

---

## Fase 9 — `ChassisCatalog`

**Objetivo.** Trazer o MK-II e o MK-III de volta ao jogo.

**Arquivos.** `combat/chassis_catalog.gd` (novo), `assets/chassis/*.tres` →
`chassis/`, `scenes/hangar/hangar.gd`.

**Passos.**

1. Mover `assets/chassis/mk2_goliath.tres` e `mk3_strider.tres` para `chassis/`,
   corrigindo referências.
2. Criar `ChassisCatalog` no mesmo molde de `PartCatalog` (`combat/part_catalog.gd`):
   lista explícita de ids, cache estático, e o mesmo comentário explicando por que a
   lista não é varredura de diretório.
3. No hangar, uma aba ou seção para escolher o exoesqueleto. Trocar de chassi
   **revalida a montagem**: peça em encaixe que o novo chassi não tem, ou com tag
   restrita, é desencaixada com aviso.

**Invariantes.** O MK-I continua sendo o padrão. Um save que aponta para um chassi que
sumiu cai no MK-I com `push_warning`, como já acontece com peça removida.

**Verificação.** Simulador e smoke test. No hangar, trocar para o MK-III Strider e
confirmar que `back_2` e `chest_2` somem da lista e que a peça que estava lá foi
desencaixada.

**Pronto quando.** Os três exoesqueletos são escolhíveis e nenhum `.tres` de chassi vive
fora de `chassis/`.

---

## Relatório ao fim de cada fase

Responda nesta forma:

```
Fase N — <nome>

Placar (BOTBATTLE_SEED=1):
  <as três linhas>
  → idêntico à linha-base | DIVERGIU: <o quê>

Smoke test: <a linha "Fim da batalha">

Arquivos: criados <n>, editados <n>, apagados <n>
Removido: <as constantes/funções/campos que sumiram>

Fora do plano: <o que você encontrou e não consertou, ou "nada">
Decisões: <o que o plano não dizia e você teve que escolher, ou "nenhuma">
```

A linha **Decisões** é a mais importante: se o plano foi ambíguo em algum ponto, é ali
que isso aparece antes de virar dívida.
