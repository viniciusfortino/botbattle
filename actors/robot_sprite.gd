## Corpo do robô montado a partir do kit: um nó por osso do esqueleto e um por peça
## montada, em qualquer profundidade.
##
## A árvore sai da montagem (`Loadout.kit`/`mounted`) — posição de repouso, profundidade
## e âncora da arte vêm do próprio esqueleto e dos sockets ocupados. É por isso que
## acrescentar um osso ou um socket não exige tocar neste arquivo: o nó aparece sozinho,
## no lugar e na ordem que o `.tres` mandar.
##
## Cada nó desenha a arte da peça quando ela existe e, quando não existe, a silhueta
## procedural que este arquivo fornece.
##
## A origem do nó fica nos "pés"; o corpo ocupa de y = -360 até y = 0.
@tool
class_name RobotSprite
extends Node2D

## Medido em cima da calibração real da montada (§13.1/§13.3.3) — não é mais um
## chute; só ancora VFX (feixe de laser, números de dano em battle.gd), não combate.
const HEIGHT := 347.0

## A sombra fica atrás de qualquer pedaço do corpo, e o corpo inteiro fica acima dela.
## Nenhum z do robô é negativo: com a árvore de nós, um z abaixo de zero cairia atrás do
## cenário — coisa que o desenho antigo, feito num `_draw()` só, não conseguia fazer.
const SHADOW_Z := 0

## A animação de repouso: é ela que respira. Toda animação de ação volta para cá.
const IDLE_ANIMATION := "idle"
## Transição entre uma animação e outra, para a pose não dar solavanco.
const BLEND_TIME := 0.15

## Paleta do desenho de reserva. Não é escolha do jogador (§7): a cor por unidade que
## sobrou vive em UnitStats e serve aos VFX, não à silhueta.
const FALLBACK_BODY := Color("4f9dde")
const FALLBACK_ACCENT := Color("8ef0ff")

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
## O `art_id` do retrato fullbody (res://assets/source/parts/<id>/) — vazio quando o
## kit não tem visão fullbody.
var _full_art_id := ""
## O esqueleto da montagem atual. `set_loadout()` refaz a árvore quando ele muda —
## trocar de kit pode trocar a forma inteira.
var _skeleton_shape: Skeleton = null
var _skeleton: Node2D = null
## chave do osso, ou caminho de socket -> PartNode.
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
## para escolher a variante da arte.
func set_loadout(loadout: Loadout, body: Body = null) -> void:
	_loadout = loadout
	_body = body
	var kit := loadout.kit if loadout != null else null
	_full_art_id = kit.full_art_id if kit != null else ""

	# Trocar de kit pode trocar de esqueleto, ou de visão (fullbody <-> montada), e aí a
	# árvore inteira é outra.
	var shape: Skeleton = kit.skeleton if kit != null else null
	if shape != _skeleton_shape or _use_fullbody() != (_full_node != null):
		_build()
	else:
		_sync()


func flash(color: Color) -> void:
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.28)


# --- Montagem da árvore ---------------------------------------------------

## Fullbody (herói) ou montada (inimigo e hangar) — decidido pelo kit, com o override
## explícito de `force_montada` (ver §6.2.2 do plano).
func _use_fullbody() -> bool:
	return not force_montada and not _full_art_id.is_empty()


## Refaz a árvore inteira a partir do esqueleto. Os nós não recebem `owner`, então são
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

	_skeleton_shape = _loadout.kit.skeleton if _loadout != null and _loadout.kit != null else null
	if _skeleton_shape == null:
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


