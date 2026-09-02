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
	for key in Loadout.SLOT_KEYS:
		var part := loadout.get_part(key)
		slots[key] = part.id if part != null else ""
	return {
		"pilot_name": loadout.pilot_name,
		"body_color": loadout.body_color.to_html(false),
		"accent_color": loadout.accent_color.to_html(false),
		"arm_left_mode": int(loadout.arm_left_mode),
		"arm_right_mode": int(loadout.arm_right_mode),
		"slots": slots,
	}


func _from_dict(data: Dictionary, base: Loadout) -> Loadout:
	base.pilot_name = String(data.get("pilot_name", base.pilot_name))
	if data.has("body_color"):
		base.body_color = Color(String(data["body_color"]))
	if data.has("accent_color"):
		base.accent_color = Color(String(data["accent_color"]))
	base.arm_left_mode = int(data.get("arm_left_mode", 0)) as Loadout.ArmMode
	base.arm_right_mode = int(data.get("arm_right_mode", 0)) as Loadout.ArmMode

	var slots: Dictionary = data.get("slots", {})
	for key in Loadout.SLOT_KEYS:
		var id := String(slots.get(key, ""))
		if id.is_empty():
			base.set_part(key, null)
			continue
		var part := PartCatalog.get_part(id)
		if part == null:
			push_warning("Peça '%s' não existe mais — encaixe %s ficou vazio." % [id, key])
		base.set_part(key, part)
	return base
