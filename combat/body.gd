## O corpo de um combatente: um conjunto de hitboxes independentes.
##
## Parte delas é estrutural (vem do exoesqueleto); o resto são as peças montadas, que
## também têm vida própria. A vida total é a soma de todas. Cada hitbox tem uma `key`
## única — é por ela que as ações declaram do que precisam para existir.
class_name Body
extends RefCounted

## Geometria das partes estruturais: área aparente (weight), quanto amplificam o dano
## que recebem (multiplier) e em que ordem recebem o excedente de um golpe (absorb).
const FRAME := {
	"head": {"kind": BodyPart.Kind.HEAD, "name": "Cabeça", "narrative": "a cabeça",
		"weight": 1.0, "multiplier": 1.5, "absorb": 5},
	"torso": {"kind": BodyPart.Kind.TORSO, "name": "Tórax", "narrative": "o tórax",
		"weight": 3.0, "multiplier": 1.0, "absorb": 0},
	"arm_left": {"kind": BodyPart.Kind.ARM_LEFT, "name": "Braço esq.", "narrative": "o braço esquerdo",
		"weight": 1.5, "multiplier": 0.85, "absorb": 3},
	"arm_right": {"kind": BodyPart.Kind.ARM_RIGHT, "name": "Braço dir.", "narrative": "o braço direito",
		"weight": 1.5, "multiplier": 0.85, "absorb": 4},
	"leg_left": {"kind": BodyPart.Kind.LEG_LEFT, "name": "Perna esq.", "narrative": "a perna esquerda",
		"weight": 2.0, "multiplier": 0.9, "absorb": 1},
	"leg_right": {"kind": BodyPart.Kind.LEG_RIGHT, "name": "Perna dir.", "narrative": "a perna direita",
		"weight": 2.0, "multiplier": 0.9, "absorb": 2},
}

## Onde cada encaixe se pendura. Peça montada cai junto com a parte que a sustenta.
const ATTACHMENT_PARENT := {
	"head_top": "head",
	"back_1": "torso", "back_2": "torso",
	"chest_1": "torso", "chest_2": "torso",
	"arm_left": "arm_left", "arm_right": "arm_right",
}

var parts: Array[BodyPart] = []


## Monta o corpo a partir de uma montagem do hangar.
static func from_loadout(loadout: Loadout) -> Body:
	var body := Body.new()
	var chassis := loadout.chassis if loadout.chassis != null else Chassis.new()
	var structural := {}

	for key in FRAME:
		var config: Dictionary = FRAME[key].duplicate()
		config["key"] = key
		config["hp"] = body._frame_hp(key, chassis)

		# Braço ou perna substituídos por inteiro: a peça é a própria hitbox estrutural.
		var replacement := body._structural_replacement(loadout, key)
		if replacement != null:
			config["hp"] = replacement.resistance
			config["source"] = replacement
			config["multiplier"] = replacement.damage_multiplier
		var part := BodyPart.new(config)
		body.parts.append(part)
		structural[key] = part

	# Peças montadas: hitboxes próprias, penduradas na parte que as sustenta.
	var used_names := {}
	for slot_key in Loadout.SLOT_KEYS:
		if not ATTACHMENT_PARENT.has(slot_key):
			continue
		var piece := loadout.get_part(slot_key)
		if piece == null or body._is_structural_slot(loadout, slot_key):
			continue

		var name := piece.display_name
		if used_names.has(name):
			used_names[name] = int(used_names[name]) + 1
			name = "%s %d" % [name, used_names[name]]
		else:
			used_names[name] = 1

		body.parts.append(BodyPart.new({
			"key": "part:%s" % slot_key,
			"kind": BodyPart.Kind.ATTACHMENT,
			"name": name,
			"narrative": piece.narrative_name,
			"hp": piece.resistance,
			"weight": piece.hit_weight,
			"multiplier": piece.damage_multiplier,
			"absorb": 6,
			"source": piece,
			"parent": structural.get(ATTACHMENT_PARENT[slot_key]),
		}))
	return body


func total_hp() -> int:
	var sum := 0
	for part in parts:
		sum += part.hp
	return sum


func max_total_hp() -> int:
	var sum := 0
	for part in parts:
		sum += part.max_hp
	return sum


func intact_parts() -> Array[BodyPart]:
	return parts.filter(func(p: BodyPart) -> bool: return p.is_intact())


## As peças que já foram destruídas — elas param de somar atributos no combatente.
func lost_pieces() -> Array[Part]:
	var lost: Array[Part] = []
	for part in parts:
		if not part.is_intact() and part.source != null:
			lost.append(part.source)
	return lost


func part_by_key(key: String) -> BodyPart:
	for part in parts:
		if part.key == key:
			return part
	return null


## A hitbox estrutural de um tipo (cabeça, braço esquerdo…).
func part_of(kind: BodyPart.Kind) -> BodyPart:
	for part in parts:
		if part.kind == kind:
			return part
	return null


func structural_parts() -> Array[BodyPart]:
	return parts.filter(func(p: BodyPart) -> bool: return p.kind != BodyPart.Kind.ATTACHMENT)


func attachment_parts() -> Array[BodyPart]:
	return parts.filter(func(p: BodyPart) -> bool: return p.kind == BodyPart.Kind.ATTACHMENT)


