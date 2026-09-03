## O hangar: onde o robô é montado antes da batalha.
##
## Aqui o jogador se vê, se nomeia, escolhe as cores e decide as peças. Tudo que muda
## aqui é resolvido na hora — atributos, carga e o desenho do robô — e gravado em
## user:// ao entrar na batalha.
extends Node2D

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

const BODY_COLORS := [
	"4f9dde", "d95a52", "5ec27a", "c9a227", "9b6ede", "d1743f", "3fb8b0", "8a94a6",
]
const ACCENT_COLORS := [
	"8ef0ff", "ffb85c", "9dffb0", "ffe680", "e0b3ff", "ff9d7a", "7affe6", "ffffff",
]

enum Tab { PARTS, CHASSIS, COLORS }

@onready var sprite: RobotSprite = $Robot/Sprite
@onready var name_edit: LineEdit = %NameEdit
@onready var stats_label: Label = %StatsLabel
@onready var load_bar: ProgressBar = %LoadBar
@onready var load_text: Label = %LoadText
@onready var tabs: HBoxContainer = %Tabs
@onready var content: VBoxContainer = %Content
@onready var battle_button: Button = %BattleButton

var loadout: Loadout
var _tab: Tab = Tab.PARTS
## Encaixe aberto no momento; vazio quando a lista de encaixes está visível.
var _open_slot := ""
## Aviso da última troca de exoesqueleto, quando ela desencaixou alguma peça.
var _notice := ""


func _ready() -> void:
	loadout = PlayerLoadout.current
	if loadout == null:
		loadout = load(PlayerLoadout.DEFAULT_LOADOUT).duplicate(true)

	name_edit.text = loadout.pilot_name
	name_edit.text_changed.connect(func(text: String) -> void:
		loadout.pilot_name = text.strip_edges())

	_build_tabs()
	battle_button.pressed.connect(_on_battle_pressed)
	_refresh()


# --- Topo: atributos e carga --------------------------------------------

func _refresh() -> void:
	var stats := loadout.resolve()
	var body := Body.from_loadout(loadout)
	stats_label.text = "    ".join(_stat_bits(stats, body))

	var capacity := loadout.stat("capacity") if loadout.chassis != null else 1
	load_bar.max_value = capacity
	load_bar.value = mini(loadout.total_weight(), capacity)
	load_text.text = "%d/%d" % [loadout.total_weight(), capacity]

	var over := not loadout.is_valid()
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f87171") if over else Color("60a5fa")
	fill.set_corner_radius_all(8)
	load_bar.add_theme_stylebox_override("fill", fill)

	battle_button.disabled = over
	battle_button.text = "CARGA EXCEDIDA" if over else "BATALHAR"

	sprite.body_color = loadout.body_color
	sprite.accent_color = loadout.accent_color
	sprite.left_arm_intact = true
	sprite.right_arm_intact = true
	sprite.left_leg_intact = true
	sprite.right_leg_intact = true
	sprite.set_loadout(loadout)

	_rebuild_content()


## "FOR 22    AGI 22    DEF 8    VIDA 174    EN 30" — um item por atributo do esquema
## que alimenta o combate, com VIDA (que não é um StatDef; vem das hitboxes do Body)
## encaixada logo depois da defesa, como sempre esteve.
func _stat_bits(stats: UnitStats, body: Body) -> Array[String]:
	var bits: Array[String] = []
	for def in loadout.schema().stats:
		if def.maps_to.is_empty():
			continue
		bits.append("%s %d" % [def.abbreviation, stats.get(def.maps_to)])
		if def.key == "defense":
			bits.append("VIDA %d" % body.max_total_hp())
	return bits


# --- Abas ---------------------------------------------------------------

func _build_tabs() -> void:
	for entry in [[Tab.PARTS, "Peças"], [Tab.CHASSIS, "Exoesqueleto"], [Tab.COLORS, "Cores"]]:
		var button := Button.new()
		button.text = String(entry[1])
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 36)
		var tab: Tab = entry[0]
		button.pressed.connect(func() -> void:
			_tab = tab
			_open_slot = ""
			_refresh())
		tabs.add_child(button)
	_sync_tab_buttons()


func _sync_tab_buttons() -> void:
	var index := 0
	for child in tabs.get_children():
		if child is Button:
			(child as Button).button_pressed = index == int(_tab)
			index += 1


func _rebuild_content() -> void:
	for child in content.get_children():
		child.queue_free()
	_sync_tab_buttons()

	if _tab == Tab.COLORS:
		_build_colors()
	elif _tab == Tab.CHASSIS:
		_build_chassis_list()
	elif _open_slot.is_empty():
		_build_slot_list()
	else:
		_build_part_list(_open_slot)


# --- Aba Peças ----------------------------------------------------------

func _build_slot_list() -> void:
	for key in loadout.slot_keys():
		var part := loadout.get_part(key)
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 32)
		row.custom_minimum_size = Vector2(0, 84)

		var detail := part.display_name if part != null else "—"
		if (key == "arm_left" or key == "arm_right") and part != null:
			var mount := loadout.mount_for(key)
			detail = "%s  (%s)" % [detail, mount.label if mount != null else ""]
		row.text = "%s\n%s" % [loadout.slot_label(key), detail]

		row.pressed.connect(func() -> void:
			_open_slot = key
			_rebuild_content())
		content.add_child(row)