## A visão montada: um `PartNode` por osso do esqueleto, e um por peça montada em
## qualquer profundidade — a recursão de `Loadout.mounted_parts()` vira a recursão da
## árvore de nós, socket por socket.
func _build_montada() -> void:
	_skeleton = Node2D.new()
	_skeleton.name = "Skeleton"
	add_child(_skeleton)

	for bone in _skeleton_shape.bones_in_order():
		var node := PartNode.new()
		node.name = bone.key
		node.key = bone.key
		node.position = bone.rest_position
		node.rotation = bone.rest_rotation
		node.art_offset = bone.art_offset
		node.art_height = bone.art_height
		node.fallback = _bone_fallback("", bone.key, "")
		var host: Node2D = _bone_nodes.get(bone.parent, _skeleton)
		host.add_child(node)
		_bone_nodes[bone.key] = node

	for entry in _loadout.mounted_parts():
		var path: String = entry["path"]
		var socket: SocketDef = entry["socket"]
		var parent_path: String = entry["parent_path"]
		var root_bone := path.split("/")[0]
		var socket_key := path.get_slice("/", path.get_slice_count("/") - 1)
		var host: Node2D = (_mount_nodes.get(parent_path) if not parent_path.is_empty()
			else _bone_nodes.get(root_bone))
		if host == null:
			continue

		var node := PartNode.new()
		node.name = path.replace("/", "_")
		node.key = path
		if socket != null:
			node.position = socket.rest_position
			node.art_offset = socket.art_offset
			node.art_height = socket.art_height
		node.fallback = _bone_fallback(path, root_bone, socket_key)
		host.add_child(node)
		_mount_nodes[path] = node

	_build_player(_skeleton_shape.form.animations if _skeleton_shape.form != null else null)


## A visão fullbody: uma imagem só, ancorada pelos pés — medida por alpha (não há
## calibração por osso aqui, é um retângulo só). Ver §13.4 do plano: full_hires é a
## resolução escolhida (256px, densidade próxima da montada em 4×), com a ressalva
## de proporção em aberto até alguém regerar com prompt de proporção casada.
const FULL_ART_OFFSET := Vector2(3.5, 4.0)
const FULL_ART_HEIGHT := 256.0

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
## chaves da forma — "hip", "hip/torso", "hip/torso/head". Uma animação escrita para uma
## forma vale para qualquer esqueleto que a use.
func _build_player(animations: AnimationLibrary) -> void:
	_player = null
	if animations == null or _skeleton == null:
		return
	_player = AnimationPlayer.new()
	_player.name = "Pose"
	_skeleton.add_child(_player)
	_player.add_animation_library("", animations)
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
## e uma animação que não existe nesta forma simplesmente não acontece (devolve 0).
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
## existe para este `art_id` — senão a pose fica em Idle e a duração devolvida é 0.
func _play_fullbody_pose(anim: String) -> float:
	if anim.is_empty() or _full_art_id.is_empty():
		return 0.0
	if not (FULLBODY_POSE in CharacterArt.poses(_full_art_id)):
		return 0.0
	_full_pose = FULLBODY_POSE
	_sync()
	get_tree().create_timer(FULLBODY_POSE_DURATION).timeout.connect(
		_end_fullbody_pose, CONNECT_ONE_SHOT)
	return FULLBODY_POSE_DURATION


func _end_fullbody_pose() -> void:
	_full_pose = "Idle"
	_sync()


## A profundidade é declarada em absoluto no esqueleto, mas aplicada como diferença para
## o pai: assim o z de um robô continua relativo ao próprio RobotSprite, e dois
## combatentes em cena não se intercalam. A de cada osso vem do próprio `BoneDef`, a de
## cada peça montada vem do `SocketDef` que ela ocupa — já resolvido em
## `entry["socket"]` por `Loadout.mounted_parts()`.
func _apply_view() -> void:
	if _skeleton == null or _skeleton_shape == null:
		return
	var bones := _skeleton_shape.bones_in_order()
	var entries := _loadout.mounted_parts()

	var absolute := {}
	for bone in bones:
		absolute[bone.key] = bone.z_index
	for entry in entries:
		var socket: SocketDef = entry["socket"]
		absolute[entry["path"]] = socket.z_index if socket != null else 0

	var lowest := 0
	for z in absolute.values():
		lowest = mini(lowest, int(z))
	_skeleton.z_index = 1 - lowest

	for bone in bones:
		var node: Node2D = _bone_nodes.get(bone.key)
		if node != null:
			node.z_index = bone.z_index - int(absolute.get(bone.parent, 0))

	for entry in entries:
		var path: String = entry["path"]
		var node: Node2D = _mount_nodes.get(path)
		if node == null:
			continue
		var parent_path: String = entry["parent_path"]
		var parent_key := parent_path if not parent_path.is_empty() else path.split("/")[0]
		var socket: SocketDef = entry["socket"]
		var target: int = socket.z_index if socket != null else 0
		node.z_index = target - int(absolute.get(parent_key, 0))


