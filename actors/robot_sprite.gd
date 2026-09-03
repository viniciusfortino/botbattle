## Corpo do robô montado a partir da anatomia: um nó por osso e um por encaixe.
##
## A árvore sai do recurso `Anatomy` — posição de repouso, profundidade e âncora da arte
## vêm de lá. É por isso que acrescentar um encaixe não exige tocar neste arquivo: o nó
## aparece sozinho, no lugar e na ordem que o `.tres` mandar.
##
## Cada nó desenha a arte da peça quando ela existe e, quando não existe, a silhueta
## procedural que este arquivo fornece — a migração é peça por peça, não de uma vez.
##
## A origem do nó fica nos "pés"; o corpo ocupa de y = -360 até y = 0.
@tool
class_name RobotSprite
extends Node2D

const HEIGHT := 360.0

## A sombra fica atrás de qualquer pedaço do corpo, e o corpo inteiro fica acima dela.
## Nenhum z do robô é negativo: com a árvore de nós, um z abaixo de zero cairia atrás do
## cenário — coisa que o desenho antigo, feito num `_draw()` só, não conseguia fazer.
const SHADOW_Z := 0

## A animação de repouso: é ela que respira. Toda animação de ação volta para cá.
const IDLE_ANIMATION := "idle"
## Transição entre uma animação e outra, para a pose não dar solavanco.
const BLEND_TIME := 0.15

## "east"/"west" na fullbody, "south" na montada.
@export var direction: String = "south":
	set(value):
		direction = value
		_sync()

## Força a visão montada mesmo com full_art_id preenchido. O hangar usa isso.
@export var force_montada: bool = false:
	set(value):
		force_montada = value
		_build()

@export var body_color: Color = Color("4f9dde"):
	set(value):
		body_color = value
		_redraw_all()

@export var accent_color: Color = Color("8ef0ff"):
	set(value):
		accent_color = value
		_redraw_all()

@export var left_arm_intact: bool = true:
	set(value):
		left_arm_intact = value
		_sync()

@export var right_arm_intact: bool = true:
	set(value):
		right_arm_intact = value
		_sync()

@export var left_leg_intact: bool = true:
	set(value):
		left_leg_intact = value
		_sync()

@export var right_leg_intact: bool = true:
	set(value):
		right_leg_intact = value
		_sync()

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
## Id em characters/<id>/full — vazio quando o chassi não tem visão fullbody.
var _full_art_id := ""
var _anatomy: Anatomy = null
var _skeleton: Node2D = null
## chave da anatomia -> PartNode.
var _bone_nodes: Dictionary = {}
var _mount_nodes: Dictionary = {}
var _player: AnimationPlayer = null
## O nó único da visão fullbody — null quando a visão é montada.
var _full_node: PartNode = null
var _full_pose := "Idle"


func _ready() -> void:
	_base_y = position.y
	_build()


## O balanço do corpo inteiro no chão. A respiração do tórax não está aqui: ela é a
## animação `idle`, tocada pelo AnimationPlayer, e o que pende do tórax acompanha.
func _process(delta: float) -> void:
	if not bob_enabled:
		return
	_time += delta
	_apply_vertical_offset()


func _apply_vertical_offset() -> void:
	position.y = _base_y + ground_offset + (sin(_time * 2.2) * 5.0 if bob_enabled else 0.0)


## Passa a desenhar esta montagem. `body` diz o que ainda está de pé (pode ser null,
## no hangar, onde nada foi destruído) — é dele que sai o estado de cada pedaço, usado
## para escolher a variante da arte (ver ArtLibrary).
func set_loadout(loadout: Loadout, body: Body = null) -> void:
	_loadout = loadout
	_body = body
	var chassis := loadout.chassis if loadout != null else null
	_chassis_id = chassis.id if chassis != null else ""
	_full_art_id = chassis.full_art_id if chassis != null else ""

	# Trocar de chassi pode trocar de anatomia, ou de visão (fullbody <-> montada), e aí
	# a árvore inteira é outra.
	if _resolve_anatomy() != _anatomy or _use_fullbody() != (_full_node != null):
		_build()
	else:
		_sync()


