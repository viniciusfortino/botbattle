## Corpo do robô desenhado por código (nenhum asset necessário ainda).
## A origem do nó fica nos "pés"; o corpo ocupa de y = -360 até y = 0.
##
## O que aparece vem da montagem: cada encaixe ocupado ganha uma silhueta conforme o
## tipo de peça, e o que foi destruído em combate some do desenho.
@tool
class_name RobotSprite
extends Node2D

const HEIGHT := 360.0

## Visão de costas (o personagem do jogador) ou de frente (o oponente).
@export var back_view: bool = false:
	set(value):
		back_view = value
		queue_redraw()

@export var body_color: Color = Color("4f9dde"):
	set(value):
		body_color = value
		queue_redraw()

@export var accent_color: Color = Color("8ef0ff"):
	set(value):
		accent_color = value
		queue_redraw()

@export var left_arm_intact: bool = true:
	set(value):
		left_arm_intact = value
		queue_redraw()

@export var right_arm_intact: bool = true:
	set(value):
		right_arm_intact = value
		queue_redraw()

@export var left_leg_intact: bool = true:
	set(value):
		left_leg_intact = value
		queue_redraw()

@export var right_leg_intact: bool = true:
	set(value):
		right_leg_intact = value
		queue_redraw()

## Quanto o corpo afunda por estar escorado numa perna só.
@export var ground_offset: float = 0.0:
	set(value):
		ground_offset = value
		_apply_vertical_offset()

## Balanço sutil de "respiração".
@export var bob_enabled: bool = true

var _time := 0.0
var _base_y := 0.0
var _loadout: Loadout = null
var _body: Body = null
var _chassis_id := ""
var _head_ratio := 1.0
var _torso_ratio := 1.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	if not bob_enabled:
		return
	_time += delta
	_apply_vertical_offset()
	queue_redraw()


func _apply_vertical_offset() -> void:
	position.y = _base_y + ground_offset + (sin(_time * 2.2) * 5.0 if bob_enabled else 0.0)


## Passa a desenhar esta montagem. `body` diz o que ainda está de pé (pode ser null,
## no hangar, onde nada foi destruído) — é dele que sai a vida de cabeça/tórax, usada
## para escolher o estado de dano do sprite pintado (ver ChassisArt).
func set_loadout(loadout: Loadout, body: Body = null) -> void:
	_loadout = loadout
	_body = body
	_chassis_id = loadout.chassis.id if loadout != null and loadout.chassis != null else ""
	var head := body.part_by_key("head") if body != null else null
	var torso := body.part_by_key("torso") if body != null else null
	_head_ratio = head.ratio() if head != null else 1.0
	_torso_ratio = torso.ratio() if torso != null else 1.0
	queue_redraw()


func flash(color: Color) -> void:
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.28)


func _draw() -> void:
	var dark := body_color.darkened(0.45)
	var mid := body_color.darkened(0.2)
	var light := body_color.lightened(0.15)
	var metal := Color(0.16, 0.19, 0.25)
	var breath := sin(_time * 2.2) * 3.0

	# Sombra no chão.
	_ellipse(Vector2(0.0, 6.0), Vector2(130.0, 26.0), Color(0.0, 0.0, 0.0, 0.35))

	# Visto de costas, o lado esquerdo do robô fica à nossa esquerda; de frente, ao contrário.
	var left_side := -1.0 if back_view else 1.0

	# Peças das costas ficam atrás de tudo.
	_draw_back_mounts(left_side, breath, metal)

	# Pernas e pés. A perna destruída some — sem ela não há deslocamento.
	_draw_leg(left_side, left_leg_intact, mid, dark)
	_draw_leg(-left_side, right_leg_intact, mid, dark)

	# Sprite pintado existe só de frente por enquanto; de costas (o jogador) segue
	# vetorial. Um arquivo sem transparência real (ver ChassisArt) volta null sozinho.
	var torso_art := ChassisArt.part_texture(_chassis_id, "torso", _torso_ratio) if not back_view else null
	var head_art := ChassisArt.part_texture(_chassis_id, "head", _head_ratio) if not back_view else null

	# A cabeça sempre encosta em onde o tórax de fato começa — pintado (-290) ou
	# vetorial (-268, o topo da caixa procedural). Sem isso, cabeça pintada + tórax
	# ainda vetorial (ou vice-versa) deixam um buraco entre as duas peças.
	var neck_line := -290.0 if torso_art != null else -268.0

	# Quadril e tronco.
	if torso_art != null:
		_draw_art(torso_art, neck_line + breath, 190.0, false)
	else:
		_box(Rect2(-72.0, -150.0, 144.0, 46.0), metal, 10)
		_box(Rect2(-86.0, neck_line + breath, 172.0, 128.0), body_color, 18, dark, 4)

	# Ombros e braços.
	_draw_arm(left_side, "arm_left", left_arm_intact, breath, light, mid, dark, metal)
	_draw_arm(-left_side, "arm_right", right_arm_intact, breath, light, mid, dark, metal)

	# Pescoço e cabeça. Ancorada no mesmo y que o topo do tórax, pelo bottom da arte: as
	# duas se tocam nessa linha em qualquer proporção que a imagem tiver.
	if head_art != null:
		_draw_art(head_art, neck_line + breath, 140.0, true)
	else:
		_box(Rect2(-20.0, -290.0 + breath, 40.0, 26.0), metal, 6)
		_box(Rect2(-58.0, -364.0 + breath, 116.0, 82.0), light, 20, dark, 4)
	_draw_head_mount(breath, metal, dark)

	if back_view:
		_draw_back_torso_details(breath, dark, metal)
		_draw_back_head_details(breath, dark, metal)
	else:
		if torso_art == null:
			_draw_front_torso_details(breath, metal)
		if head_art == null:
			_draw_front_head_details(breath, dark, metal)
		_draw_chest_mounts(left_side, breath, metal, dark)


