# Feature: Anatomia e atributos — a ficha do robô declarada uma vez

Documento de desenho. Descreve como tirar do código duas coisas que hoje estão escritas
à mão em vários arquivos — **a anatomia** (que ossos e encaixes o robô tem) e **os
atributos** (força, agilidade, defesa…) — e colocá-las em recursos editáveis, para que
acrescentar um encaixe, um osso, um modo de montagem ou um atributo novo deixe de ser
refactor e passe a ser um `.tres`.

Este documento é o par estrutural do [feature_parts.md](feature_parts.md): lá está como
a peça *aparece*; aqui está o que a peça *é*, onde ela se encaixa e o que ela move.

---

## 1. O problema

O corpo do robô funciona. O que não escala é que a mesma informação está declarada em
vários lugares que não se conhecem.

**A anatomia, cinco vezes:**

| Onde | O que declara |
| --- | --- |
| `combat/loadout.gd:16,29,47,75,141` | `SLOT_KEYS`, nove `@export`, `get/set_part`, `slot_label`, `accepted_slot` |
| `combat/body.gd:11,27,259` | `FRAME` (as seis partes estruturais), `ATTACHMENT_PARENT`, `_frame_hp` |
| `combat/chassis.gd:26-29` | `head_resistance`, `torso_resistance`, `arm_resistance`, `leg_resistance` |
| `combat/combatant.gd:277` | `_hitbox_key_for_slot` — o mapa encaixe → hitbox |
| `actors/robot_sprite.gd:178-217` | `_draw_head_mount`, `_draw_back_mounts`, `_draw_chest_mounts` |

Uma sexta cópia está em `combat/unit_stats.gd:11-16,33-47` — `head_hp`, `torso_hp`,
`arm_hp`, `leg_hp`, `hp_for()` e `total_hp()`, sobras de antes de o `Body` existir, hoje
sem nenhum leitor. E o [feature_parts.md](feature_parts.md) §5 propõe uma sétima: a
árvore de nós escrita à mão num `.tscn`, com `Back1`, `Back2`, `ChestLayer`,
`ShoulderLeft` fixos.

**Os atributos, quatro vezes:**

| Onde | O que declara |
| --- | --- |
| `combat/chassis.gd:12-15` | `strength`, `agility`, `defense`, `energy` como campos base |
| `combat/part.gd:29-39` | os mesmos quatro como modificadores, mais `resistance` e `weight` |
| `combat/loadout.gd:220-232` | a soma, a penalidade de carga, os pisos e o mapa para `UnitStats` |
| `scenes/hangar/hangar.gd:53,198-206` | os rótulos `"FOR %d AGI %d DEF %d…"` e a lista do delta |

Acrescentar um encaixe de cintura exige editar cinco arquivos. Acrescentar um atributo
de refrigeração exige editar quatro. Errar em qualquer um produz bug silencioso — o
encaixe existe no hangar mas não vira hitbox, ou o atributo soma mas não aparece.

Três sintomas do mesmo problema, todos concretos:

**A regra "a peça substitui o osso inteiro" mora em três lugares.** `body.gd:268`
(`_structural_replacement`), `body.gd:283` (`_is_structural_slot`) e `combatant.gd:277`
respondem à mesma pergunta com três implementações. E quem precisa da chave da hitbox
sem ter acesso ao `Combatant` tenta as duas por força bruta — `robot_sprite.gd:172`
testa `"part:<key>"` e cai para `"key"`.

**O visual adivinha o que a peça é lendo os atributos dela.** `robot_sprite.gd:182`
decide entre sensor e canhão por `grants_action.is_empty()` — são duas ramificações e só
duas, então **um lança-chamas de cabeça hoje desenharia como o canhão laser**, e um
lança-foguetes também. `:201` decide "isto é um turbo" por `piece.agility > 0`; `:215`
decide "célula de energia" por `piece.energy > 0`; `:243` compara `grants_action` com
exatamente `"plasma"` e `"laser"`, então uma arma nova de braço desenha como espada.

**O estado de dano tem três definições.** `chassis_art.gd:17-18` usa 0,6/0,3;
`hitbox_debug_panel.gd:121-123` repete 0,6/0,3 à mão; o `feature_parts.md:250` propõe
0,5/0,2 para os VFX. Arte, HUD e partículas vão discordar sobre o que é "muito
danificado".

---

## 2. A ideia

Dois recursos novos passam a ser as declarações únicas. Todo o resto lê deles.

