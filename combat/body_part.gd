## Uma hitbox: um pedaço do robô com vida própria.
##
## Pode ser estrutural (vem do exoesqueleto) ou uma peça montada. Nos dois casos vale a
## mesma regra: o total de vida do combatente é a soma das hitboxes (ver Body).
class_name BodyPart
extends RefCounted

## Os pedaços estruturais. Peças montadas usam ATTACHMENT e se distinguem pela `key`.
enum Kind { HEAD, TORSO, ARM_LEFT, ARM_RIGHT, LEG_LEFT, LEG_RIGHT, ATTACHMENT }

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


func is_intact() -> bool:
	return hp > 0


func is_attachment() -> bool:
	return source != null and kind == Kind.ATTACHMENT


func ratio() -> float:
	return float(hp) / float(max_hp)


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
