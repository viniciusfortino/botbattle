## Camada visual da batalha: liga o BattleManager (regras) à cena e à UI.
extends Node2D

const HP_COLOR := Color("4ade80")
const HP_LOW_COLOR := Color("f87171")
const MP_COLOR := Color("60a5fa")
const DAMAGE_COLOR := Color("ff6b6b")
const CRIT_COLOR := Color("ffd166")
const HEAL_COLOR := Color("6ee7a8")
const NEUTRAL_COLOR := Color("cbd5e1")

@onready var manager: BattleManager = $BattleManager
@onready var hero: Combatant = $Actors/Hero
@onready var enemy: Combatant = $Actors/Enemy
@onready var fx: Node2D = $FX

@onready var enemy_name: Label = %EnemyName
@onready var enemy_hp: ProgressBar = %EnemyHP
@onready var enemy_hp_text: Label = %EnemyHPText
@onready var hero_name: Label = %HeroName
@onready var hero_hp: ProgressBar = %HeroHP
@onready var hero_hp_text: Label = %HeroHPText
@onready var hero_mp: ProgressBar = %HeroMP
@onready var hero_mp_text: Label = %HeroMPText
@onready var log_label: Label = %LogLabel
@onready var action_grid: GridContainer = %ActionGrid
@onready var banner: Control = %Banner
@onready var banner_label: Label = %BannerLabel
@onready var restart_button: Button = %RestartButton
@onready var hitbox_panel: HitboxDebugPanel = %HitboxPanel
@onready var bottom_panel: PanelContainer = %BottomPanel
@onready var target_picker: TargetPicker = %TargetPicker
@onready var banner_reason: Label = %BannerReason

## Altura do painel inferior com os comandos e, mais alta, com a mira aberta.
const PANEL_TOP := -420.0
const PANEL_TOP_AIMING := -620.0

## Ação escolhida no primeiro toque, à espera do alvo.
var _pending_action := ""


## O robô do jogador vem do hangar. Precisa ser em _enter_tree: o Combatant monta o
## corpo no _ready dele, que roda antes do _ready desta cena.
func _enter_tree() -> void:
	var player := get_node_or_null("/root/PlayerLoadout")
	var hero_node := get_node_or_null("Actors/Hero")
	if player != null and hero_node != null and player.current != null:
		hero_node.loadout = player.current


func _ready() -> void:
	randomize()
	banner.hide()

	_setup_bar(enemy_hp, HP_COLOR)
	_setup_bar(hero_hp, HP_COLOR)
	_setup_bar(hero_mp, MP_COLOR)

	enemy_name.text = enemy.stats.display_name
	hero_name.text = hero.stats.display_name
	hitbox_panel.track(enemy)
	target_picker.setup(enemy)
	target_picker.target_chosen.connect(_on_target_chosen)
	target_picker.cancelled.connect(_on_aim_cancelled)
	enemy.hp_changed.connect(func(_c: int, _m: int) -> void: target_picker.refresh())

	enemy.hp_changed.connect(func(c: int, m: int) -> void:
		_update_bar(enemy_hp, enemy_hp_text, c, m))
	hero.hp_changed.connect(func(c: int, m: int) -> void:
		_update_bar(hero_hp, hero_hp_text, c, m)
		_refresh_action_buttons())
	hero.mp_changed.connect(func(c: int, m: int) -> void:
		_update_bar(hero_mp, hero_mp_text, c, m, "EN ")
		_refresh_action_buttons())

	_build_action_buttons()
	restart_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/hangar/hangar.tscn"))

	manager.message.connect(_log)
	manager.round_started.connect(func(n: int) -> void: _log("— Rodada %d —" % n))
	manager.awaiting_input.connect(_on_awaiting_input)
	manager.action_performed.connect(_on_action_performed)
	manager.battle_finished.connect(_on_battle_finished)

	_set_actions_enabled(false)
	await get_tree().create_timer(0.4).timeout
	manager.start([hero], [enemy])


# --- Entrada do jogador -------------------------------------------------

func _on_awaiting_input(actor: Combatant) -> void:
	if actor != hero:
		return
	_log("Sua vez. O que R-7 deve fazer?")
	_refresh_action_buttons()
	_set_actions_enabled(true)