```
Anatomy  ──┬──▶  Body        (quais hitboxes existem, e de quem cada uma pendura)
           ├──▶  Loadout     (quais encaixes existem, e o que cada um aceita)
           ├──▶  Combatant   (qual hitbox uma ação exige)
           └──▶  RobotSprite (a árvore de nós, as poses e as animações)

StatSchema ─┬─▶  Chassis     (o valor base de cada atributo)
            ├─▶  Part        (quanto a peça soma ou multiplica)
            ├─▶  Loadout     (como somar e onde isso desemboca em UnitStats)
            └─▶  Hangar      (rótulos, ordem e o delta de cada troca)
```

A divisão de responsabilidade fica:

| Recurso | Responde | Exemplo |
| --- | --- | --- |
| `Anatomy` | **Que forma** o robô tem | humanoide: quadril, tórax, cabeça, dois braços, duas pernas, nove encaixes |
| `StatSchema` | **Quais atributos** existem no jogo | força, agilidade, defesa, energia, carga |
| `Chassis` | **Quão forte** essa forma é | MK-I: força 12, carga 120, tórax aguenta 34 |
| `Part` | **O que** entra num encaixe | canhão de plasma: +6 força, 16 de vida, concede `plasma` |
| `Loadout` | **O que está** encaixado agora | o R-7 com plasma no braço esquerdo |

Hoje o `Chassis` responde às três primeiras perguntas ao mesmo tempo. É por isso que as
resistências de fábrica são quatro campos fixos (porque os ossos são quatro tipos fixos)
e que os atributos são quatro campos fixos (porque o `resolve()` soma quatro variáveis
locais escritas à mão).

---

## 3. A anatomia

### 3.1 `BoneDef` — um osso do esqueleto

```gdscript
## Um pedaço estrutural do corpo: existe em todo robô que use esta anatomia, mesmo
## sem nenhuma peça montada.
class_name BoneDef
extends Resource

## Identidade dentro do corpo: "hip", "torso", "arm_left"…
@export var key: String = ""
@export var kind: BodyPart.Kind = BodyPart.Kind.TORSO
## Nome curto, para a UI ("Braço dir.").
@export var display_name: String = ""
## Nome com artigo, para o log ("o braço direito").
@export var narrative_name: String = ""
## O osso que sustenta este: pai de transformação **e** de cascata de dano.
## Vazio = raiz.
@export var parent: String = ""

@export_group("Hitbox")
## Falso = osso só de transformação, sem vida e sem aparecer no painel de hitboxes.
@export var hitbox: bool = true
## Vida de fábrica. O chassi pode sobrescrever por `bone_resistance`.
@export var resistance: int = 20
## Área aparente — peso no sorteio de acerto.
@export var hit_weight: float = 1.0
## Quanto este osso amplifica o dano que recebe.
@export var damage_multiplier: float = 1.0
## Ordem em que recebe o excedente de um golpe em outra hitbox (menor = antes).
@export var absorb_priority: int = 9

@export_group("Pose")
## Posição de repouso **relativa ao osso pai**.
@export var rest_position: Vector2 = Vector2.ZERO
@export var rest_rotation: float = 0.0
## O ponto em torno do qual a arte gira (o ombro, o quadril).
@export var pivot: Vector2 = Vector2.ZERO
## Altura de desenho em unidades de jogo; a largura sai da proporção da imagem.
@export var art_height: float = 100.0
@export var z_index: int = 0
## Profundidade na vista de costas, quando ela difere. Vale `z_index` se não definida.
@export var z_index_back: int = 0
```

Duas novidades em relação ao `FRAME` de hoje:

**`parent` é pai de transformação.** As seis partes estruturais atuais não têm hierarquia
entre si — só as peças montadas penduram em algo, via `ATTACHMENT_PARENT`. Com `parent`,
mover o quadril move o tórax, que move os braços, a cabeça e tudo que estiver pendurado
neles. É isso que torna "o robô se abaixa ao disparar" uma track só, em vez de doze
âncoras movidas em sincronia. A mesma hierarquia serve à cascata de destruição que o
`Body._collapse_dependents` já executa: deixar `parent` vazio em tudo preserva
exatamente o comportamento atual.

**`hitbox: bool` é consequência disso.** Para o robô se abaixar você quer um osso
**quadril** na raiz, com as pernas e o tórax pendurados nele — e quadril não é uma
hitbox (o `FRAME` tem seis partes e nenhuma é quadril). Um osso pode existir para
transformar sem ter vida própria.