# --- O que cada nó mostra -------------------------------------------------

## Distribui arte e visibilidade pelos nós. O osso só aparece quando nada o cobre — a
## peça direto no socket dele é quem esconde a silhueta, do mesmo jeito que esconde a
## hitbox da mira (Docs/feature_montagem.md §7). Cascata (peça cai, o que estava montado
## nela cai junto) já vem de graça: `_collapse_dependents()` zera o `hp` de tudo isso
## antes do próximo `_sync()`, então checar só a própria hitbox de cada nó já basta.
##
## Na fullbody não há osso nem socket: é um nó só, sem dano por parte (§6.4).
func _sync() -> void:
	if _full_node != null:
		_full_node.set_art_resolver(_full_art_resolver())
		_full_node.set_condition(BodyPart.Condition.INTACT)
		_full_node.queue_redraw()
		return
	if _loadout == null or _loadout.kit == null:
		return

	var entries := _loadout.mounted_parts()

	# Que osso tem uma peça viva direto em cima — esses somem; os outros ficam expostos.
	var covered := {}
	for entry in entries:
		if String(entry["parent_path"]).is_empty():
			var root_bone: String = String(entry["path"]).split("/")[0]
			var hitbox := _body.part_by_key(entry["path"]) if _body != null else null
			covered[root_bone] = hitbox == null or hitbox.is_intact()

	for bone in _loadout.kit.skeleton.bones:
		var node: PartNode = _bone_nodes.get(bone.key)
		if node == null:
			continue
		# O osso NUNCA fica invisível por estar coberto: no Godot, `visible = false` num
		# nó esconde os filhos junto, e a peça que o cobre é filha dele — escondê-lo
		# apagaria a peça de cima também, em qualquer profundidade. Coberto, ele só para
		# de desenhar a própria silhueta (sem resolver, sem fallback) — os filhos seguem
		# se desenhando por conta própria.
		node.visible = _bone_visible(bone.key)
		node.fallback = Callable() if covered.get(bone.key, false) else _bone_fallback("", bone.key, "")
		node.set_art_resolver(Callable())
		node.set_condition(_condition(bone.key))

	for entry in entries:
		var path: String = entry["path"]
		var node: PartNode = _mount_nodes.get(path)
		if node == null:
			continue
		var part: Part = entry["part"]
		var hitbox := _body.part_by_key(path) if _body != null else null
		node.visible = hitbox == null or hitbox.is_intact()
		node.set_art_resolver(_mounted_art_resolver(part))
		node.set_condition(hitbox.condition() if hitbox != null else BodyPart.Condition.INTACT)

	_redraw_all()


func _bone_visible(key: String) -> bool:
	match key:
		"leg_left":
			return left_leg_intact
		"leg_right":
			return right_leg_intact
		_:
			return true


## A arte da visão fullbody: uma imagem só, sem cascata de dano (§6.4) — o `art_id` do
## retrato do kit direto.
func _full_art_resolver() -> Callable:
	if Engine.is_editor_hint() or _full_art_id.is_empty():
		return Callable()
	var art_id := _full_art_id
	var dir := direction
	var pose := _full_pose
	return func(_cond: BodyPart.Condition) -> Texture2D:
		return CharacterArt.texture(art_id, dir, BodyPart.Condition.INTACT, pose)


## A peça neste caminho de socket, se estiver montada e ainda de pé.
func _mounted(path: String) -> Part:
	if _loadout == null:
		return null
	var part: Part = _loadout.mounted.get(path)
	if part == null or _body == null:
		return part
	var hitbox := _body.part_by_key(path)
	return part if hitbox == null or hitbox.is_intact() else null


