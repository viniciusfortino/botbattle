## A montagem de um robô: exoesqueleto, peças encaixadas, nome e cores.
##
## É o que o hangar edita e o que a batalha consome. Nada aqui conhece combate: a ponte
## é `resolve()`, que devolve o `UnitStats` que o combate já sabe ler.
class_name Loadout
extends Resource

@export var pilot_name: String = "R-7"
@export var chassis: Chassis:
	set(value):
		chassis = value
		_resolved.clear()

## Cor não é mais escolha do jogador (§7 do plano PixelLab) — o que sobra aqui é o
## dado autorado por unidade que UnitStats.resolve() usa para VFX (feixe do laser,
## número de "Guarda"); o robô em si é sempre a arte do PixelLab.
var body_color: Color = Color("4f9dde")
var accent_color: Color = Color("8ef0ff")

## Encaixe → peça. As chaves vêm da anatomia; encaixe vazio não aparece no dicionário.
@export var slots: Dictionary[String, Part] = {}

const DEFAULT_SCHEMA_PATH := "res://stats/default.tres"
const DEFAULT_ANATOMY_PATH := "res://anatomy/humanoid.tres"

## Os valores da última chamada a resolve(), por chave de atributo — inclusive os que
## não têm `maps_to` e por isso não aparecem em UnitStats (hoje só "capacity").
## Atributos resolvidos da última chamada a `resolve()`. Toda mudança na montagem o
## esvazia — senão `stat()` devolveria o número do exoesqueleto anterior.
var _resolved: Dictionary = {}


func get_part(key: String) -> Part:
	return slots.get(key)


## Um encaixe vazio some do dicionário em vez de guardar null — é o que mantém
## `slots` como a lista exata do que está montado.
func set_part(key: String, part: Part) -> void:
	_resolved.clear()
	if part == null:
		slots.erase(key)
	else:
		slots[key] = part


## A forma deste robô — do chassi, ou o padrão do jogo quando ele não aponta nenhuma.
func anatomy() -> Anatomy:
	if chassis != null and chassis.anatomy != null:
		return chassis.anatomy
	return load(DEFAULT_ANATOMY_PATH)


## A vida de fábrica de um osso: a sobrescrita do chassi, senão o valor do próprio osso.
func resistance_for(bone: BoneDef) -> int:
	if chassis != null and chassis.bone_resistance.has(bone.key):
		return chassis.bone_resistance[bone.key]
	return bone.resistance


## A peça que substitui esta parte estrutural inteira, se houver (braço ou perna
## trocados por completo) — é ela que dá a vida e o multiplicador de dano da hitbox.
func part_replacing(bone_key: String) -> Part:
	var atm := anatomy()
	for slot_key in atm.slot_keys():
		var def := atm.slot(slot_key)
		if def.host_bone != bone_key:
			continue
		var piece := get_part(slot_key)
		if piece == null:
			continue
		var mount := atm.mount_for(slot_key, piece)
		if mount != null and mount.replaces_host:
			return piece
	return null


## Este encaixe já virou a hitbox estrutural do osso que o sustenta (braço/perna
## trocados por inteiro), em vez de pendurar nele?
func replaces_host(slot_key: String) -> bool:
	var piece := get_part(slot_key)
	if piece == null:
		return false
	var mount := anatomy().mount_for(slot_key, piece)
	return mount != null and mount.replaces_host


## Todos os encaixes desta montagem, na ordem da anatomia, menos os que o chassi atual
## não tem.
func slot_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in anatomy().slot_keys():
		if chassis == null or not chassis.disabled_slots.has(key):
			keys.append(key)
	return keys


## Rótulo do encaixe para a UI do hangar — do SlotDef correspondente na anatomia.
func slot_label(key: String) -> String:
	var def := anatomy().slot(key)
	return def.label if def != null else key


## Os tipos de peça que este encaixe aceita agora, somando todos os modos de montagem.
func accepted_slots(key: String) -> Array[Part.Slot]:
	return anatomy().accepted_slots(key)


## Como a peça deste encaixe está montada agora (null se vazio) — braço de fábrica,
## antebraço trocado, braço completo…
func mount_for(key: String) -> MountDef:
	return anatomy().mount_for(key, get_part(key))


