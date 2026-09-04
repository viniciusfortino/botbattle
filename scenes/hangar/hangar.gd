## O hangar: onde o robô é montado antes da batalha.
##
## Aqui o jogador se vê, se nomeia e decide as peças. Tudo que muda aqui é resolvido na
## hora — atributos, carga e o desenho do robô — e gravado em user:// ao entrar na
## batalha. A cor não é mais escolha do jogador (§7 do plano PixelLab); o robô é
## sempre a arte do PixelLab, na visão montada.
extends Node2D

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

enum Tab { PARTS, KIT }

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
## Socket aberto no momento (caminho completo); vazio quando a lista está visível.
var _open_slot := ""
## Aviso da última troca de peça ou de kit, quando ela desencaixou algo.
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

	var capacity := loadout.stat("capacity") if loadout.is_valid() else 1
	load_bar.max_value = capacity
	load_bar.value = mini(loadout.total_weight(), capacity)
	load_text.text = "%d/%d" % [loadout.total_weight(), capacity]

	# Sobrecarga não impede batalhar (ver o comentário de `Loadout.is_valid()`) — é só
	# aviso de que a agilidade já está pagando o preço.
	var overloaded := loadout.load_ratio() > 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f87171") if overloaded else Color("60a5fa")
	fill.set_corner_radius_all(8)
	load_bar.add_theme_stylebox_override("fill", fill)

	battle_button.disabled = not loadout.is_valid()
	battle_button.text = "BATALHAR"

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
	for entry in [[Tab.PARTS, "Peças"], [Tab.KIT, "Exoesqueleto"]]:
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

	if _tab == Tab.KIT:
		_build_kit_list()
	elif _open_slot.is_empty():
		_build_socket_list()
	else:
		_build_part_list(_open_slot)


# --- Aba Peças ----------------------------------------------------------

## A árvore de sockets da montagem atual, achatada em linhas — uma por socket
## disponível, ocupado ou não. Um socket só aparece se o que o publica está montado:
## tirar a carcaça esconde os rails dela junto (§4 do feature — não existe socket sem o
## que o publica).
func _build_socket_list() -> void:
	if not _notice.is_empty():
		content.add_child(_notice_label())

	for entry in loadout.available_sockets():
		var path: String = entry["path"]
		var socket: SocketDef = entry["socket"]
		var part: Part = entry["part"]

		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 32)
		row.custom_minimum_size = Vector2(0, 84)

		var depth: int = path.count("/") - 1
		var indent := "    ".repeat(maxi(0, depth))
		row.text = "%s%s\n%s%s" % [
			indent, _socket_label(path, socket), indent, part.display_name if part != null else "—"]

		row.pressed.connect(func() -> void:
			_open_slot = path
			_rebuild_content())
		content.add_child(row)


## "main" empresta o nome do osso (Cabeça, Braço esq.) — o próprio socket não duplica
## esse texto (`SocketDef.label` fica vazio nele, ver combat/socket_def.gd).
func _socket_label(path: String, socket: SocketDef) -> String:
	if socket.key == "main":
		var bone := loadout.kit.skeleton.bone(path.split("/")[0])
		return bone.display_name if bone != null else path
	return socket.label if not socket.label.is_empty() else socket.key


func _notice_label() -> Label:
	var warning := Label.new()
	warning.text = _notice
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 28)
	warning.add_theme_color_override("font_color", Color("f87171"))
	return warning


## As opções de um socket saem de `PartCatalog` filtrado pelo `standard` dele, não por
## `Part.Slot` — é a peça que decide onde encaixa, nunca o anfitrião (§4 do feature).
func _build_part_list(path: String) -> void:
	var socket := _socket_at(path)
	if socket == null:
		_open_slot = ""
		_rebuild_content()
		return

	var header := Label.new()
	header.text = _socket_label(path, socket)
	header.add_theme_font_size_override("font_size", 34)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(header)

	content.add_child(_make_option(path, null, "Vazio", ""))
	for part in PartCatalog.for_standard(socket.standard):
		content.add_child(_make_option(path, part, part.display_name, _delta_text(path, part)))

	var back := Button.new()
	back.text = "Voltar"
	back.add_theme_font_size_override("font_size", 34)
	back.pressed.connect(func() -> void:
		_open_slot = ""
		_rebuild_content())
	content.add_child(back)


