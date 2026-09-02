## A montagem de um robô: exoesqueleto, peças encaixadas, nome e cores.
##
## É o que o hangar edita e o que a batalha consome. Nada aqui conhece combate: a ponte
## é `resolve()`, que devolve o `UnitStats` que o combate já sabe ler.
class_name Loadout
extends Resource

## Como o braço está montado — define que tipo de peça aquele braço aceita.
enum ArmMode {
	STOCK,    ## braço do exoesqueleto, com uma peça acoplada ao antebraço
	FOREARM,  ## antebraço substituído por uma peça
	FULL,     ## braço inteiro substituído por uma peça
}

## Todos os encaixes, na ordem em que o hangar os lista.
const SLOT_KEYS := [
	"head_top", "back_1", "back_2", "chest_1", "chest_2",
	"arm_left", "arm_right", "leg_left", "leg_right",
]

@export var pilot_name: String = "R-7"
@export var chassis: Chassis

@export_group("Visual")
@export var body_color: Color = Color("4f9dde")
@export var accent_color: Color = Color("8ef0ff")

@export_group("Encaixes")
@export var head_top: Part
@export var back_1: Part
@export var back_2: Part
@export var chest_1: Part
@export var chest_2: Part

@export_group("Braços")
@export var arm_left_mode: ArmMode = ArmMode.STOCK
@export var arm_left_part: Part
@export var arm_right_mode: ArmMode = ArmMode.STOCK
@export var arm_right_part: Part

@export_group("Pernas")
## Null mantém a perna de fábrica do exoesqueleto.
@export var leg_left_part: Part
@export var leg_right_part: Part


func get_part(key: String) -> Part:
	match key:
		"head_top": return head_top
		"back_1": return back_1
		"back_2": return back_2
		"chest_1": return chest_1
		"chest_2": return chest_2
		"arm_left": return arm_left_part
		"arm_right": return arm_right_part
		"leg_left": return leg_left_part
		"leg_right": return leg_right_part
		_: return null


func set_part(key: String, part: Part) -> void:
	match key:
		"head_top": head_top = part
		"back_1": back_1 = part
		"back_2": back_2 = part
		"chest_1": chest_1 = part
		"chest_2": chest_2 = part
		"arm_left": arm_left_part = part
		"arm_right": arm_right_part = part
		"leg_left": leg_left_part = part
		"leg_right": leg_right_part = part


## Rótulo do encaixe para a UI do hangar.
static func slot_label(key: String) -> String:
	match key:
		"head_top": return "Topo da cabeça"
		"back_1": return "Costas 1"
		"back_2": return "Costas 2"
		"chest_1": return "Peito 1"
		"chest_2": return "Peito 2"
		"arm_left": return "Braço esquerdo"
		"arm_right": return "Braço direito"
		"leg_left": return "Perna esquerda"
		_: return "Perna direita"


## As peças que cabem neste encaixe. Nos braços entram os três modos de uma vez —
## escolher a peça é que define se o braço fica de fábrica, meio trocado ou inteiro novo.
func options_for(key: String) -> Array[Part]:
	if key == "arm_left" or key == "arm_right":
		var list: Array[Part] = []
		for slot in [Part.Slot.ARM_MOUNT, Part.Slot.FOREARM, Part.Slot.ARM_FULL]:
			list.append_array(PartCatalog.for_slot(slot))
		return list
	return PartCatalog.for_slot(accepted_slot(key))


## Encaixa uma peça, ajustando o modo do braço ao tipo escolhido.
func equip(key: String, part: Part) -> void:
	if part != null and (key == "arm_left" or key == "arm_right"):
		var mode := ArmMode.STOCK
		match part.slot:
			Part.Slot.FOREARM:
				mode = ArmMode.FOREARM
			Part.Slot.ARM_FULL:
				mode = ArmMode.FULL
		if key == "arm_left":
			arm_left_mode = mode
		else:
			arm_right_mode = mode
	set_part(key, part)


## Como o braço está montado, em palavras — para a linha do encaixe no hangar.
func arm_mode_label(key: String) -> String:
	match arm_mode(key):
		ArmMode.FOREARM: return "antebraço trocado"
		ArmMode.FULL: return "braço completo"
		_: return "braço de fábrica"


## Que tipo de peça este encaixe aceita agora (nos braços, depende do modo).
func accepted_slot(key: String) -> Part.Slot:
	match key:
		"head_top": return Part.Slot.HEAD_TOP
		"back_1", "back_2": return Part.Slot.BACK
		"chest_1", "chest_2": return Part.Slot.CHEST
		"arm_left": return _arm_slot(arm_left_mode)
		"arm_right": return _arm_slot(arm_right_mode)
		_: return Part.Slot.LEG_FULL


func arm_mode(key: String) -> ArmMode:
	return arm_left_mode if key == "arm_left" else arm_right_mode


## Trocar o modo do braço descarta a peça que estava lá — ela não cabe no novo modo.
func set_arm_mode(key: String, mode: ArmMode) -> void:
	if key == "arm_left":
		arm_left_mode = mode
		arm_left_part = null
	else:
		arm_right_mode = mode
		arm_right_part = null


## Todas as peças encaixadas, ignorando as indicadas em `lost`.
func active_parts(lost: Array = []) -> Array[Part]:
	var parts: Array[Part] = []
	for key in SLOT_KEYS:
		var part := get_part(key)
		if part != null and not lost.has(part):
			parts.append(part)
	return parts


func total_weight() -> int:
	var sum := 0
	for part in active_parts():
		sum += part.weight
	return sum


## Quanto da capacidade está ocupada (pode passar de 1.0 — aí a montagem é inválida).
func load_ratio() -> float:
	if chassis == null or chassis.capacity <= 0:
		return 0.0
	return float(total_weight()) / float(chassis.capacity)


func is_valid() -> bool:
	return chassis != null and load_ratio() <= 1.0


## Metade da capacidade é grátis; daí em diante a agilidade cai até −30% no limite.
func load_penalty() -> float:
	return 1.0 - 0.3 * clampf((load_ratio() - 0.5) / 0.5, 0.0, 1.0)


## A ponte com o combate: os atributos da montagem no formato que a batalha já lê.
## `lost` são as peças destruídas, que deixam de somar.
func resolve(lost: Array = []) -> UnitStats:
	var stats := UnitStats.new()
	stats.display_name = pilot_name
	stats.body_color = body_color
	stats.accent_color = accent_color

	var base := chassis if chassis != null else Chassis.new()
	var strength := base.strength
	var agility := base.agility
	var defense := base.defense
	var energy := base.energy

	for part in active_parts(lost):
		strength += part.strength
		agility += part.agility
		defense += part.defense
		energy += part.energy

	stats.attack = maxi(1, strength)
	stats.defense = maxi(0, defense)
	stats.max_mp = maxi(0, energy)
	stats.speed = maxi(1, roundi(agility * load_penalty()))
	return stats


func _arm_slot(mode: ArmMode) -> Part.Slot:
	match mode:
		ArmMode.FOREARM: return Part.Slot.FOREARM
		ArmMode.FULL: return Part.Slot.ARM_FULL
		_: return Part.Slot.ARM_MOUNT
