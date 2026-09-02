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

var _combatant: Combatant
var _buttons: Array[Dictionary] = []
var _grid: GridContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "Onde atacar?"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

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
	for entry in _buttons:
		entry["button"].queue_free()
	_buttons.clear()

	for part in combatant.body.parts:
		var button := _make_button(part.display_name)
		button.pressed.connect(func() -> void: target_chosen.emit(part))
		_grid.add_child(button)
		_buttons.append({"part": part, "button": button})
	refresh()


## Atualiza chances e desabilita o que já foi destruído.
func refresh() -> void:
	if _combatant == null:
		return
	for entry in _buttons:
		var part: BodyPart = entry["part"]
		var button: Button = entry["button"]
		if part.is_intact():
			button.disabled = false
			button.text = "%s\n%d%%" % [part.display_name, roundi(_combatant.body.aim_chance(part) * 100.0)]
		else:
			button.disabled = true
			button.text = "%s\ndestruído" % part.display_name


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return button
