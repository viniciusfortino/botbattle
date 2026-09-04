## A montagem de um robô: kit, peças montadas, nome e cores.
##
## É o que o hangar edita e o que a batalha consome. Nada aqui conhece combate: a ponte
## é `resolve()`, que devolve o `UnitStats` que o combate já sabe ler.
class_name Loadout
extends Resource

@export var pilot_name: String = "R-7"

## O kit de fábrica desta montagem (Docs/feature_montagem.md).
@export var kit: Kit:
	set(value):
		kit = value
		_resolved.clear()

## Cor não é mais escolha do jogador (§7 do plano PixelLab) — o que sobra aqui é o
## dado autorado por unidade que UnitStats.resolve() usa para VFX (feixe do laser,
## número de "Guarda"); o robô em si é sempre a arte do PixelLab.
var body_color: Color = Color("4f9dde")
var accent_color: Color = Color("8ef0ff")

## Caminho de socket → peça (`"arm_left/main"`, `"arm_left/main/rail_1"`). Some da
## árvore quem não está aqui — sem entrada distinta para "vazio".
@export var mounted: Dictionary[String, Part] = {}

const DEFAULT_SCHEMA_PATH := "res://content/stats/default.tres"

## Os valores da última chamada a resolve(), por chave de atributo — inclusive os que
## não têm `maps_to` e por isso não aparecem em UnitStats (hoje só "capacity").
## Atributos resolvidos da última chamada a `resolve()`. Toda mudança na montagem o
## esvazia — senão `stat()` devolveria o número do exoesqueleto anterior.
var _resolved: Dictionary = {}


## Todos os sockets desta montagem, ocupados ou não, em profundidade: cada entrada é
## {path, part, parent_path, socket}. `part` é null quando o socket está vazio. Um
## socket só aparece se o que o publica está montado — vazio um nível não esconde o de
## baixo por engano, porque não existe "de baixo" sem a peça que o publica (§4 do
## feature). `parent_path` vazio = publicado direto por um osso do esqueleto.
func available_sockets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kit == null or kit.skeleton == null:
		return out
	for bone in kit.skeleton.bones:
		for socket in bone.sockets:
			_walk_sockets("%s/%s" % [bone.key, socket.key], "", socket, out)
	return out


func _walk_sockets(path: String, parent_path: String, socket: SocketDef, out: Array[Dictionary]) -> void:
	var part: Part = mounted.get(path)
	out.append({"path": path, "part": part, "parent_path": parent_path, "socket": socket})
	if part != null:
		for child_socket in part.sockets:
			_walk_sockets("%s/%s" % [path, child_socket.key], path, child_socket, out)


## Só os sockets ocupados de `available_sockets()` — o que `resolve()`, `Body` e
## `RobotSprite` de fato percorrem.
func mounted_parts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in available_sockets():
		if entry["part"] != null:
			out.append(entry)
	return out


## Encaixa uma peça no caminho de socket, ou esvazia (com null). Trocar ou esvaziar
## derruba tudo que estava montado nos sockets dela — aqueles sockets deixam de existir
## junto (§4 do feature: um socket só existe porque o que o publica está montado).
## Devolve o que caiu por causa disso, para quem chamou poder avisar.
func mount(path: String, part: Part) -> Array[Part]:
	_resolved.clear()
	var dropped: Array[Part] = []
	var prefix := "%s/" % path
	for key in mounted.keys():
		if key.begins_with(prefix):
			dropped.append(mounted[key])
			mounted.erase(key)
	if part == null:
		mounted.erase(path)
	else:
		mounted[path] = part
	return dropped


## As peças que concedem ações, com a chave de hitbox de cada uma —
## `Combatant.available_actions()` lê daqui.
func granting_parts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in mounted_parts():
		out.append({"part": entry["part"], "key": entry["path"]})
	return out


func total_weight() -> int:
	var sum := 0
	for entry in mounted_parts():
		sum += (entry["part"] as Part).weight
	return sum