## As peças que cabem neste encaixe. Nos braços entram os três modos de uma vez —
## escolher a peça é que define se o braço fica de fábrica, meio trocado ou inteiro novo.
func options_for(key: String) -> Array[Part]:
	if chassis != null and chassis.disabled_slots.has(key):
		return []

	var list: Array[Part] = []
	for slot in accepted_slots(key):
		list.append_array(PartCatalog.for_slot(slot))

	return list.filter(accepts)


## O exoesqueleto atual aceita esta peça? Só as tags que ele recusa entram aqui — se
## o encaixe existe é pergunta de `slot_keys()`.
func accepts(part: Part) -> bool:
	if chassis == null or part == null:
		return true
	for tag in part.tags:
		if chassis.restricted_tags.has(tag):
			return false
	return true


## Tira da montagem o que o exoesqueleto atual não comporta: peça em encaixe que ele
## não tem, ou peça com tag que ele recusa. Devolve o que saiu, para quem chamou poder
## avisar em vez de a peça sumir em silêncio.
func revalidate() -> Array[Part]:
	var dropped: Array[Part] = []
	var available := slot_keys()
	for key in slots.keys():
		var part: Part = slots[key]
		if part == null:
			continue
		if not available.has(key) or not accepts(part):
			dropped.append(part)
			slots.erase(key)
	_resolved.clear()
	return dropped


## Encaixa uma peça (ou esvazia o encaixe, com null). O modo de montagem não é mais
## estado — quem quiser saber como o braço está montado agora chama mount_for(key).
func equip(key: String, part: Part) -> void:
	set_part(key, part)


## Todas as peças encaixadas, ignorando as indicadas em `lost`.
func active_parts(lost: Array = []) -> Array[Part]:
	var parts: Array[Part] = []
	for key in slot_keys():
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
	var capacity := stat("capacity")
	if chassis == null or capacity <= 0:
		return 0.0
	return float(total_weight()) / float(capacity)


func is_valid() -> bool:
	# O jogo permite lutar com overweight (load_ratio > 1.0),
	# a penalidade é aplicada na agilidade.
	return chassis != null


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


## O vocabulário de atributos desta montagem — do chassi, ou o padrão do jogo quando
## ele não aponta nenhum (ex: um Chassis.new() de teste).
func schema() -> StatSchema:
	if chassis != null and chassis.schema != null:
		return chassis.schema
	return load(DEFAULT_SCHEMA_PATH)


## O valor resolvido de um atributo. Para os que têm `maps_to` é o mesmo número que
## está em UnitStats; para os que não têm (hoje só "capacity") é a única forma de lê-lo.
func stat(key: String) -> int:
	if _resolved.is_empty():
		resolve()
	return int(_resolved.get(key, 0))


## A ponte com o combate: os atributos da montagem no formato que a batalha já lê.
## `lost` são as peças destruídas, que deixam de somar.
func resolve(lost: Array = []) -> UnitStats:
	var stats := UnitStats.new()
	stats.display_name = pilot_name
	stats.body_color = body_color
	stats.accent_color = accent_color

	var stat_schema := schema()
	var values := {}
	for def in stat_schema.stats:
		values[def.key] = chassis.base_stats.get(def.key, def.default_base) if chassis != null else def.default_base

	# A carga se resolve sozinha, sem escalonadores e sem excluir peças perdidas — senão
	# ela passaria a depender das peças que ela mesma limita (feature_anatomy.md §10.3).
	for part in active_parts():
		values["capacity"] = int(values.get("capacity", 0)) + part.modifiers.get("capacity", 0)
	var capacity_def := stat_schema.stat("capacity")
	if capacity_def != null:
		values["capacity"] = maxi(capacity_def.minimum, values["capacity"])
	_resolved = values

	# A penalidade de carga é o primeiro multiplicador — as peças entram junto dela.
	var scale := {"agility": load_penalty()}

	for part in active_parts(lost):
		for key in part.modifiers:
			if key == "capacity":
				continue
			values[key] = int(values.get(key, 0)) + part.modifiers[key]
		for key in part.scalers:
			if key == "capacity":
				continue
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