func flash(color: Color) -> void:
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.28)


# --- Montagem da árvore ---------------------------------------------------

func _resolve_anatomy() -> Anatomy:
	if _loadout != null:
		return _loadout.anatomy()
	return load(Loadout.DEFAULT_ANATOMY_PATH)


## Fullbody (herói) ou montada (inimigo e hangar) — decidido pelo chassi, com o
## override explícito de `force_montada` (ver §6.2.2 do plano).
func _use_fullbody() -> bool:
	return not force_montada and not _full_art_id.is_empty()


## Refaz a árvore inteira a partir da anatomia. Os nós não recebem `owner`, então são
## de execução e nunca vão parar dentro de um `.tscn` salvo.
func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_bone_nodes.clear()
	_mount_nodes.clear()
	_skeleton = null
	_player = null
	_full_node = null
	_full_pose = "Idle"

	_anatomy = _resolve_anatomy()
	if _anatomy == null:
		return

	var shadow := PartNode.new()
	shadow.name = "Shadow"
	shadow.z_index = SHADOW_Z
	shadow.fallback = _draw_shadow
	add_child(shadow)

	if _use_fullbody():
		_build_fullbody()
	else:
		_build_montada()

	_apply_view()
	_sync()


## A visão montada: um PartNode por osso e por encaixe, igual a antes — só a fonte da
## arte mudou (ver §6.2.1).
func _build_montada() -> void:
	_skeleton = Node2D.new()
	_skeleton.name = "Skeleton"
	add_child(_skeleton)

	for bone in _anatomy.bones_in_order():
		var node := PartNode.new()
		node.name = bone.key
		node.key = bone.key
		node.position = bone.rest_position
		node.rotation = bone.rest_rotation
		node.art_offset = bone.art_offset
		node.art_height = bone.art_height
		node.fallback = _bone_fallback(bone.key)
		var host: Node2D = _bone_nodes.get(bone.parent, _skeleton)
		host.add_child(node)
		_bone_nodes[bone.key] = node

	for slot_key in _anatomy.slot_keys():
		var def := _anatomy.slot(slot_key)
		var host: Node2D = _bone_nodes.get(def.host_bone)
		if host == null:
			continue
		var node := PartNode.new()
		node.name = "mount_%s" % slot_key
		node.key = slot_key
		node.position = def.rest_position
		node.rotation = def.rest_rotation
		node.art_offset = def.art_offset
		node.art_height = def.art_height
		node.fallback = _mount_fallback(slot_key)
		host.add_child(node)
		_mount_nodes[slot_key] = node

	_build_player()


## A visão fullbody: uma imagem só, ancorada pelos pés — medida por alpha (não há
## calibração por osso aqui, é um retângulo só). Ver §13 do plano.
const FULL_ART_OFFSET := Vector2(1.0, 15.0)
const FULL_ART_HEIGHT := 128.0

func _build_fullbody() -> void:
	var node := PartNode.new()
	node.name = "Full"
	node.key = "full"
	node.art_offset = FULL_ART_OFFSET
	node.art_height = FULL_ART_HEIGHT
	node.z_index = 1
	add_child(node)
	_full_node = node


## O tocador fica sob o esqueleto, então os caminhos das trilhas são exatamente as
## chaves da anatomia — "hip", "hip/torso", "hip/torso/head". Uma animação escrita para
## esta anatomia vale para qualquer robô que a use.
func _build_player() -> void:
	_player = null
	if _anatomy == null or _anatomy.animations == null or _skeleton == null:
		return
	_player = AnimationPlayer.new()
	_player.name = "Pose"
	_skeleton.add_child(_player)
	_player.add_animation_library("", _anatomy.animations)
	_player.set_default_blend_time(BLEND_TIME)
	_player.animation_finished.connect(_on_pose_finished)
	_play_idle()


func _play_idle() -> void:
	if _player == null or not bob_enabled:
		return
	if _player.has_animation(IDLE_ANIMATION):
		_player.play(IDLE_ANIMATION)


func _on_pose_finished(_anim: StringName) -> void:
	_play_idle()