## Sorteia uma parte ainda intacta, com peso proporcional à área.
func random_target() -> BodyPart:
	var pool := intact_parts()
	if pool.is_empty():
		return null

	var total_weight := 0.0
	for part in pool:
		total_weight += part.hit_weight

	var roll := randf() * total_weight
	for part in pool:
		roll -= part.hit_weight
		if roll <= 0.0:
			return part
	return pool[-1]


## Chance de um golpe mirado realmente acertar a parte escolhida: proporcional à área,
## então o tórax é alvo certo e uma peça pequena é aposta.
func aim_chance(part: BodyPart) -> float:
	if part == null:
		return 0.0
	var heaviest := 0.0
	for other in parts:
		heaviest = maxf(heaviest, other.hit_weight)
	if heaviest <= 0.0:
		return 1.0
	return 0.5 + 0.5 * (part.hit_weight / heaviest)


## O alvo de um golpe: a parte mirada quando a mira pega, senão o sorteio de sempre.
func aimed_target(preferred: BodyPart = null) -> BodyPart:
	if preferred == null or not preferred.is_intact():
		return random_target()
	if randf() < aim_chance(preferred):
		return preferred
	return random_target()


## Aplica o dano na hitbox indicada. O que ela não absorver se dissipa pelas outras,
## mas **o respingo não mutila**: ele para em 1 de vida em cada parte vizinha, então só
## o golpe direto (ou mirado) arranca uma peça. A vida total cai o mesmo tanto.
##
## A exceção é a cascata: uma hitbox destruída leva junto o que estava pendurado nela,
## e essa perda extra não conta como dano aplicado — a cabeça arrancada leva o canhão.
func apply_damage(amount: int, first: BodyPart = null) -> Dictionary:
	var target := first if first != null and first.is_intact() else random_target()
	if target == null:
		return {"part": null, "dealt": 0, "destroyed": []}

	var destroyed: Array[BodyPart] = []
	var remaining := amount
	var dealt := 0

	# 1. A parte atingida encaixa o golpe inteiro e pode cair.
	var before := target.hp
	remaining = target.absorb(remaining)
	dealt += before - target.hp
	if target.hp == 0:
		destroyed.append(target)

	# 2. O excedente se dissipa pelo corpo, ferindo sem destruir.
	var others := intact_parts()
	others.erase(target)
	others.sort_custom(func(a: BodyPart, b: BodyPart) -> bool:
		return a.absorb_priority < b.absorb_priority)
	for part in others:
		if remaining <= 0:
			break
		var start := part.hp
		remaining = part.absorb(remaining, 1)
		dealt += start - part.hp

	# 3. Golpe grande demais para o corpo inteiro absorver: aí leva o que restou.
	if remaining > 0:
		for part in others:
			if remaining <= 0:
				break
			var start := part.hp
			remaining = part.absorb(remaining)
			dealt += start - part.hp
			if part.hp == 0:
				destroyed.append(part)

	_collapse_dependents(destroyed)
	return {"part": target, "dealt": dealt, "destroyed": destroyed}


## Repara primeiro o que está mais avariado. Devolve o total restaurado.
func repair(amount: int) -> int:
	var order: Array[BodyPart] = []
	order.assign(parts)
	order.sort_custom(func(a: BodyPart, b: BodyPart) -> bool:
		return (a.max_hp - a.hp) > (b.max_hp - b.hp))

	var remaining := amount
	var restored := 0
	for part in order:
		if remaining <= 0:
			break
		var done := part.repair(remaining)
		restored += done
		remaining -= done
	return restored


## O que estava pendurado numa hitbox destruída cai junto, em cascata.
func _collapse_dependents(destroyed: Array[BodyPart]) -> void:
	var queue: Array[BodyPart] = []
	queue.assign(destroyed)
	while not queue.is_empty():
		var fallen: BodyPart = queue.pop_front()
		for part in parts:
			if part.parent == fallen and part.is_intact():
				part.hp = 0
				destroyed.append(part)
				queue.append(part)


func _frame_hp(key: String, chassis: Chassis) -> int:
	match key:
		"head": return chassis.head_resistance
		"torso": return chassis.torso_resistance
		"arm_left", "arm_right": return chassis.arm_resistance
		_: return chassis.leg_resistance


## A peça que substitui esta parte estrutural inteira, se houver.
func _structural_replacement(loadout: Loadout, key: String) -> Part:
	match key:
		"arm_left":
			return loadout.arm_left_part if loadout.arm_left_mode == Loadout.ArmMode.FULL else null
		"arm_right":
			return loadout.arm_right_part if loadout.arm_right_mode == Loadout.ArmMode.FULL else null
		"leg_left":
			return loadout.leg_left_part
		"leg_right":
			return loadout.leg_right_part
		_:
			return null


## O encaixe já virou a hitbox estrutural (braço/perna trocados por inteiro)?
func _is_structural_slot(loadout: Loadout, slot_key: String) -> bool:
	if slot_key == "arm_left":
		return loadout.arm_left_mode == Loadout.ArmMode.FULL
	if slot_key == "arm_right":
		return loadout.arm_right_mode == Loadout.ArmMode.FULL
	return false
