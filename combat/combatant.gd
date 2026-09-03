## Um lutador em cena: a montagem, o estado de combate e as animações do corpo.
##
## A montagem (`loadout`) é a fonte da verdade. Dela saem três coisas: o corpo em
## hitboxes, os atributos (`stats`, recalculados quando uma peça cai) e as ações
## disponíveis — cada uma vinda de uma peça montada.
class_name Combatant
extends Node2D

signal hp_changed(current: int, maximum: int)
signal mp_changed(current: int, maximum: int)
## Emitido a cada golpe recebido, com {part, dealt, destroyed}.
signal part_hit(info: Dictionary)
## Emitido quando perder uma peça muda os atributos.
signal stats_changed
signal defeated

@export var loadout: Loadout
## Marque apenas no personagem controlado pelo jogador (visto de costas).
@export var is_player: bool = false
@export_range(0.2, 3.0, 0.05) var visual_scale: float = 1.0

var body: Body
## Derivado da montagem: some o que as peças destruídas deixaram de fornecer.
var stats: UnitStats
var mp: int = 0
var guarding: bool = false

var hp: int:
	get:
		return body.total_hp() if body != null else 0

var max_hp: int:
	get:
		return body.max_total_hp() if body != null else 0

var _home := Vector2.ZERO

@onready var sprite: RobotSprite = $Sprite


func _ready() -> void:
	if loadout == null:
		loadout = Loadout.new()
		loadout.chassis = Chassis.new()
	body = Body.from_loadout(loadout)
	stats = loadout.resolve()
	_home = position
	mp = stats.max_mp
	# Quem é visto de que ângulo é `direction` (§6.6) — não é mais "sou o jogador" que
	# decide a visão (fullbody/montada); isso é do chassi (RobotSprite._use_fullbody()).
	sprite.direction = "east" if is_player else "south"
	sprite.body_color = loadout.body_color
	sprite.accent_color = loadout.accent_color
	sprite.scale = Vector2.ONE * visual_scale
	_sync_body()
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, stats.max_mp)


func is_alive() -> bool:
	return hp > 0


# --- Ações vindas das peças ---------------------------------------------

## As ações que este robô pode executar, cada uma com a peça que a concede e a hitbox
## dessa peça. Ações repetidas (duas espadas) aparecem uma vez só, pela peça mais forte.
func available_actions() -> Array[Dictionary]:
	var anatomy := loadout.anatomy()
	var by_id := {}
	for slot_key in loadout.slot_keys():
		var piece := loadout.get_part(slot_key)
		if piece == null:
			continue
		for action_id in piece.grants_actions:
			var entry := {
				"id": action_id,
				"part": piece,
				"key": anatomy.hitbox_key(slot_key, piece),
			}
			var current: Variant = by_id.get(action_id)
			var current_strength: int = (current["part"] as Part).modifiers.get("strength", 0) if current != null else -1
			if current == null or piece.modifiers.get("strength", 0) > current_strength:
				by_id[action_id] = entry

	var list: Array[Dictionary] = []
	for id in Actions.LIST:
		if by_id.has(id):
			list.append(by_id[id])
	# Defender não vem de peça nenhuma: é do exoesqueleto.
	list.append({"id": "guard", "part": null, "key": ""})
	return list


func action_entry(action_id: String) -> Dictionary:
	for entry in available_actions():
		if String(entry["id"]) == action_id:
			return entry
	return {}


## As hitboxes que precisam estar de pé para esta ação existir: a própria peça, o
## membro que a sustenta e, se a ação exige deslocamento, as duas pernas.
func requirements_for(action_id: String) -> Array[String]:
	var keys: Array[String] = []
	var entry := action_entry(action_id)
	if entry.is_empty():
		return keys

	var key := String(entry["key"])
	if not key.is_empty():
		keys.append(key)
		var hitbox := body.part_by_key(key)
		if hitbox != null and hitbox.parent != null:
			keys.append(hitbox.parent.key)
	if Actions.needs_legs(action_id):
		keys.append("leg_left")
		keys.append("leg_right")
	return keys


## A primeira hitbox destruída que esta ação exige (null se o corpo permite a ação).
func missing_requirement(action_id: String) -> BodyPart:
	for key in requirements_for(action_id):
		var part := body.part_by_key(key)
		if part != null and not part.is_intact():
			return part
	return null


## A hitbox cuja integridade escala o dano: a peça que empunha a arma.
func power_part_for(action_id: String) -> BodyPart:
	var entry := action_entry(action_id)
	if entry.is_empty() or String(entry["key"]).is_empty():
		return null
	return body.part_by_key(String(entry["key"]))


## A animação de corpo desta ação: o padrão da ação, ou o que a peça que a concede
## manda no lugar — é assim que um lança-chamas faz o robô se agachar sem que a ação
## "disparar" precise saber que ele existe.
func body_animation_for(action_id: String) -> String:
	var entry := action_entry(action_id)
	var piece: Part = entry.get("part")
	if piece != null and not piece.body_animation.is_empty():
		return piece.body_animation
	return Actions.body_animation(action_id)