## Quanto da capacidade está ocupada (pode passar de 1.0 — aí a montagem é inválida).
func load_ratio() -> float:
	var capacity := stat("capacity")
	if kit == null or capacity <= 0:
		return 0.0
	return float(total_weight()) / float(capacity)


func is_valid() -> bool:
	# O jogo permite lutar com overweight (load_ratio > 1.0),
	# a penalidade é aplicada na agilidade.
	return kit != null


## Penalidade de carga na agilidade.
func load_penalty() -> float:
	var ratio = load_ratio()
	if ratio <= 0.5:
		return 1.0
	elif ratio <= 1.0:
		# De 50% a 100% de carga, agilidade cai até -30%
		return 1.0 - 0.3 * ((ratio - 0.5) / 0.5)
	else:
		# Overweight: acima de 100%, agilidade despenca rapidamente
		var over = clampf((ratio - 1.0) / 0.5, 0.0, 1.0)
		return 0.7 - (0.5 * over)


## O vocabulário de atributos desta montagem. `Kit` não tem schema próprio — todo kit
## usa o mesmo, por ora (nenhum conteúdo hoje precisa de outro).
func schema() -> StatSchema:
	return load(DEFAULT_SCHEMA_PATH)


## O valor resolvido de um atributo. Para os que têm `maps_to` é o mesmo número que
## está em UnitStats; para os que não têm (hoje só "capacity") é a única forma de lê-lo.
func stat(key: String) -> int:
	if _resolved.is_empty():
		resolve()
	return int(_resolved.get(key, 0))


## A ponte com o combate: os atributos da montagem no formato que a batalha já lê.
## `lost` são as peças destruídas, que deixam de somar. `capacity` é só mais um
## atributo — pode vir do osso **e** de peças (a carcaça reforçada de um MK-II soma, a
## carenagem leve de um MK-III subtrai) —, só que resolvida numa passada própria, cedo
## demais para sentir a própria penalidade de carga, e sem excluir peças perdidas: senão
## ela passaria a depender das peças que ela mesma limita (§10.3 do feature_anatomy.md).
func resolve(lost: Array = []) -> UnitStats:
	var stats := UnitStats.new()
	stats.display_name = pilot_name
	stats.body_color = body_color
	stats.accent_color = accent_color

	var stat_schema := schema()
	var values := {}
	for def in stat_schema.stats:
		values[def.key] = 0

	if kit != null:
		for bone in kit.skeleton.bones:
			values["capacity"] = int(values.get("capacity", 0)) + int(bone.modifiers.get("capacity", 0))
	for entry in mounted_parts():
		var mounted_part: Part = entry["part"]
		values["capacity"] = int(values.get("capacity", 0)) + int(mounted_part.modifiers.get("capacity", 0))
	var capacity_def := stat_schema.stat("capacity")
	if capacity_def != null:
		values["capacity"] = maxi(capacity_def.minimum, int(values.get("capacity", 0)))
	_resolved = values

	# A penalidade de carga é o primeiro multiplicador — as peças entram junto dela.
	var scale := {"agility": load_penalty()}

	if kit != null:
		for bone in kit.skeleton.bones:
			for key in bone.modifiers:
				if key == "capacity":
					continue
				values[key] = int(values.get(key, 0)) + int(bone.modifiers[key])
	for entry in mounted_parts():
		var part: Part = entry["part"]
		if lost.has(part):
			continue
		for key in part.modifiers:
			if key == "capacity":
				continue
			values[key] = int(values.get(key, 0)) + part.modifiers[key]
		for key in part.scalers:
			scale[key] = float(scale.get(key, 1.0)) * part.scalers[key]

	for def in stat_schema.stats:
		if def.key == "capacity":
			continue
		var value := maxi(def.minimum, roundi(values[def.key] * float(scale.get(def.key, 1.0))))
		values[def.key] = value
		if not def.maps_to.is_empty():
			stats.set(def.maps_to, value)
	_resolved = values
	return stats