## A arte de uma peça montada, direto pelo `art_id` dela — osso de fábrica, braço
## trocado ou acessório resolvem todos do mesmo jeito desde a Fase 8 (não existe mais
## "cai na arte do osso": toda peça de fábrica já tem o próprio `art_id`). Sem espelho em
## nenhum caso — cada lado desenha a própria arte quando ela existir, sem tentar virar a
## do outro lado (Docs/feature_montagem.md §11.1, decidido: arte dedicada por lado).
func _mounted_art_resolver(part: Part) -> Callable:
	if Engine.is_editor_hint() or part == null or part.art_id.is_empty():
		return Callable()
	var art_id := part.art_id
	var dir := direction
	return func(cond: BodyPart.Condition) -> Texture2D:
		return CharacterArt.texture(art_id, dir, cond)


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
# Tudo aqui é desenhado em coordenadas locais do nó, com a pose vinda do esqueleto/socket.

## O desenho procedural de um pedaço. `path`/`socket_key` vazios = é o próprio osso — só
## aparece exposto, sem nada montado nele por definição, então a silhueta não varia por
## peça. `socket_key == "main"` é a peça que É o membro: mesma silhueta do osso, mas
## pode variar pela peça que está lá (braço pesado sai mais largo). Qualquer outro
## socket é acessório e desenha pelo próprio nome.
func _bone_fallback(path: String, root_bone: String, socket_key: String) -> Callable:
	if socket_key.is_empty() or socket_key == "main":
		var piece_path := path if socket_key == "main" else ""
		match root_bone:
			"torso":
				return _draw_torso
			"head":
				return _draw_head
			"arm_left", "arm_right":
				return func(ci: CanvasItem) -> void:
					_draw_arm(ci, root_bone, _mounted(piece_path) if not piece_path.is_empty() else null)
			"leg_left", "leg_right":
				return _draw_leg
			_:
				return Callable()
	match socket_key:
		"top_1":
			return func(ci: CanvasItem) -> void: _draw_head_mount(ci, _mounted(path))
		"back_1", "back_2":
			return _draw_back_mount
		"chest_1", "chest_2":
			return _draw_chest_mount
		"rail_1":
			return func(ci: CanvasItem) -> void: _draw_weapon(ci, _mounted(path))
		_:
			return Callable()


func _draw_shadow(ci: CanvasItem) -> void:
	_ellipse(ci, Vector2(0.0, 6.0), Vector2(130.0, 26.0), Color(0.0, 0.0, 0.0, 0.35))


func _draw_torso(ci: CanvasItem) -> void:
	var dark := FALLBACK_BODY.darkened(0.45)
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-72.0, 56.0, 144.0, 46.0), metal, 10)
	_box(ci, Rect2(-86.0, -62.0, 172.0, 128.0), FALLBACK_BODY, 18, dark, 4)

	_ellipse(ci, Vector2.ZERO, Vector2(40.0, 40.0), FALLBACK_ACCENT * Color(1, 1, 1, 0.2))
	_box(ci, Rect2(-26.0, -26.0, 52.0, 52.0), metal, 12)
	ci.draw_circle(Vector2.ZERO, 16.0, FALLBACK_ACCENT)


func _draw_head(ci: CanvasItem) -> void:
	var dark := FALLBACK_BODY.darkened(0.45)
	var light := FALLBACK_BODY.lightened(0.15)
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-20.0, 0.0, 40.0, 26.0), metal, 6)
	_box(ci, Rect2(-58.0, -74.0, 116.0, 82.0), light, 20, dark, 4)

	_box(ci, Rect2(-44.0, -54.0, 88.0, 38.0), metal, 10)
	ci.draw_circle(Vector2(-19.0, -35.0), 9.0, FALLBACK_ACCENT)
	ci.draw_circle(Vector2(19.0, -35.0), 9.0, FALLBACK_ACCENT)
	_box(ci, Rect2(-26.0, -10.0, 52.0, 10.0), dark, 4)