### 3.2 `MountDef` — um modo de montagem

```gdscript
## Uma forma de ocupar um encaixe. É o que hoje o `Loadout.ArmMode` descreve para os
## braços — generalizado, e derivado da peça em vez de guardado à parte.
class_name MountDef
extends Resource

## O tipo de peça que entra por este modo.
@export var accepts: Part.Slot = Part.Slot.BACK
## Como o hangar chama este modo: "braço de fábrica", "antebraço trocado".
@export var label: String = ""
## A peça vira a própria hitbox do osso hospedeiro, em vez de pendurar nele.
@export var replaces_host: bool = false
```

### 3.3 `SlotDef` — um encaixe

```gdscript
## Um encaixe do exoesqueleto: onde uma peça entra, e o que ela vira quando entra.
class_name SlotDef
extends Resource

## Identidade do encaixe: "head_top", "back_1", "arm_left"…
@export var key: String = ""
## Rótulo para o hangar: "Topo da cabeça".
@export var label: String = ""
## O osso que sustenta a peça — ou que ela substitui, conforme o modo.
@export var host_bone: String = ""
## Os modos de montagem deste encaixe, na ordem em que o hangar os lista.
@export var mounts: Array[MountDef] = []
## Ordem em que a peça montada recebe o excedente de um golpe.
@export var attachment_absorb_priority: int = 6

@export_group("Pose")
@export var rest_position: Vector2 = Vector2.ZERO
@export var rest_rotation: float = 0.0
@export var art_height: float = 80.0
@export var z_index: int = 0
@export var z_index_back: int = 0
```

### 3.4 `Anatomy` — o esqueleto inteiro

```gdscript
## A forma de um robô: que ossos ele tem, onde as peças entram e como ele se move.
##
## É a declaração única do esqueleto — `Body`, `Loadout`, `Combatant` e `RobotSprite`
## leem daqui em vez de cada um manter a sua cópia.
class_name Anatomy
extends Resource

@export var id: String = "humanoid"
@export var display_name: String = "Humanoide"
@export var bones: Array[BoneDef] = []
## Na ordem em que o hangar lista os encaixes.
@export var slots: Array[SlotDef] = []
## Animações de corpo, escritas contra os caminhos de nó que saem das chaves dos ossos.
@export var animations: AnimationLibrary

func bone(key: String) -> BoneDef
func slot(key: String) -> SlotDef
func slot_keys() -> Array[String]
## Os ossos em ordem de hierarquia (pai antes de filho).
func bones_in_order() -> Array[BoneDef]

## Os tipos de peça que este encaixe aceita, somando todos os modos.
func accepted_slots(slot_key: String) -> Array[Part.Slot]

## O modo pelo qual esta peça entra neste encaixe (null se ela não cabe).
func mount_for(slot_key: String, part: Part) -> MountDef

## A chave da hitbox que esta peça ocupa: o osso hospedeiro quando ela o substitui,
## senão "part:<slot_key>". É a única resposta para essa pergunta no projeto inteiro.
func hitbox_key(slot_key: String, part: Part) -> String

## O caminho do nó desta peça dentro do RobotSprite: "hip/torso/back_1".
func node_path(slot_key: String) -> String
```

`hitbox_key()` sozinha apaga `Combatant._hitbox_key_for_slot`, `Body._is_structural_slot`
e o fallback por tentativa de `RobotSprite._mounted`.

---

## 4. Os atributos

### 4.1 `StatDef` e `StatSchema`

```gdscript
## Um atributo do jogo. O chassi dá o valor base, as peças somam e multiplicam.
class_name StatDef
extends Resource

@export var key: String = ""              # "strength"
@export var display_name: String = ""     # "Força"
@export var abbreviation: String = ""     # "FOR"
@export var description: String = ""      # "Base do dano causado."
## Valor quando o chassi não declara nada.
@export var default_base: int = 0
## Piso aplicado depois de somar e multiplicar.
@export var minimum: int = 0
## Campo de `UnitStats` que este atributo alimenta ("attack", "speed", "defense",
## "max_mp"). Vazio = o atributo existe, soma e aparece no hangar, e quem precisa
## dele lê por `loadout.stat(key)`.
@export var maps_to: String = ""
```

```gdscript
## O vocabulário de atributos do jogo — declarado uma vez, em res://stats/default.tres.
class_name StatSchema
extends Resource

## Na ordem em que o hangar os mostra.
@export var stats: Array[StatDef] = []

func stat(key: String) -> StatDef
func keys() -> Array[String]
```