## Toca a animação de corpo desta ação, se ela tiver uma, e devolve a duração — quem
## chama precisa saber quanto esperar antes de deixar a ação seguinte cortá-la no meio.
func play_body_animation(action_id: String) -> float:
	return sprite.play_body(body_animation_for(action_id))


func weapon_efficiency(action_id: String) -> float:
	return Actions.part_efficiency(power_part_for(action_id))


## A ação está disponível? Precisa de energia, do corpo que ela exige e de fazer efeito.
func can_use(action_id: String) -> bool:
	if action_entry(action_id).is_empty():
		return false
	if not can_pay(Actions.cost(action_id)):
		return false
	if Actions.kind_of(action_id) == Actions.HEAL and hp >= max_hp:
		return false
	return missing_requirement(action_id) == null


## Ainda existe alguma forma de causar dano? Ignora energia de propósito: sem EN dá
## para defender e recarregar, o que não é estar desarmado.
func has_offense() -> bool:
	for entry in available_actions():
		var id := String(entry["id"])
		if Actions.kind_of(id) != Actions.DAMAGE:
			continue
		if missing_requirement(id) == null:
			return true
	return false


## O que o combatente deixa de conseguir fazer se esta hitbox cair.
func capabilities_lost_with(part: BodyPart) -> Array[String]:
	var labels: Array[String] = []
	for entry in available_actions():
		var id := String(entry["id"])
		if not requirements_for(id).has(part.key):
			continue
		var label := Actions.loss_label(id)
		if not label.is_empty() and not labels.has(label):
			labels.append(label)
	return labels


# --- Dano, cura e energia -----------------------------------------------

## Aplica o dano a partir de `part`; o excedente transborda para as outras hitboxes.
func apply_damage(amount: int, part: BodyPart = null) -> Dictionary:
	var info := body.apply_damage(amount, part)
	_recalculate_stats()
	_sync_body()
	hp_changed.emit(hp, max_hp)
	part_hit.emit(info)
	if hp == 0:
		defeated.emit()
		_play_death()
	return info


func heal(amount: int) -> int:
	var restored := body.repair(amount)
	_recalculate_stats()
	_sync_body()
	hp_changed.emit(hp, max_hp)
	return restored


func change_mp(amount: int) -> void:
	mp = clampi(mp + amount, 0, stats.max_mp)
	mp_changed.emit(mp, stats.max_mp)


func can_pay(amount: int) -> bool:
	return mp >= amount


## Peça destruída deixa de somar atributos — perder turbos custa iniciativa.
func _recalculate_stats() -> void:
	var before := stats.speed
	stats = loadout.resolve(body.lost_pieces())
	mp = mini(mp, stats.max_mp)
	stats_changed.emit()
	if before != stats.speed:
		mp_changed.emit(mp, stats.max_mp)


# --- Animações ----------------------------------------------------------

## Avança em direção ao alvo e volta. Use `await c.lunge(pos).finished`.
func lunge(target_global: Vector2) -> Tween:
	var dir := (target_global - global_position).normalized()
	var tween := create_tween()
	tween.tween_property(self, "position", _home + dir * 170.0, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.06)
	tween.tween_property(self, "position", _home, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween


## Recuo curto usado por habilidades e defesa.
func brace() -> Tween:
	var back := Vector2(0.0, 26.0 if is_player else -26.0)
	var tween := create_tween()
	tween.tween_property(self, "position", _home + back, 0.14).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", _home, 0.22).set_trans(Tween.TRANS_SINE)
	return tween


func flash_hit() -> void:
	sprite.flash(Color(1.0, 0.55, 0.5))
	var tween := create_tween()
	for i in 4:
		var offset := Vector2(18.0 if i % 2 == 0 else -18.0, 0.0)
		tween.tween_property(self, "position", _home + offset, 0.045)
	tween.tween_property(self, "position", _home, 0.05)


func flash_heal() -> void:
	sprite.flash(Color(0.55, 1.0, 0.7))


## Mantém o desenho do corpo de acordo com os membros e peças que ainda existem.
func _sync_body() -> void:
	var left_leg := _intact("leg_left")
	var right_leg := _intact("leg_right")
	sprite.left_arm_intact = _intact("arm_left")
	sprite.right_arm_intact = _intact("arm_right")
	sprite.left_leg_intact = left_leg
	sprite.right_leg_intact = right_leg
	sprite.set_loadout(loadout, body)

	# Sobre uma perna só, o robô se escora para o lado que restou em vez de flutuar.
	if not is_alive():
		return
	var tilt := 0.0
	if left_leg != right_leg:
		tilt = -7.0 if left_leg else 7.0
	sprite.rotation = deg_to_rad(tilt)
	sprite.ground_offset = 10.0 if tilt != 0.0 else 0.0


func _intact(key: String) -> bool:
	var part := body.part_by_key(key)
	return part == null or part.is_intact()


func _play_death() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "modulate:a", 0.15, 0.5)
	tween.tween_property(sprite, "rotation", deg_to_rad(-18.0 if is_player else 18.0), 0.5)
	tween.tween_property(self, "position", _home + Vector2(0.0, 40.0), 0.5)