func _socket_at(path: String) -> SocketDef:
	for entry in loadout.available_sockets():
		if entry["path"] == path:
			return entry["socket"]
	return null


func _make_option(path: String, part: Part, title: String, detail: String) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 30)
	button.custom_minimum_size = Vector2(0, 88)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = title if detail.is_empty() else "%s\n%s" % [title, detail]
	button.disabled = loadout.mounted.get(path) == part
	button.pressed.connect(func() -> void:
		var dropped := loadout.mount(path, part)
		_open_slot = ""
		_notice = _dropped_notice(dropped) if not dropped.is_empty() else ""
		_refresh())
	return button


## O que trocar para esta peça faz com os atributos — é o que transforma a montagem
## numa decisão em vez de tentativa e erro. Precisa desfazer também o que a troca
## derrubaria em cascata (§4 do feature: os sockets de baixo somem junto quando a peça
## de cima some) — senão a própria prévia apagaria acessórios de verdade só de olhar as
## opções.
func _delta_text(path: String, part: Part) -> String:
	var saved := _save_subtree(path)
	var before := loadout.resolve()
	var before_weight := loadout.total_weight()

	loadout.mount(path, part)
	var after := loadout.resolve()
	var after_weight := loadout.total_weight()

	_clear_subtree(path)
	for key in saved:
		loadout.mounted[key] = saved[key]
	loadout.resolve()

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


func _save_subtree(path: String) -> Dictionary:
	var saved := {}
	var prefix := "%s/" % path
	for key in loadout.mounted:
		if key == path or String(key).begins_with(prefix):
			saved[key] = loadout.mounted[key]
	return saved


func _clear_subtree(path: String) -> void:
	var prefix := "%s/" % path
	for key in loadout.mounted.keys():
		if key == path or String(key).begins_with(prefix):
			loadout.mounted.erase(key)


func _dropped_notice(dropped: Array[Part]) -> String:
	var names: Array[String] = []
	for part in dropped:
		names.append(part.display_name)
	if dropped.size() == 1:
		return "%s desencaixou junto." % ", ".join(names)
	return "%s desencaixaram junto." % ", ".join(names)


# --- Aba Exoesqueleto ---------------------------------------------------

func _build_kit_list() -> void:
	if not _notice.is_empty():
		content.add_child(_notice_label())

	for kit in KitCatalog.all():
		var current := loadout.kit != null and loadout.kit.id == kit.id
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 30)
		button.custom_minimum_size = Vector2(0, 104)
		button.text = "%s\n%s" % [kit.display_name, _kit_detail(kit)]
		button.disabled = current
		button.pressed.connect(func() -> void: _pick_kit(kit))
		content.add_child(button)


## "FOR 18  AGI 4  DEF 12  EN 18  CARGA 250" — os atributos que este kit tem de
## fábrica, resolvidos numa montagem descartável só para mostrar o número.
func _kit_detail(kit: Kit) -> String:
	var preview := Loadout.new()
	preview.kit = kit
	preview.mounted = kit.default_mounted()
	preview.resolve()
	var bits: Array[String] = []
	for def in preview.schema().stats:
		bits.append("%s %d" % [def.abbreviation, preview.stat(def.key)])
	return "  ".join(bits)


## Trocar de kit reinicia a montagem para a configuração de fábrica dele — os dois kits
## compartilham o esqueleto `mk`, mas as peças de fábrica são específicas de cada um
## (nomes, arte e atributos diferentes), então não há uma tradução parcial óbvia do que
## estava montado. O jogador é avisado.
func _pick_kit(kit: Kit) -> void:
	if loadout.kit != null and loadout.kit.id == kit.id:
		return
	loadout.kit = kit
	loadout.mounted = kit.default_mounted()
	_notice = "Montagem reiniciada para a configuração de fábrica do %s." % kit.display_name
	_refresh()


# --- Sair para a batalha ------------------------------------------------

func _on_battle_pressed() -> void:
	if not loadout.is_valid():
		return
	if loadout.pilot_name.strip_edges().is_empty():
		loadout.pilot_name = "R-7"
	PlayerLoadout.save(loadout)
	get_tree().change_scene_to_file(BATTLE_SCENE)
