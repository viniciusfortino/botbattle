## A montagem do jogador (autoload `PlayerLoadout`).
##
## Guarda o robô entre o hangar e a batalha, e entre execuções do jogo. O save grava
## **ids** de peça, não recursos serializados: assim mexer nos .tres do catálogo nunca
## corrompe o arquivo salvo — uma peça que sumiu vira encaixe vazio, com aviso.
extends Node

const SAVE_PATH := "user://loadout.json"
const DEFAULT_LOADOUT := "res://units/r7.tres"

var current: Loadout


func _ready() -> void:
	current = load_saved()


## Carrega o save, ou devolve uma cópia da montagem padrão.
func load_saved() -> Loadout:
	var base: Loadout = load(DEFAULT_LOADOUT).duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return base

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Não foi possível ler %s" % SAVE_PATH)
		return base
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save de montagem inválido — usando o padrão.")
		return base

	return _from_dict(parsed as Dictionary, base)


func save(loadout: Loadout) -> void:
	current = loadout
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível gravar %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_to_dict(loadout), "\t"))
	file.close()


func _to_dict(loadout: Loadout) -> Dictionary:
	var slots := {}
	for key in loadout.slot_keys():
		var part := loadout.get_part(key)
		slots[key] = part.id if part != null else ""
	return {
		"pilot_name": loadout.pilot_name,
		"chassis": loadout.chassis.id if loadout.chassis != null else "",
		"body_color": loadout.body_color.to_html(false),
		"accent_color": loadout.accent_color.to_html(false),
		"slots": slots,
	}


func _from_dict(data: Dictionary, base: Loadout) -> Loadout:
	base.pilot_name = String(data.get("pilot_name", base.pilot_name))
	if data.has("body_color"):
		base.body_color = Color(String(data["body_color"]))
	if data.has("accent_color"):
		base.accent_color = Color(String(data["accent_color"]))

	# Um save que aponta para um exoesqueleto que sumiu do catálogo cai no de fábrica,
	# do mesmo jeito que uma peça removida vira encaixe vazio.
	var chassis_id := String(data.get("chassis", ""))
	if not chassis_id.is_empty():
		var chassis := ChassisCatalog.get_chassis(chassis_id)
		if chassis == null:
			push_warning("Exoesqueleto '%s' não existe mais — usando o de fábrica." % chassis_id)
			chassis = ChassisCatalog.default_chassis()
		if chassis != null:
			base.chassis = chassis

	# "arm_left_mode"/"arm_right_mode" podem sobrar de um save antigo — não lemos mais
	# essas chaves (o modo agora é derivado da peça), e um Dictionary ignora o que não
	# se pede.
	var slots: Dictionary = data.get("slots", {})
	for key in base.slot_keys():
		var id := String(slots.get(key, ""))
		if id.is_empty():
			base.set_part(key, null)
			continue
		var part := PartCatalog.get_part(id)
		if part == null:
			push_warning("Peça '%s' não existe mais — encaixe %s ficou vazio." % [id, key])
		base.set_part(key, part)

	for dropped in base.revalidate():
		push_warning("'%s' não cabe no exoesqueleto salvo — encaixe liberado." % dropped.display_name)
	return base