## Um braço. Destruído, some tudo menos o ombro: a silhueta assimétrica conta de longe
## o que aconteceu. `piece` é o que está montado nesse braço agora — o osso exposto
## (nada montado) sempre chama isto com `piece = null`.
func _draw_arm(ci: CanvasItem, key: String, piece: Part) -> void:
	var dark := FALLBACK_BODY.darkened(0.45)
	var mid := FALLBACK_BODY.darkened(0.2)
	var light := FALLBACK_BODY.lightened(0.15)
	_box(ci, Rect2(-26.0, 0.0, 52.0, 60.0), light, 14, dark, 3)

	if not (left_arm_intact if key == "arm_left" else right_arm_intact):
		return

	# A distinção de largura por modo de montagem (braço trocado × antebraço) saiu com
	# `Part.Slot` (Docs/plan_montagem.md, Fase 7) — é só o desenho de reserva, e todo
	# braço/peça de verdade já tem (ou vai ter) arte própria.
	var width := 44.0
	_box(ci, Rect2(-width * 0.5, 48.0, width, 76.0), mid, 12, dark, 3)
	if piece == null:
		# Mão de fábrica, quando nada está acoplado.
		_box(ci, Rect2(-20.0, 114.0, 40.0, 30.0), dark, 8)


func _draw_leg(ci: CanvasItem) -> void:
	var dark := FALLBACK_BODY.darkened(0.45)
	var mid := FALLBACK_BODY.darkened(0.2)
	_box(ci, Rect2(-26.0, -55.0, 52.0, 84.0), mid, 10, dark, 3)
	_box(ci, Rect2(-32.0, 23.0, 64.0, 32.0), dark, 8)


func _draw_head_mount(ci: CanvasItem, piece: Part) -> void:
	if piece == null:
		return
	var dark := FALLBACK_BODY.darkened(0.45)
	var metal := Color(0.16, 0.19, 0.25)

	# A silhueta sai do que a peça declara fazer: quem não concede ação nenhuma é
	# sensor, quem concede é armamento.
	if piece.grants_actions.is_empty():
		_box(ci, Rect2(-4.0, -52.0, 8.0, 52.0), metal, 3)
		ci.draw_circle(Vector2(0.0, -56.0), 9.0, FALLBACK_ACCENT)
	else:
		_box(ci, Rect2(-34.0, -46.0, 68.0, 46.0), metal, 10, dark, 3)
		ci.draw_circle(Vector2(0.0, -22.0), 12.0, FALLBACK_ACCENT)
		ci.draw_circle(Vector2(0.0, -22.0), 5.0, Color(1, 1, 1, 0.9))


func _draw_back_mount(ci: CanvasItem) -> void:
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-26.0, 0.0, 52.0, 88.0), metal, 12)
	ci.draw_circle(Vector2(0.0, 42.0), 11.0, FALLBACK_ACCENT)


func _draw_chest_mount(ci: CanvasItem) -> void:
	var dark := FALLBACK_BODY.darkened(0.45)
	var metal := Color(0.16, 0.19, 0.25)
	_box(ci, Rect2(-24.0, 0.0, 48.0, 62.0), metal, 10, dark, 3)
	ci.draw_circle(Vector2(0.0, 30.0), 11.0, FALLBACK_ACCENT)


## A arma acoplada ao braço. Arma que não exige deslocamento é de tiro; a que exige é
## corpo a corpo — sai da própria ação, então uma arma nova entra na silhueta certa sem
## tocar aqui.
func _draw_weapon(ci: CanvasItem, piece: Part) -> void:
	if piece == null:
		return
	var dark := FALLBACK_BODY.darkened(0.45)
	var light := FALLBACK_BODY.lightened(0.15)
	var metal := Color(0.16, 0.19, 0.25)

	var ranged := false
	for action_id in piece.grants_actions:
		if not Actions.needs_legs(action_id):
			ranged = true
			break

	if ranged:
		_box(ci, Rect2(-27.0, 30.0, 54.0, 54.0), metal, 14, dark, 3)
		ci.draw_circle(Vector2(0.0, 58.0), 14.0, FALLBACK_ACCENT)
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