# --- Peças por encaixe ---------------------------------------------------

## A peça deste encaixe, se estiver montada e ainda de pé.
func _mounted(slot_key: String) -> Part:
	if _loadout == null:
		return null
	var piece := _loadout.get_part(slot_key)
	if piece == null or _body == null:
		return piece
	var hitbox := _body.part_by_key("part:%s" % slot_key)
	if hitbox == null:
		hitbox = _body.part_by_key(slot_key)
	return piece if hitbox == null or hitbox.is_intact() else null


func _draw_head_mount(breath: float, metal: Color, dark: Color) -> void:
	var piece := _mounted("head_top")
	if piece == null:
		return
	if piece.grants_action.is_empty():
		# Sensor: haste fina com uma luz na ponta.
		_box(Rect2(-4.0, -412.0 + breath, 8.0, 52.0), metal, 3)
		draw_circle(Vector2(0.0, -416.0 + breath), 9.0, accent_color)
	else:
		# Canhão: bloco sobre a cabeça com a boca virada para a frente.
		_box(Rect2(-34.0, -406.0 + breath, 68.0, 46.0), metal, 10, dark, 3)
		draw_circle(Vector2(0.0, -382.0 + breath), 12.0, accent_color)
		draw_circle(Vector2(0.0, -382.0 + breath), 5.0, Color(1, 1, 1, 0.9))


func _draw_back_mounts(left_side: float, breath: float, metal: Color) -> void:
	for entry in [["back_1", left_side], ["back_2", -left_side]]:
		var piece := _mounted(String(entry[0]))
		if piece == null:
			continue
		var side: float = entry[1]
		_box(Rect2(side * 142.0 - 26.0, -258.0 + breath, 52.0, 88.0), metal, 12)
		if piece.agility > 0:
			# Turbo: bocal com chama.
			_box(Rect2(side * 142.0 - 16.0, -180.0 + breath, 34.0, 26.0), metal.darkened(0.3), 6)
			draw_circle(Vector2(side * 142.0, -160.0 + breath), 13.0, accent_color)
		else:
			draw_circle(Vector2(side * 142.0, -216.0 + breath), 11.0, accent_color)


func _draw_chest_mounts(left_side: float, breath: float, metal: Color, dark: Color) -> void:
	for entry in [["chest_1", left_side], ["chest_2", -left_side]]:
		var piece := _mounted(String(entry[0]))
		if piece == null:
			continue
		var side: float = entry[1]
		_box(Rect2(side * 58.0 - 24.0, -256.0 + breath, 48.0, 62.0), metal, 10, dark, 3)
		if piece.energy > 0:
			draw_circle(Vector2(side * 58.0, -226.0 + breath), 11.0, accent_color)


func _draw_leg(side: float, intact: bool, mid: Color, dark: Color) -> void:
	if not intact:
		return
	_box(Rect2(side * 34.0 - 26.0, -110.0, 52.0, 84.0), mid, 10, dark, 3)
	_box(Rect2(side * 34.0 - 32.0, -32.0, 64.0, 32.0), dark, 8)