## Toca uma animação de corpo e devolve a duração dela, para quem chamou saber quanto
## esperar antes de virar o turno. Ao terminar, o corpo volta sozinho para o repouso —
## e uma animação que não existe nesta anatomia simplesmente não acontece (devolve 0).
##
## Na fullbody não há AnimationPlayer (§6.5): a "animação" é trocar a pose do único
## PartNode por um tempo fixo e voltar para Idle sozinho.
const FULLBODY_POSE_DURATION := 0.45
const FULLBODY_POSE := "fighting_pose_flexe"

func play_body(anim: String) -> float:
	if _full_node != null:
		return _play_fullbody_pose(anim)
	if _player == null or anim.is_empty() or not _player.has_animation(anim):
		return 0.0
	_player.play(anim)
	return _player.get_animation(anim).length


## O nome da pose não é hardcoded sem rede: só troca se `poses()` confirmar que ela
## existe para este `char_id` — senão a pose fica em Idle e a duração devolvida é 0.
func _play_fullbody_pose(anim: String) -> float:
	if anim.is_empty() or _full_art_id.is_empty():
		return 0.0
	var base_path := "%s/%s/full" % [CharacterArt.CHARACTERS, _full_art_id]
	if not (FULLBODY_POSE in CharacterArt.poses(base_path)):
		return 0.0
	_full_pose = FULLBODY_POSE
	_sync()
	get_tree().create_timer(FULLBODY_POSE_DURATION).timeout.connect(
		_end_fullbody_pose, CONNECT_ONE_SHOT)
	return FULLBODY_POSE_DURATION


func _end_fullbody_pose() -> void:
	_full_pose = "Idle"
	_sync()


## A profundidade é declarada em absoluto na anatomia, mas aplicada como diferença para
## o pai: assim o z de um robô continua relativo ao próprio RobotSprite, e dois
## combatentes em cena não se intercalam.
func _apply_view() -> void:
	if _skeleton == null or _anatomy == null:
		return
	# A anatomia declara profundidade em absoluto e pode usar valores negativos (peça
	# de costas atrás do tórax). O esqueleto inteiro sobe o bastante para que o menor
	# deles fique logo acima da sombra.
	_skeleton.z_index = 1 - _lowest_z()

	var absolute := {}
	for bone in _anatomy.bones_in_order():
		var node: Node2D = _bone_nodes.get(bone.key)
		if node == null:
			continue
		var target: int = bone.z_index
		node.z_index = target - int(absolute.get(bone.parent, 0))
		absolute[bone.key] = target

	for slot_key in _anatomy.slot_keys():
		var node: Node2D = _mount_nodes.get(slot_key)
		var def := _anatomy.slot(slot_key)
		if node == null or def == null:
			continue
		var target: int = def.z_index
		node.z_index = target - int(absolute.get(def.host_bone, 0))


## O menor z declarado na anatomia.
func _lowest_z() -> int:
	var lowest := 0
	for bone in _anatomy.bones:
		lowest = mini(lowest, bone.z_index)
	for def in _anatomy.slots:
		lowest = mini(lowest, def.z_index)
	return lowest


# --- O que cada nó mostra -------------------------------------------------

## Distribui arte e visibilidade pelos nós. O que foi destruído some; o ombro é a
## exceção — ele fica para a silhueta contar de longe que o braço caiu.
##
## Na fullbody não há osso nem encaixe: é um nó só, sem dano por parte (§6.4).
func _sync() -> void:
	if _anatomy == null:
		return

	if _full_node != null:
		_full_node.set_art_resolver(_full_art_resolver())
		_full_node.set_condition(BodyPart.Condition.INTACT)
		_full_node.queue_redraw()
		return

	for bone in _anatomy.bones:
		var node: PartNode = _bone_nodes.get(bone.key)
		if node == null:
			continue
		node.visible = _bone_visible(bone.key)
		node.set_art_resolver(_bone_art_resolver(bone))
		node.set_condition(_condition(bone.key))

	for slot_key in _anatomy.slot_keys():
		var node: PartNode = _mount_nodes.get(slot_key)
		if node == null:
			continue
		var piece := _mounted(slot_key)
		# Peça que substitui o osso inteiro é desenhada por ele, não por um nó à parte.
		var own_node := piece != null and not _replaces_host(slot_key)
		node.visible = own_node and _host_intact(slot_key)
		if own_node:
			node.set_art_resolver(_mount_art_resolver(piece))
			node.set_condition(_mount_condition(slot_key, piece))
		else:
			node.set_art_resolver(Callable())

	_redraw_all()


