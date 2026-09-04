## Uma hitbox: um pedaço do robô com vida própria.
##
## Pode ser estrutural (vem do exoesqueleto) ou uma peça montada. Nos dois casos vale a
## mesma regra: o total de vida do combatente é a soma das hitboxes (ver Body).
class_name BodyPart
extends RefCounted

## Os pedaços estruturais. Peças montadas usam ATTACHMENT e se distinguem pela `key`.
enum Kind { HEAD, TORSO, ARM_LEFT, ARM_RIGHT, LEG_LEFT, LEG_RIGHT, ATTACHMENT }

## O quanto uma hitbox ainda está de pé. É a única definição desses limiares no
## projeto: arte, HUD e VFX leem daqui, para nunca discordar sobre o que é "muito
## danificado".
enum Condition { INTACT, DAMAGED, CRITICAL, DESTROYED }

const DAMAGED_AT := 0.6
const CRITICAL_AT := 0.3

## Identidade única dentro do corpo: "head", "arm_left", "part:back_1"…
## É por ela que as ações declaram o que precisam estar de pé.
var key: String
var kind: Kind
## Nome curto, para a UI ("Braço dir.").
var display_name: String
## Nome com artigo, para o log ("o braço direito").
var narrative_name: String
var max_hp: int
var hp: int
## Peso relativo no sorteio de acerto (área aparente da parte).
var hit_weight: float
## Quanto essa parte amplifica o dano recebido (cabeça dói mais).
var damage_multiplier: float
## Ordem em que a parte recebe o excedente de um golpe em outra hitbox (menor = antes).
var absorb_priority: int
## A peça que esta hitbox representa, quando for uma peça montada.
var source: Part = null
## A hitbox que sustenta esta. Se a mãe cai, esta cai junto.
var parent: BodyPart = null
## Esta peça está direto no socket de um osso e o esconde da mira enquanto viver — só
## campo de memória, o modelo novo não serializa isso (Docs/feature_montagem.md §7).
var covers_parent: bool = false


func _init(config: Dictionary) -> void:
	key = String(config.get("key", ""))
	kind = config.get("kind", Kind.ATTACHMENT)
	display_name = String(config.get("name", "Peça"))
	narrative_name = String(config.get("narrative", "a peça"))
	max_hp = maxi(1, int(config.get("hp", 1)))
	hp = max_hp
	hit_weight = float(config.get("weight", 1.0))
	damage_multiplier = float(config.get("multiplier", 1.0))
	absorb_priority = int(config.get("absorb", 9))
	source = config.get("source")
	parent = config.get("parent")


## Uma hitbox estrutural, a partir de um osso do esqueleto.
static func from_bone(bone: BoneDef, resistance: int) -> BodyPart:
	return BodyPart.new({
		"key": bone.key,
		"kind": bone.kind,
		"name": bone.display_name,
		"narrative": bone.narrative_name,
		"hp": resistance,
		"weight": bone.hit_weight,
		"multiplier": bone.damage_multiplier,
		"absorb": bone.absorb_priority,
	})


## Uma hitbox de peça montada: pendurada em quem a sustenta (osso ou outra peça — a
## recursão não distingue). `covers` marca a peça que está direto no socket de um osso,
## escondendo-o da mira enquanto viver (Docs/feature_montagem.md §7).
static func from_mounted(part: Part, parent_part: BodyPart, key: String, covers: bool) -> BodyPart:
	var body_part := BodyPart.new({
		"key": key,
		"kind": Kind.ATTACHMENT,
		"name": part.display_name,
		"narrative": part.narrative_name,
		"hp": part.resistance,
		"weight": part.hit_weight,
		"multiplier": part.damage_multiplier,
		"absorb": 6,
		"source": part,
		"parent": parent_part,
	})
	body_part.covers_parent = covers
	return body_part


func is_intact() -> bool:
	return hp > 0


func is_attachment() -> bool:
	return source != null and kind == Kind.ATTACHMENT


func ratio() -> float:
	return float(hp) / float(max_hp)


## O estado de dano desta hitbox, para quem decide arte, cor de HUD ou VFX.
func condition() -> Condition:
	return condition_for(ratio()) if is_intact() else Condition.DESTROYED


## A mesma pergunta, para quem só tem a proporção de vida (ex: o sprite pintado do
## chassi, antes de o `Body` existir no hangar).
static func condition_for(value: float) -> Condition:
	if value <= 0.0:
		return Condition.DESTROYED
	if value <= CRITICAL_AT:
		return Condition.CRITICAL
	if value <= DAMAGED_AT:
		return Condition.DAMAGED
	return Condition.INTACT


## Absorve o que puder sem descer abaixo de `floor_hp`, e devolve o excedente, que
## transborda para outra parte. O piso é o que faz o respingo ferir sem arrancar.
func absorb(amount: int, floor_hp: int = 0) -> int:
	var available := maxi(0, hp - floor_hp)
	var taken := mini(amount, available)
	hp -= taken
	return amount - taken


## Repara até o limite da parte e devolve o quanto foi restaurado.
func repair(amount: int) -> int:
	var restored := mini(amount, max_hp - hp)
	hp += restored
	return restored