O esquema padrão transcreve exatamente o que existe hoje:

| key | rótulo | abrev | base MK-I | piso | `maps_to` |
| --- | --- | --- | --- | --- | --- |
| `strength` | Força | FOR | 12 | 1 | `attack` |
| `agility` | Agilidade | AGI | 10 | 1 | `speed` |
| `defense` | Defesa | DEF | 4 | 0 | `defense` |
| `energy` | Energia | EN | 18 | 0 | `max_mp` |
| `capacity` | Carga | CARGA | 120 | 1 | — |

**`UnitStats` continua com campos nomeados.** O `maps_to` é a ponte: o combate lê
`stats.attack` e `stats.speed` no caminho quente (`battle_manager.gd:153,200-201`) e não
tem por que virar dicionário. Um atributo sem `maps_to` existe do mesmo jeito — soma,
aparece no hangar, e é lido por quem souber o que fazer com ele. Isso é honesto: um
atributo genuinamente novo sempre vai exigir ensinar ao combate o que ele faz; o que o
esquema compra é que acrescentá-lo não exija editar `Chassis`, `Part`, `resolve()` e os
rótulos do hangar.

De quebra, `head_hp`, `torso_hp`, `arm_hp`, `leg_hp`, `hp_for()` e `total_hp()` saem do
`UnitStats` — são código morto desde que o `Body` passou a somar a vida por hitbox.

### 4.2 O que `Chassis` e `Part` passam a guardar

```gdscript
# Chassis
@export var schema: StatSchema
## Valores base: {"strength": 12, "agility": 10, "capacity": 120}.
## O que não estiver aqui usa o `default_base` do StatDef.
@export var base_stats: Dictionary[String, int] = {}
```

```gdscript
# Part
## Quanto a peça soma: {"strength": 6}.
@export var modifiers: Dictionary[String, int] = {}
## Quanto a peça multiplica, depois de todas as somas: {"agility": 1.2}.
@export var scalers: Dictionary[String, float] = {}
```

Dois campos da `Part` **não** entram no dicionário, de propósito:

- **`weight`** não é um atributo, é o **preço**. Ele soma contra a carga em vez de somar
  com uma base do chassi, e é o único número que o hangar mostra como custo.
- **`resistance`** não é somável: é a vida daquela hitbox, consumida pelo `Body` peça a
  peça. Somar as resistências de todas as peças não significa nada.

### 4.3 O `resolve()` genérico

```gdscript
func resolve(lost: Array = []) -> UnitStats:
    var values := {}
    for def in schema().stats:
        values[def.key] = chassis.base_stats.get(def.key, def.default_base)

    # A penalidade de carga é o primeiro multiplicador — as peças entram junto dela.
    var scale := {"agility": load_penalty()}

    for part in active_parts(lost):
        for key in part.modifiers:
            values[key] = int(values.get(key, 0)) + part.modifiers[key]
        for key in part.scalers:
            scale[key] = float(scale.get(key, 1.0)) * part.scalers[key]

    var stats := UnitStats.new()
    for def in schema().stats:
        var value := maxi(def.minimum, roundi(values[def.key] * float(scale.get(def.key, 1.0))))
        values[def.key] = value
        if not def.maps_to.is_empty():
            stats.set(def.maps_to, value)
    _resolved = values
    return stats
```

A ordem — soma tudo, multiplica depois, aplica o piso por último — é exatamente a de
hoje (`loadout.gd:229-232`), e a penalidade de carga deixa de ser um caso especial no
meio do cálculo para virar mais um multiplicador. Os `scalers` são o que hoje não tem
onde morar: uma peça "+20% de força" é impossível de expressar.

No hangar, `stats_label` (`hangar.gd:53`) e `_delta_text` (`:198-206`) viram laços sobre
o esquema, e param de ser listas escritas à mão.

---

## 5. A árvore de nós e as animações

### 5.1 Por que o `_draw()` não serve

Um `AnimationPlayer` não tem o que animar num `_draw()` procedural: não existem nós com
transformação para pôr numa track. O [feature_parts.md](feature_parts.md) §5 já viu isso
e propõe uma árvore de `PartNode` — mas fixa essa árvore num `.tscn` com nomes escritos
à mão, o que seria mais uma cópia da anatomia.

A anatomia **gera** a árvore. Um nó por osso, aninhado por `parent`, na transformação de
repouso; um nó por encaixe, filho do `host_bone`; todos nomeados pela chave. Assim o
caminho do nó é derivável (`hip/torso/arm_left`), e uma `AnimationLibrary` escrita contra
esses caminhos vale para qualquer robô que use a anatomia.