func _bone_visible(key: String) -> bool:
	match key:
		"leg_left":
			return left_leg_intact
		"leg_right":
			return right_leg_intact
		_:
			return true


## O encaixe do braço some junto com o braço; o resto acompanha o osso que o sustenta.
func _host_intact(slot_key: String) -> bool:
	match slot_key:
		"arm_left":
			return left_arm_intact
		"arm_right":
			return right_arm_intact
		"leg_left":
			return left_leg_intact
		"leg_right":
			return right_leg_intact
		_:
			return true


func _replaces_host(slot_key: String) -> bool:
	return _loadout != null and _loadout.replaces_host(slot_key)


## O char_id que a montada usa para pedir arte de osso ao CharacterArt: o chassi manda,
## via full_art_id quando ele existir (mesmo em visão forçada a montada), senão via id.
func _art_char_id() -> String:
	return _full_art_id if not _full_art_id.is_empty() else _chassis_id


## A arte de um osso: a da peça que o substituiu, se ela tiver; senão a do chassi. A
## escolha é feita uma vez aqui — o Callable devolvido só aplica a condição que chegar
## depois. `direction` é capturado por valor, como `char_id` e `bone_key`: lido de
## `self` de dentro do Callable, a arte pararia de acompanhar a troca de direção.
func _bone_art_resolver(bone: BoneDef) -> Callable:
	# No editor não há montagem nem corpo: a pré-visualização é só a silhueta.
	if Engine.is_editor_hint():
		return Callable()
	var piece := _loadout.part_replacing(bone.key) if _loadout != null else null
	if piece != null and not piece.art_id.is_empty():
		var art_id := piece.art_id
		var dir := direction
		return func(cond: BodyPart.Condition) -> Texture2D:
			return CharacterArt.part_texture(art_id, dir, cond)
	var char_id := _art_char_id()
	var bone_key := bone.key
	var dir := direction
	return func(cond: BodyPart.Condition) -> Texture2D:
		return CharacterArt.bone_texture(char_id, bone_key, dir, cond)


## A arte da visão fullbody: uma imagem só, sem cascata de dano (§6.4) e sem chassi
## substituindo osso — é o char_id do chassi direto.
func _full_art_resolver() -> Callable:
	if Engine.is_editor_hint() or _full_art_id.is_empty():
		return Callable()
	var char_id := _full_art_id
	var dir := direction
	var pose := _full_pose
	return func(_cond: BodyPart.Condition) -> Texture2D:
		return CharacterArt.bone_texture(char_id, "full", dir, BodyPart.Condition.INTACT, pose)


## A peça deste encaixe, se estiver montada e ainda de pé.
func _mounted(slot_key: String) -> Part:
	if _loadout == null:
		return null
	var piece := _loadout.get_part(slot_key)
	if piece == null or _body == null:
		return piece
	var hitbox := _hitbox_of(slot_key, piece)
	return piece if hitbox == null or hitbox.is_intact() else null


## A hitbox que esta peça ocupa. Quem sabe responder isso é a anatomia — aqui não se
## adivinha mais entre "part:<encaixe>" e o nome do osso.
func _hitbox_of(slot_key: String, piece: Part) -> BodyPart:
	if _body == null or _loadout == null:
		return null
	return _body.part_by_key(_loadout.anatomy().hitbox_key(slot_key, piece))


## Igual ao osso, mas peça montada sempre tem arte por id — nunca cai no chassi. Não
## precisa do encaixe: quem depende dele é a condição, não a escolha da arte.
func _mount_art_resolver(piece: Part) -> Callable:
	if piece == null or piece.art_id.is_empty():
		return Callable()
	var art_id := piece.art_id
	var dir := direction
	return func(cond: BodyPart.Condition) -> Texture2D:
		return CharacterArt.part_texture(art_id, dir, cond)


