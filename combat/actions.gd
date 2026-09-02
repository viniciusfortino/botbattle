## Catálogo de ações. Adicione uma entrada aqui e um botão em battle.tscn
## (com metadata/action = "id_da_acao") para expor a ação ao jogador.
##
## Aqui ficam só as *definições* das ações — dano, custo, precisão, narração. Quem
## concede cada uma é a peça montada (`Part.grants_action`), e é o Combatant que resolve
## os requisitos concretos: a hitbox da própria peça, o membro que a sustenta e, quando
## `needs_legs` é verdadeiro, as duas pernas — sem deslocamento não há investida.
class_name Actions
extends RefCounted

const DAMAGE := "damage"
## Nenhuma ação cura hoje — a maquinaria continua aqui para itens ou aliados médicos.
const HEAL := "heal"
const GUARD := "guard"

## Abaixo disso a arma ainda funciona, mas com menos dano (ver part_efficiency).
const MIN_EFFICIENCY := 0.5

const LIST := {
	"attack": {
		"name": "Atacar",
		"kind": DAMAGE,
		"mp": 0,
		"power": 1.0,
		"pierce": 0.0,
		"crit": 0.10,
		"accuracy": 0.95,
		"needs_legs": true,
		"weapon": "lâmina",
		"lost_as": "ataque corpo a corpo",
		"log": "%s avança contra %s!",
	},
	"guard": {
		"name": "Defender",
		"kind": GUARD,
		"mp": 0,
		"mp_regen": 6,
		"needs_legs": false,
		"log": "%s ergue o escudo.",
	},
	"laser": {
		"name": "Laser",
		"kind": DAMAGE,
		"mp": 8,
		"power": 1.25,
		"pierce": 0.25,
		"crit": 0.12,
		"accuracy": 1.0,
		"needs_legs": false,
		"weapon": "canhão laser",
		"lost_as": "tiro de laser",
		"log": "%s dispara um laser contra %s!",
	},
	"plasma": {
		"name": "Plasma",
		"kind": DAMAGE,
		"mp": 12,
		"power": 1.85,
		"pierce": 0.5,
		"crit": 0.15,
		"accuracy": 1.0,
		"needs_legs": false,
		"weapon": "canhão de plasma",
		"lost_as": "canhão de plasma",
		"log": "%s dispara um feixe de plasma em %s!",
	},
}


static func get_action(id: String) -> Dictionary:
	return LIST.get(id, LIST["attack"])


static func action_name(id: String) -> String:
	return String(get_action(id).get("name", id))


static func cost(id: String) -> int:
	return int(get_action(id).get("mp", 0))


## A ação exige deslocamento (e portanto as duas pernas)?
static func needs_legs(id: String) -> bool:
	return bool(get_action(id).get("needs_legs", false))


static func kind_of(id: String) -> String:
	return String(get_action(id).get("kind", DAMAGE))


## Nome da arma, para o log e para a UI.
static func weapon_of(id: String) -> String:
	return String(get_action(id).get("weapon", ""))


## Como o log chama o que se perde junto com a arma: "sem canhão de plasma".
static func loss_label(id: String) -> String:
	return String(get_action(id).get("lost_as", ""))


## Quanto uma hitbox nessa condição ainda entrega: 100% inteira, MIN_EFFICIENCY em
## frangalhos, 0 quando destruída. O piso evita que a arma vire inútil antes de cair.
static func part_efficiency(part: BodyPart) -> float:
	if part == null:
		return 1.0
	if not part.is_intact():
		return 0.0
	return MIN_EFFICIENCY + (1.0 - MIN_EFFICIENCY) * part.ratio()