func _on_action_pressed(action_id: String) -> void:
	if manager.current != hero or manager.finished:
		return
	if not hero.can_use(action_id):
		return
	_set_actions_enabled(false)

	var kind := String(Actions.get_action(action_id).get("kind", Actions.DAMAGE))
	if kind != Actions.DAMAGE:
		manager.perform(hero, action_id, hero)
		return

	# Ataque: segundo toque escolhe a hitbox.
	if manager.first_target_for(hero) == null:
		return
	_pending_action = action_id
	_open_aim()


# --- Mira (segundo toque) ---------------------------------------------

func _open_aim() -> void:
	target_picker.refresh()
	action_grid.hide()
	target_picker.show()
	_slide_panel(PANEL_TOP_AIMING)


func _close_aim() -> void:
	target_picker.hide()
	action_grid.show()
	_slide_panel(PANEL_TOP)


func _slide_panel(top: float) -> void:
	create_tween().tween_property(bottom_panel, "offset_top", top, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_target_chosen(part: BodyPart) -> void:
	_close_aim()
	var target := manager.first_target_for(hero)
	if target == null or _pending_action.is_empty():
		return
	var action_id := _pending_action
	_pending_action = ""
	manager.perform(hero, action_id, target, part)


func _on_aim_cancelled() -> void:
	_pending_action = ""
	_close_aim()
	_set_actions_enabled(true)


## Os botões vêm da montagem: uma ação por peça equipada, mais o Defender do chassi.
func _build_action_buttons() -> void:
	for child in action_grid.get_children():
		child.queue_free()

	var entries := hero.available_actions()
	action_grid.columns = clampi(entries.size(), 1, 3)
	for entry in entries:
		var id := String(entry["id"])
		var button := Button.new()
		button.set_meta("action", id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_action_pressed.bind(id))
		action_grid.add_child(button)
	_refresh_action_buttons()


func _action_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in action_grid.get_children():
		if child is Button and child.has_meta("action"):
			buttons.append(child)
	return buttons


func _set_actions_enabled(enabled: bool) -> void:
	for button in _action_buttons():
		button.disabled = not enabled or not hero.can_use(String(button.get_meta("action")))


## O rótulo do botão conta o estado da arma: custo, desgaste ou a perda do braço.
func _refresh_action_buttons() -> void:
	for button in _action_buttons():
		var id := String(button.get_meta("action"))
		var missing := hero.missing_requirement(id)
		var weapon_part := hero.power_part_for(id)
		var status: Array[String] = []

		if missing != null:
			var immobile := missing.kind == BodyPart.Kind.LEG_LEFT \
				or missing.kind == BodyPart.Kind.LEG_RIGHT
			status.append("imobilizado" if immobile else "perdido")
		else:
			if Actions.cost(id) > 0:
				status.append("%d EN" % Actions.cost(id))
			if weapon_part != null and weapon_part.ratio() < 1.0:
				status.append("%d%%" % roundi(hero.weapon_efficiency(id) * 100.0))

		button.text = Actions.action_name(id)
		if not status.is_empty():
			button.text += "\n" + " · ".join(status)


# --- Execução de uma ação -----------------------------------------------

func _on_action_performed(result: Dictionary) -> void:
	_set_actions_enabled(false)
	_log(_describe(result))

	var actor: Combatant = result["actor"]
	var target: Combatant = result["target"]

	if not actor.is_player:
		await get_tree().create_timer(0.5).timeout

	# A pose do corpo entra junto com o avanço ou o recuo, não no lugar deles: uma sai da
	# anatomia (ossos), a outra é o nó inteiro se deslocando pela arena.
	#
	# Guardamos o fim dela para o turno não virar por cima. Hoje isso nunca chega a
	# segurar nada: a espera que já existia — a animação da ação mais os 0,75s lá embaixo
	# — dá 1,05s no caminho mais curto (o feixe), e a pose mais longa tem 0,8s. A guarda
	# é para quando as animações passarem disso.
	var pose_seconds := actor.play_body_animation(String(result["action_id"]))
	var pose_ends_at := Time.get_ticks_msec() + int(pose_seconds * 1000.0)

	match String(result["kind"]):
		Actions.DAMAGE:
			if String(result["action_id"]) == "plasma":
				await _play_beam(actor, target)
				manager.commit(result)
				_show_result_fx(result)
			else:
				var tween := actor.lunge(target.global_position)
				await get_tree().create_timer(0.22).timeout
				manager.commit(result)
				_show_result_fx(result)
				await tween.finished
		_:
			await actor.brace().finished
			manager.commit(result)
			_show_result_fx(result)

	await get_tree().create_timer(0.75).timeout
	if manager.finished:
		return

	# O que sobrar da pose, quando ela for mais longa que a espera acima.
	var pose_left := float(pose_ends_at - Time.get_ticks_msec()) / 1000.0
	if pose_left > 0.0:
		await get_tree().create_timer(pose_left).timeout
	manager.next_turn()


func _describe(result: Dictionary) -> String:
	var actor: Combatant = result["actor"]
	var target: Combatant = result["target"]
	var template := String(result["action"].get("log", "%s age."))
	if template.count("%s") >= 2:
		return template % [actor.stats.display_name, target.stats.display_name]
	return template % actor.stats.display_name


func _show_result_fx(result: Dictionary) -> void:
	var target: Combatant = result["target"]
	var spot := fx.to_local(target.global_position) + Vector2(randf_range(-70.0, 70.0), -RobotSprite.HEIGHT * target.visual_scale + 40.0)

	match String(result["kind"]):
		Actions.DAMAGE:
			if result["missed"]:
				DamageNumber.spawn(fx, spot, "Errou", NEUTRAL_COLOR)
			else:
				target.flash_hit()
				var crit: bool = result["crit"]
				var part: BodyPart = result["part"]
				var label := "" if part == null else part.display_name
				DamageNumber.spawn(fx, spot, str(result["damage"]),
					CRIT_COLOR if crit else DAMAGE_COLOR, crit, label)
		Actions.HEAL:
			target.flash_heal()
			DamageNumber.spawn(fx, spot, "+%d" % result["healed"], HEAL_COLOR)
		Actions.GUARD:
			DamageNumber.spawn(fx, spot, "Guarda", target.stats.accent_color)


func _play_beam(actor: Combatant, target: Combatant) -> void:
	var charge := actor.brace()
	await get_tree().create_timer(0.16).timeout

	var beam := Line2D.new()
	beam.width = 20.0
	beam.default_color = actor.stats.accent_color
	beam.z_index = 50
	beam.points = PackedVector2Array([
		fx.to_local(actor.global_position) + Vector2(0.0, -RobotSprite.HEIGHT * 0.55 * actor.visual_scale),
		fx.to_local(target.global_position) + Vector2(0.0, -RobotSprite.HEIGHT * 0.55 * target.visual_scale),
	])
	fx.add_child(beam)

	var tween := create_tween()
	tween.tween_property(beam, "width", 64.0, 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(beam, "modulate:a", 0.0, 0.3)
	tween.tween_callback(beam.queue_free)

	await get_tree().create_timer(0.14).timeout
	if charge.is_valid():
		charge.kill()
		actor.brace()


# --- Fim de batalha e HUD -----------------------------------------------

func _on_battle_finished(player_won: bool) -> void:
	_set_actions_enabled(false)
	if target_picker.visible:
		_close_aim()
	await get_tree().create_timer(0.9).timeout
	banner_label.text = "VITÓRIA" if player_won else "DERROTA"
	banner_label.add_theme_color_override("font_color", HEAL_COLOR if player_won else HP_LOW_COLOR)
	banner_reason.text = manager.end_reason
	banner_reason.visible = not manager.end_reason.is_empty()
	banner.show()
	banner.modulate.a = 0.0
	create_tween().tween_property(banner, "modulate:a", 1.0, 0.4)


func _log(text: String) -> void:
	log_label.text = text
	log_label.modulate.a = 0.35
	create_tween().tween_property(log_label, "modulate:a", 1.0, 0.2)


func _setup_bar(bar: ProgressBar, color: Color) -> void:
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("fill", fill)


func _update_bar(bar: ProgressBar, label: Label, current: int, maximum: int, prefix: String = "") -> void:
	bar.max_value = maximum
	create_tween().tween_property(bar, "value", float(current), 0.35).set_trans(Tween.TRANS_QUAD)
	label.text = "%s%d/%d" % [prefix, current, maximum]

	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null and prefix.is_empty():
		fill.bg_color = HP_LOW_COLOR if float(current) / float(maximum) <= 0.3 else HP_COLOR