## A condição de uma peça montada é a da hitbox que ela ocupa, não uma conta feita a
## partir da peça — uma peça sem hitbox própria (nada disparado ainda) está intacta.
func _mount_condition(slot_key: String, piece: Part) -> BodyPart.Condition:
	var hitbox := _hitbox_of(slot_key, piece)
	return hitbox.condition() if hitbox != null else BodyPart.Condition.INTACT


func _condition(key: String) -> BodyPart.Condition:
	var hitbox := _body.part_by_key(key) if _body != null else null
	return hitbox.condition() if hitbox != null else BodyPart.Condition.INTACT


## Redesenha todo mundo, e é grosso de propósito: as silhuetas de reserva leem cor,
## membro destruído e peça montada na hora do `_draw()`, então qualquer uma dessas
## mudanças obriga o redesenho. Só um pedaço que já tem arte poderia ser poupado aqui —
## por isso o cuidado do `PartNode._refresh_art()` ainda não rende nada no `_sync()`.
func _redraw_all() -> void:
	for node in _bone_nodes.values():
		node.queue_redraw()
	for node in _mount_nodes.values():
		node.queue_redraw()


# --- Silhuetas de reserva -------------------------------------------------
#
# Tudo aqui é desenhado em coordenadas locais do nó, com a pose vinda da anatomia.
# É o mesmo desenho de antes: só o endereço mudou.

func _bone_fallback(key: String) -> Callable:
	match key:
		"torso":
			return _draw_torso
		"head":
			return _draw_head
		"arm_left", "arm_right":
			return func(ci: CanvasItem) -> void: _draw_arm(ci, key)
		"leg_left", "leg_right":
			return _draw_leg
		_:
			return Callable()


func _mount_fallback(slot_key: String) -> Callable:
	match slot_key:
		"head_top":
			return _draw_head_mount
		"back_1", "back_2":
			return _draw_back_mount
		"chest_1", "chest_2":
			return _draw_chest_mount
		"arm_left", "arm_right":
			return func(ci: CanvasItem) -> void: _draw_weapon(ci, slot_key)
		_:
			return Callable()


func _draw_shadow(ci: CanvasItem) -> void:
	_ellipse(ci, Vector2(0.0, 6.0), Vector2(130.0, 26.0), Color(0.0, 0.0, 0.0, 0.35))


func _draw_torso(ci: CanvasItem) -> void:
	var dark := body_color.darkened(0.45)
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-72.0, 56.0, 144.0, 46.0), metal, 10)
	_box(ci, Rect2(-86.0, -62.0, 172.0, 128.0), body_color, 18, dark, 4)

	_ellipse(ci, Vector2.ZERO, Vector2(40.0, 40.0), accent_color * Color(1, 1, 1, 0.2))
	_box(ci, Rect2(-26.0, -26.0, 52.0, 52.0), metal, 12)
	ci.draw_circle(Vector2.ZERO, 16.0, accent_color)


func _draw_head(ci: CanvasItem) -> void:
	var dark := body_color.darkened(0.45)
	var light := body_color.lightened(0.15)
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-20.0, 0.0, 40.0, 26.0), metal, 6)
	_box(ci, Rect2(-58.0, -74.0, 116.0, 82.0), light, 20, dark, 4)

	_box(ci, Rect2(-44.0, -54.0, 88.0, 38.0), metal, 10)
	ci.draw_circle(Vector2(-19.0, -35.0), 9.0, accent_color)
	ci.draw_circle(Vector2(19.0, -35.0), 9.0, accent_color)
	_box(ci, Rect2(-26.0, -10.0, 52.0, 10.0), dark, 4)