## Um braço com a arma que estiver acoplada nele. Destruído, o braço inteiro some:
## fica só o ombro, e a silhueta assimétrica conta de longe o que aconteceu.
func _draw_arm(side: float, slot_key: String, intact: bool, breath: float,
		light: Color, mid: Color, dark: Color, metal: Color) -> void:
	_box(Rect2(side * 112.0 - 26.0, -272.0 + breath, 52.0, 60.0), light, 14, dark, 3)
	if not intact:
		return

	var piece := _mounted(slot_key)
	var bulky := piece != null and (piece.slot == Part.Slot.ARM_FULL or piece.slot == Part.Slot.FOREARM)
	var width := 52.0 if bulky else 40.0
	_box(Rect2(side * 110.0 - width * 0.5, -224.0 + breath, width, 76.0), mid, 12, dark, 3)

	if piece == null:
		_box(Rect2(side * 110.0 - 20.0, -158.0 + breath, 40.0, 30.0), dark, 8)
		return

	var ranged := piece.grants_action == "plasma" or piece.grants_action == "laser"
	if ranged:
		_box(Rect2(side * 110.0 - 27.0, -176.0 + breath, 54.0, 54.0), metal, 14, dark, 3)
		draw_circle(Vector2(side * 110.0, -148.0 + breath), 14.0, accent_color)
		draw_circle(Vector2(side * 110.0, -148.0 + breath), 6.0, Color(1, 1, 1, 0.9))
	elif not piece.grants_action.is_empty():
		_box(Rect2(side * 110.0 - 22.0, -162.0 + breath, 44.0, 32.0), dark, 10)
		_box(Rect2(side * 110.0 - 7.0, -142.0 + breath, 14.0, 52.0), light, 4, dark, 2)
	else:
		_box(Rect2(side * 110.0 - 22.0, -162.0 + breath, 44.0, 32.0), dark, 10)


## Reator, dutos e placa da nuca — só quando o tórax/cabeça de trás são vetoriais
## (não há sprite pintado de costas ainda; ver _draw()).
func _draw_back_torso_details(breath: float, dark: Color, metal: Color) -> void:
	var core := Vector2(0.0, -206.0 + breath)
	_ellipse(core, Vector2(46.0, 46.0), accent_color * Color(1, 1, 1, 0.25))
	draw_circle(core, 30.0, metal)
	draw_circle(core, 22.0, accent_color)
	draw_circle(core, 11.0, Color(1, 1, 1, 0.85))

	for i in 3:
		var y := -252.0 + breath + i * 16.0
		_box(Rect2(-70.0, y, 30.0, 8.0), dark, 4)
		_box(Rect2(40.0, y, 30.0, 8.0), dark, 4)


func _draw_back_head_details(breath: float, dark: Color, metal: Color) -> void:
	_box(Rect2(-34.0, -338.0 + breath, 68.0, 34.0), dark, 10)
	_box(Rect2(-70.0, -344.0 + breath, 16.0, 42.0), metal, 6)
	_box(Rect2(54.0, -344.0 + breath, 16.0, 42.0), metal, 6)
	draw_circle(Vector2(-62.0, -330.0 + breath), 6.0, accent_color)
	draw_circle(Vector2(62.0, -330.0 + breath), 6.0, accent_color)


## Visor e olhos — pulados quando existe sprite pintado para a cabeça (ChassisArt já
## desenha o rosto do robô).
func _draw_front_head_details(breath: float, dark: Color, metal: Color) -> void:
	var visor := Rect2(-44.0, -344.0 + breath, 88.0, 38.0)
	_box(visor, metal, 10)
	draw_circle(Vector2(-19.0, -325.0 + breath), 9.0, accent_color)
	draw_circle(Vector2(19.0, -325.0 + breath), 9.0, accent_color)
	_box(Rect2(-26.0, -300.0 + breath, 52.0, 10.0), dark, 4)


## Núcleo do peito — pulado quando existe sprite pintado para o tórax.
func _draw_front_torso_details(breath: float, metal: Color) -> void:
	var core := Vector2(0.0, -206.0 + breath)
	_ellipse(core, Vector2(40.0, 40.0), accent_color * Color(1, 1, 1, 0.2))
	_box(Rect2(-26.0, -232.0 + breath, 52.0, 52.0), metal, 12)
	draw_circle(core, 16.0, accent_color)


## Desenha uma peça pintada (já recortada ao conteúdo por ChassisArt), ajustando a
## altura real dela a `target_height` unidades de jogo — a largura sai da proporção da
## imagem, então nunca distorce. Ancorada por cima ou por baixo em `anchor_y` e
## centralizada em X, para encostar de forma previsível na peça vizinha.
func _draw_art(texture: Texture2D, anchor_y: float, target_height: float, anchor_bottom: bool) -> void:
	var size := texture.get_size()
	if size.y <= 0.0:
		return
	var scale := target_height / size.y
	var draw_size := size * scale
	var top := anchor_y - draw_size.y if anchor_bottom else anchor_y
	draw_texture_rect(texture, Rect2(Vector2(-draw_size.x * 0.5, top), draw_size), false)


func _box(rect: Rect2, color: Color, radius: int = 8, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border
	draw_style_box(style, rect)


func _ellipse(center: Vector2, radius: Vector2, color: Color, segments: int = 32) -> void:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
