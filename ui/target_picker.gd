## Segundo toque de um ataque: onde acertar.
##
## Mostra as hitboxes do alvo com a chance de a mira pegar (proporcional à área da
## parte). Partes já destruídas não são escolhíveis. "Aleatório" devolve null, que é o
## golpe sem mira de sempre.
class_name TargetPicker
extends VBoxContainer

## `part` é null quando o jogador escolhe atacar sem mirar.
signal target_chosen(part: BodyPart)
signal cancelled

const BUTTON_FONT := 34

enum Group { STRUCTURE, PARTS }

var _combatant: Combatant
var _buttons: Array[Dictionary] = []
var _grid: GridContainer
var _tabs: HBoxContainer
var _group: Group = Group.STRUCTURE


func _ready() -> void:
	add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Onde atacar?"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Com as peças montadas o corpo passa de dez alvos: duas abas mantêm tudo alcançável
	# com o polegar, sem rolagem.
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 12)
	add_child(_tabs)
	for entry in [[Group.STRUCTURE, "Estrutura"], [Group.PARTS, "Peças"]]:
		var tab := Button.new()
		tab.text = String(entry[1])
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 30)
		var group: Group = entry[0]
		tab.pressed.connect(func() -> void:
			_group = group
			refresh())
		_tabs.add_child(tab)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_grid)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	add_child(footer)

	var random_button := _make_button("Aleatório")
	random_button.pressed.connect(func() -> void: target_chosen.emit(null))
	footer.add_child(random_button)

	var back_button := _make_button("Voltar")
	back_button.pressed.connect(func() -> void: cancelled.emit())
	footer.add_child(back_button)


## Passa a mostrar as hitboxes deste combatente.
func setup(combatant: Combatant) -> void:
	_combatant = combatant
	_group = Group.STRUCTURE
	refresh()


## Reconstrói a aba visível: chances atualizadas e o que já caiu fica desabilitado.
func refresh() -> void:
	if _combatant == null:
		return

	var index := 0
	for child in _tabs.get_children():
		if child is Button:
			(child as Button).button_pressed = index == int(_group)
			index += 1

	for entry in _buttons:
		entry["button"].queue_free()
	_buttons.clear()

	var pool := _combatant.body.structural_parts() if _group == Group.STRUCTURE \
		else _combatant.body.attachment_parts()
	for part in pool:
		var button := _make_button("")
		if part.is_intact():
			button.text = "%s\n%d%%" % [part.display_name, roundi(_combatant.body.aim_chance(part) * 100.0)]
		else:
			button.disabled = true
			button.text = "%s\ndestruído" % part.display_name
		button.pressed.connect(func() -> void: target_chosen.emit(part))
		_grid.add_child(button)
		_buttons.append({"part": part, "button": button})

	if pool.is_empty():
		var empty := Label.new()
		empty.text = "Sem peças montadas."
		empty.add_theme_font_size_override("font_size", 30)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grid.add_child(empty)
		_buttons.append({"part": null, "button": empty})


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return button
