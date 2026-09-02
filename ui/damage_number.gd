## Número flutuante de dano/cura, com um rótulo menor embaixo (a hitbox atingida).
## Criado em código pela cena de batalha.
class_name DamageNumber
extends Label

var _subtitle: Label = null


static func spawn(parent: Node, world_position: Vector2, text: String, color: Color,
		big: bool = false, subtitle: String = "") -> DamageNumber:
	var label := DamageNumber.new()
	label.text = text
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 92 if big else 68)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08))
	label.add_theme_constant_override("outline_size", 12)
	label.position = world_position

	if not subtitle.is_empty():
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 32)
		sub.add_theme_color_override("font_color", color)
		sub.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08))
		sub.add_theme_constant_override("outline_size", 8)
		label.add_child(sub)
		label._subtitle = sub

	parent.add_child(label)
	label._float_away()
	return label


func _float_away() -> void:
	# Centraliza pelo tamanho real depois do primeiro layout.
	await get_tree().process_frame
	if _subtitle != null:
		_subtitle.position = Vector2((size.x - _subtitle.size.x) * 0.5, size.y - 12.0)
	position -= size * 0.5

	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position:y", position.y - 110.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.14).from(Vector2(0.5, 0.5)).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.12)
	tween.chain().tween_interval(0.25)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)