## Um braço. Destruído, some tudo menos o ombro: a silhueta assimétrica conta de longe
## o que aconteceu.
func _draw_arm(ci: CanvasItem, key: String) -> void:
	var dark := body_color.darkened(0.45)
	var mid := body_color.darkened(0.2)
	var light := body_color.lightened(0.15)
	_box(ci, Rect2(-26.0, 0.0, 52.0, 60.0), light, 14, dark, 3)

	if not (left_arm_intact if key == "arm_left" else right_arm_intact):
		return

	var piece := _mounted(key)
	var bulky := piece != null and (piece.slot == Part.Slot.ARM_FULL or piece.slot == Part.Slot.FOREARM)
	var width := 52.0 if bulky else 40.0
	_box(ci, Rect2(-width * 0.5, 48.0, width, 76.0), mid, 12, dark, 3)
	if piece == null:
		# Mão de fábrica, quando nada está acoplado.
		_box(ci, Rect2(-20.0, 114.0, 40.0, 30.0), dark, 8)


func _draw_leg(ci: CanvasItem) -> void:
	var dark := body_color.darkened(0.45)
	var mid := body_color.darkened(0.2)
	_box(ci, Rect2(-26.0, -55.0, 52.0, 84.0), mid, 10, dark, 3)
	_box(ci, Rect2(-32.0, 23.0, 64.0, 32.0), dark, 8)


func _draw_head_mount(ci: CanvasItem) -> void:
	var piece := _mounted("head_top")
	if piece == null:
		return
	var dark := body_color.darkened(0.45)
	var metal := Color(0.16, 0.19, 0.25)

	# A silhueta sai do que a peça declara fazer: quem não concede ação nenhuma é
	# sensor, quem concede é armamento.
	if piece.grants_actions.is_empty():
		_box(ci, Rect2(-4.0, -52.0, 8.0, 52.0), metal, 3)
		ci.draw_circle(Vector2(0.0, -56.0), 9.0, accent_color)
	else:
		_box(ci, Rect2(-34.0, -46.0, 68.0, 46.0), metal, 10, dark, 3)
		ci.draw_circle(Vector2(0.0, -22.0), 12.0, accent_color)
		ci.draw_circle(Vector2(0.0, -22.0), 5.0, Color(1, 1, 1, 0.9))


func _draw_back_mount(ci: CanvasItem) -> void:
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-26.0, 0.0, 52.0, 88.0), metal, 12)
	ci.draw_circle(Vector2(0.0, 42.0), 11.0, accent_color)


func _draw_chest_mount(ci: CanvasItem) -> void:
	var dark := body_color.darkened(0.45)
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-24.0, 0.0, 48.0, 62.0), metal, 10, dark, 3)
	ci.draw_circle(Vector2(0.0, 30.0), 11.0, accent_color)


## A arma acoplada ao braço. Arma que não exige deslocamento é de tiro; a que exige é
## corpo a corpo — sai da própria ação, então uma arma nova entra na silhueta certa sem
## tocar aqui.
func _draw_weapon(ci: CanvasItem, slot_key: String) -> void:
	var piece := _mounted(slot_key)
	if piece == null:
		return
	var dark := body_color.darkened(0.45)
	var light := body_color.lightened(0.15)
	var metal := Color(0.16, 0.19, 0.25)

	var ranged := false
	for action_id in piece.grants_actions:
		if not Actions.needs_legs(action_id):
			ranged = true
			break

	if ranged:
		_box(ci, Rect2(-27.0, 30.0, 54.0, 54.0), metal, 14, dark, 3)
		ci.draw_circle(Vector2(0.0, 58.0), 14.0, accent_color)
		ci.draw_circle(Vector2(0.0, 58.0), 6.0, Color(1, 1, 1, 0.9))
	elif not piece.grants_actions.is_empty():
		_box(ci, Rect2(-22.0, 44.0, 44.0, 32.0), dark, 10)
		_box(ci, Rect2(-7.0, 64.0, 14.0, 52.0), light, 4, dark, 2)
	else:
		_box(ci, Rect2(-22.0, 44.0, 44.0, 32.0), dark, 10)


# --- Primitivas -----------------------------------------------------------

func _box(ci: CanvasItem, rect: Rect2, color: Color, radius: int = 8,
		border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border
	ci.draw_style_box(style, rect)


func _ellipse(ci: CanvasItem, center: Vector2, radius: Vector2, color: Color, segments: int = 32) -> void:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	ci.draw_colored_polygon(points, color)