func _build_part_list(key: String) -> void:
	var header := Label.new()
	header.text = loadout.slot_label(key)
	header.add_theme_font_size_override("font_size", 34)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	content.add_child(_make_option(key, null, "Vazio", ""))
	var is_arm := key == "arm_left" or key == "arm_right"
	for part in loadout.options_for(key):
		# Nos braços, a peça escolhida é que define o modo — então o modo vai no rótulo.
		var title := part.display_name
		if is_arm:
			title = "%s  ·  %s" % [title, Part.slot_label(part.slot).to_lower()]
		content.add_child(_make_option(key, part, title, _delta_text(key, part)))

	var back := Button.new()
	back.text = "Voltar"
	back.add_theme_font_size_override("font_size", 34)
	back.pressed.connect(func() -> void:
		_open_slot = ""
		_rebuild_content())
	content.add_child(back)


func _make_option(key: String, part: Part, title: String, detail: String) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 30)
	button.custom_minimum_size = Vector2(0, 88)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = title if detail.is_empty() else "%s\n%s" % [title, detail]
	button.disabled = loadout.get_part(key) == part
	button.pressed.connect(func() -> void:
		loadout.equip(key, part)
		_open_slot = ""
		_refresh())
	return button


## O que trocar para esta peça faz com os atributos — é o que transforma a montagem
## numa decisão em vez de tentativa e erro.
func _delta_text(key: String, part: Part) -> String:
	var before := loadout.resolve()
	var before_weight := loadout.total_weight()
	var previous := loadout.get_part(key)

	loadout.equip(key, part)
	var after := loadout.resolve()
	var after_weight := loadout.total_weight()
	loadout.equip(key, previous)

	var bits: Array[String] = []
	for def in loadout.schema().stats:
		if not def.maps_to.is_empty():
			_append_delta(bits, def.abbreviation, after.get(def.maps_to) - before.get(def.maps_to))
	_append_delta(bits, "PESO", after_weight - before_weight)
	bits.append("RES %d" % part.resistance)
	for action_id in part.grants_actions:
		bits.append("→ %s" % Actions.action_name(action_id))
	return "  ".join(bits)


func _append_delta(bits: Array[String], label: String, value: int) -> void:
	if value != 0:
		bits.append("%s %+d" % [label, value])


# --- Aba Exoesqueleto ---------------------------------------------------

func _build_chassis_list() -> void:
	if not _notice.is_empty():
		var warning := Label.new()
		warning.text = _notice
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.add_theme_font_size_override("font_size", 28)
		warning.add_theme_color_override("font_color", Color("f87171"))
		content.add_child(warning)

	for chassis in ChassisCatalog.all():
		var current := loadout.chassis != null and loadout.chassis.id == chassis.id
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 30)
		button.custom_minimum_size = Vector2(0, 104)
		button.text = "%s\n%s" % [chassis.display_name, _chassis_detail(chassis)]
		button.disabled = current
		button.pressed.connect(func() -> void: _pick_chassis(chassis))
		content.add_child(button)


## "FOR 18  AGI 4  DEF 12  EN 18  CARGA 250  ·  sem Costas 2  ·  recusa AGILE"
func _chassis_detail(chassis: Chassis) -> String:
	var bits: Array[String] = []
	for def in loadout.schema().stats:
		bits.append("%s %d" % [def.abbreviation, chassis.base_stats.get(def.key, def.default_base)])
	var line := "  ".join(bits)

	if not chassis.disabled_slots.is_empty():
		var labels: Array[String] = []
		for key in chassis.disabled_slots:
			labels.append(loadout.slot_label(key))
		line = "%s  ·  sem %s" % [line, ", ".join(labels)]
	if not chassis.restricted_tags.is_empty():
		line = "%s  ·  recusa %s" % [line, ", ".join(chassis.restricted_tags)]
	return line


## Trocar de exoesqueleto revalida a montagem na hora: o que o novo não comporta sai,
## e o jogador é avisado de o que saiu em vez de descobrir na batalha.
func _pick_chassis(chassis: Chassis) -> void:
	if loadout.chassis != null and loadout.chassis.id == chassis.id:
		return
	loadout.chassis = chassis

	var dropped := loadout.revalidate()
	if dropped.is_empty():
		_notice = ""
	else:
		var names: Array[String] = []
		for part in dropped:
			names.append(part.display_name)
		_notice = "%s não cabe no %s e foi desencaixada." % [
			", ".join(names), chassis.display_name] if dropped.size() == 1 else \
			"%s não cabem no %s e foram desencaixadas." % [
			", ".join(names), chassis.display_name]
	_refresh()


# --- Aba Cores ----------------------------------------------------------

func _build_colors() -> void:
	content.add_child(_color_row("Corpo", BODY_COLORS, loadout.body_color,
		func(color: Color) -> void: loadout.body_color = color))
	content.add_child(_color_row("Detalhe", ACCENT_COLORS, loadout.accent_color,
		func(color: Color) -> void: loadout.accent_color = color))


func _color_row(title: String, palette: Array, selected: Color, apply: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 32)
	box.add_child(label)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)

	for hex in palette:
		var color := Color(String(hex))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "●" if color.is_equal_approx(selected) else ""

		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(14)
		if color.is_equal_approx(selected):
			style.set_border_width_all(5)
			style.border_color = Color.WHITE
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", Color(0, 0, 0, 0.75))

		button.pressed.connect(func() -> void:
			apply.call(color)
			_refresh())
		grid.add_child(button)
	return box


# --- Sair para a batalha ------------------------------------------------

func _on_battle_pressed() -> void:
	if not loadout.is_valid():
		return
	if loadout.pilot_name.strip_edges().is_empty():
		loadout.pilot_name = "R-7"
	PlayerLoadout.save(loadout)
	get_tree().change_scene_to_file(BATTLE_SCENE)
