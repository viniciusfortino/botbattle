## Painel de depuração: mostra a vida de cada hitbox de um combatente.
##
## Só aparece quando a flag global `Debug.enabled` está ligada (F3 alterna).
class_name HitboxDebugPanel
extends PanelContainer

const OK_COLOR := Color("4ade80")
const WARN_COLOR := Color("fbbf24")
const HURT_COLOR := Color("f87171")
const DEAD_COLOR := Color("3f4451")
const LABEL_SIZE := 24

var _combatant: Combatant
var _title: Label
var _rows: Array[Dictionary] = []
var _column: VBoxContainer


func _ready() -> void:
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 2)
	add_child(_column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("8ef0ff"))
	_column.add_child(_title)

	visible = Debug.enabled
	Debug.changed.connect(func(on: bool) -> void: visible = on)


## Passa a espelhar as hitboxes deste combatente.
func track(combatant: Combatant) -> void:
	_combatant = combatant
	_build_rows()
	combatant.hp_changed.connect(func(_c: int, _m: int) -> void: refresh())
	combatant.part_hit.connect(_on_part_hit)
	refresh()


func refresh() -> void:
	if _combatant == null:
		return
	_title.text = "DEBUG · HITBOXES — %s  (%d/%d)" % [
		_combatant.stats.display_name, _combatant.hp, _combatant.max_hp]

	for row in _rows:
		var part: BodyPart = row["part"]
		var bar: ProgressBar = row["bar"]
		bar.max_value = part.max_hp
		bar.value = part.hp
		row["value"].text = "%d/%d" % [part.hp, part.max_hp]

		var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		fill.bg_color = _color_for(part)
		row["name"].modulate.a = 0.45 if not part.is_intact() else 1.0


func _build_rows() -> void:
	for row in _rows:
		row["line"].queue_free()
	_rows.clear()

	for part in _combatant.body.parts:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)

		var name_label := Label.new()
		name_label.text = _name_with_weapon(part)
		name_label.custom_minimum_size = Vector2(290, 0)
		name_label.add_theme_font_size_override("font_size", LABEL_SIZE)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)

		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(120, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", LABEL_SIZE)

		line.add_child(name_label)
		line.add_child(bar)
		line.add_child(value_label)
		_column.add_child(line)

		_rows.append({
			"part": part, "line": line, "bar": bar,
			"name": name_label, "value": value_label,
		})


func _on_part_hit(info: Dictionary) -> void:
	refresh()
	var hit: BodyPart = info.get("part")
	for row in _rows:
		if row["part"] == hit:
			var line: HBoxContainer = row["line"]
			line.modulate = Color(1.6, 0.7, 0.7)
			create_tween().tween_property(line, "modulate", Color.WHITE, 0.45)
			return


## "Braço esq. · plasma" — deixa claro qual arma cai junto com a hitbox.
func _name_with_weapon(part: BodyPart) -> String:
	if part.source == null:
		return part.display_name
	for action_id in part.source.grants_actions:
		var weapon := Actions.weapon_of(action_id)
		if not weapon.is_empty():
			return "%s · %s" % [part.display_name, weapon]
	return part.display_name


func _color_for(part: BodyPart) -> Color:
	match part.condition():
		BodyPart.Condition.DESTROYED:
			return DEAD_COLOR
		BodyPart.Condition.CRITICAL:
			return HURT_COLOR
		BodyPart.Condition.DAMAGED:
			return WARN_COLOR
		_:
			return OK_COLOR