```
root
└── hip ─────┬─ leg_left ─ leg_right
             └─ torso ──┬─ head ─ [head_top]
                        ├─ arm_left  ─ [arm_left]
                        ├─ arm_right ─ [arm_right]
                        ├─ [back_1]  ─ [back_2]
                        └─ [chest_1] ─ [chest_2]
```

Abaixar o robô é uma track no `hip`. Tudo o mais segue de graça.

Quando um encaixe usa um modo com `replaces_host` (o braço completo), a arte da peça vai
**no nó do osso**, não num filho — coerente com o `hitbox_key()`, que devolve a chave do
osso nesse caso. Cada nó é um `PartNode` como o `feature_parts.md` descreve: sprite,
shader de dano e âncora de VFX.

### 5.2 Os três níveis de animação

| Nível | Quem toca | Onde mora | Exemplo |
| --- | --- | --- | --- |
| **Peça** | o sprite da própria peça | tag de `SpriteFrames` no `.aseprite` | o cano esquenta e recua |
| **Corpo** | `AnimationPlayer` sobre os nós dos ossos | `Anatomy.animations` | o robô se abaixa ao disparar |
| **Cena** | tween no `Combatant` (já existe) | `combatant.gd:219-236` | avança contra o alvo e volta |

O caso do lança-chamas que faz o robô se abaixar é o nível 2, disparado pela peça. O
vínculo:

```gdscript
# Actions.LIST — o padrão da ação: todo tiro pesado recua.
"plasma": { …, "body_animation": "recoil_heavy" },

# Part — o override opcional: este lança-chamas se agacha.
@export var body_animation: String = ""
```

Default na ação, override na peça. A animação em si mora na anatomia, porque é ela que
sabe quais ossos existem — um quadrúpede não se agacha do mesmo jeito.

### 5.3 O que compõe com o quê

Três coisas mexem no corpo ao mesmo tempo e precisam não brigar:

| O quê | Hoje | Depois |
| --- | --- | --- |
| Respiração | `breath`, somado à mão em cada coordenada do `_draw()` | track em loop no `hip` |
| Escora numa perna só | `sprite.rotation` + `ground_offset` (`combatant.gd:262-269`) | fica na **raiz**, acima da pose |
| Pose de ação | não existe | `AnimationPlayer` sobre `hip` e abaixo |

Elas compõem porque são nós e propriedades diferentes: o `Combatant` continua inclinando
a raiz sem saber que existe uma pose, e a pose continua valendo sem saber que o robô
está manco.

### 5.4 A vista de costas

`back_view` faz três coisas, todas declaradas: espelha a raiz em X (o que já troca
esquerda e direita de graça, sem a inversão manual de `robot_sprite.gd:113`), escolhe a
arte `_back` quando ela existe, e aplica o `z_index_back` dos ossos e encaixes cuja
profundidade muda — as peças das costas passam para trás, as do peito somem atrás do
tórax.

---

## 6. O que muda em cada arquivo

### 6.1 `Chassis`

```gdscript
@export var anatomy: Anatomy
@export var schema: StatSchema
@export var base_stats: Dictionary[String, int] = {}
## Sobrescreve a resistência de fábrica de ossos específicos: {"torso": 34}.
@export var bone_resistance: Dictionary[String, int] = {}
@export var disabled_slots: Array[String] = []
@export var restricted_tags: Array[String] = []
```

Saem `strength`, `agility`, `defense`, `energy`, `capacity` e as quatro resistências
nomeadas.

### 6.2 `Loadout`

```gdscript
@export var chassis: Chassis
## Encaixe → peça. As chaves vêm da anatomia; encaixe vazio não aparece no dicionário.
@export var slots: Dictionary[String, Part] = {}
```

Saem os nove `@export` nomeados, a `const SLOT_KEYS`, o `enum ArmMode`, os campos
`arm_left_mode`/`arm_right_mode` e os quatro `match`.

| Antes | Depois |
| --- | --- |
| `Loadout.SLOT_KEYS` | `loadout.slot_keys()` — da anatomia, menos os `disabled_slots` |
| `Loadout.slot_label(key)` (estático) | `loadout.slot_label(key)` — do `SlotDef.label` |
| `loadout.accepted_slot(key)` | `loadout.accepted_slots(key)` — lista, dos `mounts` |
| `loadout.arm_mode(key)` | `loadout.mount_for(key)` — derivado da peça |
| `loadout.arm_mode_label(key)` | `MountDef.label` |
| `loadout.set_arm_mode(key, mode)` | **some** |
| — | `loadout.stat(key)` — o valor resolvido de um atributo |

