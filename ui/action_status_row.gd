## Fileira compacta de ações — um rótulo por ação que a montagem concede agora, apagado
## quando a peça que a concede (ou o que a sustenta) já caiu.
##
## Substitui a barra de HP agregada: não existe mais HP total que decida a luta
## (Docs/feature_montagem.md §7, derrota funcional desde a Fase 4 do
## Docs/plan_montagem.md) — o que importa de verdade é o que o combatente ainda
## consegue fazer, e é isso que esta fileira mostra, sem número nenhum por trás.
class_name ActionStatusRow
extends HBoxContainer

const ACTIVE_COLOR := Color("cbd5e1")
const LOST_COLOR := Color("64748b")

var _combatant: Combatant


## Passa a espelhar as ações deste combatente. Reconstrói a fileira inteira a cada
## atualização — o mesmo custo do `HitboxDebugPanel`, e pela mesma razão: são poucos
## rótulos, e a lista de ações concedidas pode mudar de tamanho (peça perdida).
func track(combatant: Combatant) -> void:
	_combatant = combatant
	combatant.part_hit.connect(func(_info: Dictionary) -> void: refresh())
	combatant.stats_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	if _combatant == null:
		return
	for entry in _combatant.available_actions():
		add_child(_chip(String(entry["id"])))


func _chip(action_id: String) -> Control:
	var lost := _combatant.missing_requirement(action_id) != null

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = Actions.action_name(action_id)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", LOST_COLOR if lost else ACTIVE_COLOR)
	label.modulate.a = 0.4 if lost else 1.0
	panel.add_child(label)
	return panel
