## O corpo de um combatente: um conjunto de hitboxes independentes.
##
## Parte delas é estrutural (vem do exoesqueleto); o resto são as peças montadas, que
## também têm vida própria. A vida total é a soma de todas. Cada hitbox tem uma `key`
## única — é por ela que as ações declaram do que precisam para existir.
class_name Body
extends RefCounted

var parts: Array[BodyPart] = []


## Monta o corpo a partir de uma montagem do hangar: um osso do esqueleto é uma hitbox,
## e cada peça montada (em qualquer profundidade) é outra, pendurada em quem a
## sustenta. A peça direto no socket de um osso o esconde da mira enquanto viver — as
## duas hitboxes coexistem (Docs/feature_montagem.md §7).
static func from_loadout(loadout: Loadout) -> Body:
	var body := Body.new()
	var bone_parts := {}
	for bone in loadout.kit.skeleton.bones:
		var part := BodyPart.from_bone(bone, bone.resistance)
		body.parts.append(part)
		bone_parts[bone.key] = part

	var path_parts := {}
	for entry in loadout.mounted_parts():
		var path: String = entry["path"]
		var piece: Part = entry["part"]
		var parent_path: String = entry["parent_path"]
		var parent: BodyPart = (
			path_parts.get(parent_path) if not parent_path.is_empty()
			else bone_parts.get(path.split("/")[0]))
		# Direto no socket de um osso (parent_path vazio) = cobre o osso.
		var covers := parent_path.is_empty()
		var mounted_part := BodyPart.from_mounted(piece, parent, path, covers)
		body.parts.append(mounted_part)
		path_parts[path] = mounted_part
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
	return parts.filter(func(p: BodyPart) -> bool: return p.is_intact() and not _is_covered(p))


## Um osso escondido atrás da peça que o cobre não pode ser mirado nem sorteado — só
## fica exposto quando essa peça cai (Docs/feature_montagem.md §7). Não afeta
## `part_by_key()`: um osso coberto continua funcional, só não é alvo.
func _is_covered(target: BodyPart) -> bool:
	for other in parts:
		if other.parent == target and other.covers_parent and other.is_intact():
			return true
	return false


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

	# 1.5. Estouro: a peça que cobria um osso blinda até cair, mas o excedente do MESMO
	# golpe que a derrubou perfura o osso exposto sem o piso de 1 que protege o resto do
	# corpo — o piso é para vizinhos, e osso e peça não são vizinhos, são a mesma pilha
	# (Docs/feature_montagem.md §7).
	var exposed: BodyPart = null
	if target.hp == 0 and target.covers_parent and target.parent != null and target.parent.is_intact():
		exposed = target.parent
		var host_before := exposed.hp
		remaining = exposed.absorb(remaining)
		dealt += host_before - exposed.hp
		if exposed.hp == 0:
			destroyed.append(exposed)

	# 2. O excedente se dissipa pelo corpo, ferindo sem destruir.
	var others := intact_parts()
	others.erase(target)
	if exposed != null:
		others.erase(exposed)
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