**O modo do braço deixa de ser estado.** Hoje `arm_left_mode` é redundante: `equip()`
(`loadout.gd:117`) já o deriva da peça, `set_arm_mode()` nunca é chamado pela UI, e
`options_for()` nos braços já ignora o modo e oferece os três tipos de uma vez
(`loadout.gd:95`). O único efeito de o campo existir é obrigar o hangar a salvar e
restaurar o modo à mão para calcular o delta de uma peça (`hangar.gd:187,192-195`) e
deixar um modo obsoleto para trás quando a peça é removida.

### 6.3 `Body`

`from_loadout()` percorre a anatomia em vez de `FRAME` e `ATTACHMENT_PARENT`. Somem
`FRAME`, `ATTACHMENT_PARENT`, `_frame_hp`, `_structural_replacement` e
`_is_structural_slot`:

```gdscript
static func from_loadout(loadout: Loadout) -> Body:
    var body := Body.new()
    var anatomy := loadout.anatomy()
    var bones := {}

    for bone in anatomy.bones_in_order():
        if not bone.hitbox:
            continue
        var part := BodyPart.from_bone(bone, loadout.resistance_for(bone))
        # Uma peça que substitui o osso inteiro vira a própria hitbox dele.
        var replacement := loadout.part_replacing(bone.key)
        if replacement != null:
            part.adopt(replacement)
        part.parent = bones.get(bone.parent)
        body.parts.append(part)
        bones[bone.key] = part

    for slot_key in loadout.slot_keys():
        var piece := loadout.get_part(slot_key)
        if piece == null or loadout.replaces_host(slot_key):
            continue
        var def := anatomy.slot(slot_key)
        body.parts.append(BodyPart.from_attachment(
            def, piece, bones.get(def.host_bone), body._unique_name(piece)))
    return body
```

O resto de `Body` (`apply_damage`, `repair`, `random_target`, `aim_chance`,
`_collapse_dependents`) não muda uma linha — ele já trabalha sobre `parts` sem saber de
onde vieram.

### 6.4 `BodyPart` — o estado de dano unificado

```gdscript
## O quanto uma hitbox ainda está de pé. É a única definição desses limiares no
## projeto: arte, HUD e VFX leem daqui.
enum Condition { INTACT, DAMAGED, CRITICAL, DESTROYED }

const DAMAGED_AT := 0.6
const CRITICAL_AT := 0.3

func condition() -> Condition:
    return condition_for(ratio()) if is_intact() else Condition.DESTROYED

static func condition_for(value: float) -> Condition:
    if value <= 0.0:
        return Condition.DESTROYED
    if value <= CRITICAL_AT:
        return Condition.CRITICAL
    if value <= DAMAGED_AT:
        return Condition.DAMAGED
    return Condition.INTACT
```

`ChassisArt.DAMAGED_AT/CRITICAL_AT` e os `if part.ratio() <= 0.3` do
`hitbox_debug_panel.gd:121-123` passam a chamar isto, e os VFX do
[feature_parts.md](feature_parts.md) escutam a mesma função — a fumaça começa exatamente
quando o sprite troca para `critical` e quando o painel pinta a linha de vermelho.

### 6.5 `Part`

```gdscript
@export var modifiers: Dictionary[String, int] = {}
@export var scalers: Dictionary[String, float] = {}
@export var weight: int = 8
@export var resistance: int = 6

@export_group("Combate")
## Ids de ações em Actions.LIST que esta peça concede.
@export var grants_actions: Array[String] = []
## Sobrescreve a animação de corpo da ação, quando esta peça é a origem.
@export var body_animation: String = ""
@export var hit_weight: float = 0.8
@export var damage_multiplier: float = 1.0

@export_group("Visual")
## Prefixo do arquivo de arte:
## res://assets/sprites/parts/<art_id>_front[_estado].aseprite
## Vazio = desenho procedural.
@export var art_id: String = ""
```

`grants_action: String` vira lista — hoje uma peça nunca pode conceder duas ações, o que
descarta desenhos óbvios (um braço que corta *e* atira). `Combatant.available_actions()`
(`combatant.gd:66`) já agrupa por id de ação, então passa a iterar a lista; o desempate
por força continua igual.

### 6.6 `ArtLibrary` (era `ChassisArt`)

`actors/chassis_art.gd` já tem a mecânica certa: resolve textura por convenção de
caminho, cai em cascata de estado, cacheia, e rejeita arquivo sem transparência real para
voltar ao desenho procedural sozinho — é o que faz a arte "ligar" peça por peça, sem
mexer em código. Falta só valer para as peças também:

```gdscript
## res://assets/sprites/chassis/<chassis_id>/<bone>_front[_estado].aseprite
static func bone_texture(chassis_id: String, bone: String, cond: BodyPart.Condition) -> Texture2D

## res://assets/sprites/parts/<art_id>_front[_estado].aseprite
static func part_texture(art_id: String, cond: BodyPart.Condition) -> Texture2D
```

A assinatura recebe `Condition` em vez de `float`: os limiares saem daqui e vão para o
`BodyPart`. É este `art_id` que destrava quantas peças você quiser por encaixe — o
lança-chamas e o lança-foguetes de cabeça deixam de disputar as duas ramificações de
`_draw_head_mount`.

### 6.7 `RobotSprite`

Deixa de desenhar por código e passa a **montar** a árvore da anatomia no `_ready()`,
com um `PartNode` por osso e por encaixe. O `_draw()` de hoje não é apagado: ele
sobrevive **dentro de cada nó**, como fallback de quem ainda não tem `art_id` — a mesma
migração peça a peça que o `feature_parts.md` §7.4 descreve, agora por nó em vez de por
`if` dentro de uma função de 60 linhas.

O sniffing de atributos (`piece.agility > 0`, `piece.energy > 0`,
`grants_action == "plasma"`) some junto: quem quer aparência específica declara `art_id`.

---

## 7. Migração

| O que | Conserto |
| --- | --- |
| `parts/*.tres` (11 arquivos) | `strength`/`agility`/`defense`/`energy` → `modifiers`; `grants_action` → `grants_actions` |
| `chassis/mk1.tres` | atributos → `base_stats`; resistências → `bone_resistance`; apontar `anatomy` e `schema` |
| `assets/chassis/mk2_goliath.tres`, `mk3_strider.tres` | mover para `chassis/`, apontar anatomia e esquema, entrar no `ChassisCatalog` novo |
| `units/r7.tres`, `units/sentinel_v9.tres` | encaixes como dicionário; remover `arm_*_mode` |
| `user://loadout.json` | `_to_dict/_from_dict` já trabalham por chave; só sai o par `arm_*_mode` |

O save é o menor risco: ele grava **ids de peça por chave de encaixe**
(`player_loadout.gd:47-59`), que é exatamente o formato do dicionário novo. Um save
antigo com `arm_left_mode` continua carregando — a chave extra é ignorada, e o modo é
recalculado da peça.

`tools/simulate.gd` e `tools/smoke_test.gd` rodam sem alteração, e são a rede de
segurança de cada fase: o simulador compara o placar de 200 batalhas antes e depois para
provar que os números não andaram, e o smoke test prova que a batalha inteira ainda
termina.

---

## 8. Fases

Cada fase termina com o jogo rodando e o smoke test passando.

**1. `Condition` unificado.** `BodyPart.Condition` e os limiares num lugar só;
`ChassisArt` e `hitbox_debug_panel` passam a usar. Não toca em anatomia nem em atributos
— é limpeza isolada, e já resolve a divergência 0,6/0,3 × 0,5/0,2.

**2. `StatSchema` + `res://stats/default.tres`.** `Chassis.base_stats`,
`Part.modifiers`/`scalers`, o `resolve()` genérico, o hangar por laço. Migra os 11
`.tres` de peça. O simulador tem que dar o mesmo placar. Sai o código morto do
`UnitStats`.

**3. Os recursos de anatomia + `anatomy/humanoid.tres`.** `BoneDef`, `MountDef`,
`SlotDef`, `Anatomy`, transcrevendo exatamente o `FRAME`, o `ATTACHMENT_PARENT` e o
`SLOT_KEYS` de hoje, mais o osso `hip` que ninguém consome ainda.

**4. `Body` e `Combatant` leem da anatomia.** Somem `FRAME`, `ATTACHMENT_PARENT`,
`_frame_hp`, `_structural_replacement`, `_is_structural_slot`, `_hitbox_key_for_slot`.
Placar igual outra vez.

**5. `Loadout` por dicionário.** Migra os `.tres` de unidade e o save; some o `ArmMode`;
o hangar perde o salva-e-restaura do modo.

**6. `Part`: `grants_actions[]` e `art_id`; `ArtLibrary`.** A partir daqui, peças novas
por encaixe são só arquivo.

**7. `RobotSprite` gerado da anatomia.** A árvore de nós, com o desenho procedural
sobrevivendo por nó. É a fase mais longa e a que muda mais o visual — e a que abre a
seguinte.

**8. Animações.** `Anatomy.animations`, o `body_animation` na ação e na peça, a
respiração virando track, a escora indo para a raiz.

**9. `ChassisCatalog` e a unificação de `chassis/` com `assets/chassis/`.** O MK-II e o
MK-III deixam de ser órfãos e viram escolha no hangar.

As fases 1 e 2 são independentes de tudo o mais e podem sair em qualquer ordem. Da 3 em
diante a ordem importa.

---

## 9. O que isso destrava

**Um encaixe novo.** Cintura, ombros, um terceiro slot de costas: acrescentar um
`SlotDef` em `humanoid.tres`. O hangar lista, o `Body` cria a hitbox, o `RobotSprite`
cria o nó. Zero linhas de código.

**Quantas peças você quiser por encaixe.** Lança-chamas, lança-foguetes, canhão laser e
sensor no mesmo `head_top`, cada um com o próprio `art_id` — e o encaixe vazio continua
sendo vazio. É o que hoje as duas ramificações de `_draw_head_mount` impedem.

**Modo parcial de perna.** É o que o [feature_hangar.md](feature_hangar.md) já prevê:
acrescentar `Part.Slot.LEG_MOUNT` e um `MountDef` com `replaces_host = false` no
`SlotDef` da perna. As duas hitboxes por perna aparecem sozinhas, como já acontece nos
braços.

**Uma arma que move o corpo inteiro.** `body_animation: "crouch_fire"` na peça, e uma
animação no `hip` da anatomia. Vale para qualquer robô humanoide, com qualquer chassi.

**Uma peça multiplicativa.** `scalers = {"agility": 1.2}` — hoje impossível.

**Um atributo novo.** Um `StatDef` no esquema: ele soma, aparece no hangar com rótulo e
abreviação, entra no delta da troca. Só falta ensinar ao combate o que ele faz.

**Uma forma nova.** Um quadrúpede é uma `Anatomy` com quatro ossos de perna e nenhum de
braço. `Body`, `Combatant`, `Loadout` e o hangar não mudam; a arte e as animações, sim.

**Cascata estrutural.** Com `BoneDef.parent`, arrancar o tórax pode levar os braços — a
mecânica já existe (`Body._collapse_dependents`), faltava a hierarquia poder ser
declarada.

---

## 10. O que falta definir

1. **Peça em encaixe desligado.** Se o chassi desliga `back_2` e a montagem salva tem uma
   peça lá, ela é descartada ou fica guardada até voltar para um chassi que tenha o
   encaixe? Hoje `options_for` filtra, mas `resolve()` e `Body` ainda contam a peça.

2. **Anatomia por chassi × `disabled_slots`.** Os dois expressam "este robô tem menos
   encaixes". Vale manter os dois caminhos, ou `disabled_slots` deveria sumir em favor de
   anatomias específicas?

3. **`capacity` como atributo cria um laço.** Se uma peça pode somar carga (um reforço
   estrutural), então a carga disponível depende das peças montadas, que são limitadas
   pela carga. Precisa de uma regra explícita — provavelmente: a capacidade se resolve
   **sem** os `scalers` e sem as peças perdidas, uma vez, antes da penalidade.

4. **Ossos sem hitbox no painel de debug.** O `hip` não tem vida. O
   `hitbox_debug_panel` lista `body.parts`, então ele some sozinho — mas o painel também
   é onde se enxerga a hierarquia, e talvez valha mostrá-lo como linha estrutural.

5. **De onde vem a pose de repouso.** As posições de hoje estão afinadas à mão dentro das
   funções de desenho (`side * 142.0`, `-258.0`). Transcrevê-las para `rest_position` é
   fiel enquanto o desenho for procedural; com os sprites do
   [feature_parts.md](feature_parts.md), a pose de repouso provavelmente vira o pivot do
   `PartNode` e as posições precisam ser re-afinadas contra a arte real.

6. **Animação × destruição.** O robô se agacha para disparar; no meio da animação a
   perna cai. A pose é interrompida, é tocada até o fim, ou a escora entra por cima como
   um blend? A separação raiz/pose (§5.3) permite as três — falta escolher.
