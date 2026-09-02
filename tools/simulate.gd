## Simulador de balanceamento: roda centenas de batalhas só no modelo, sem cena nem
## animação, e reporta o placar. É a ferramenta para mexer em números com dados.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/simulate.gd
##
## A política do jogador simulado está em `_player_move()` — troque-a para comparar
## estratégias (jogar no aleatório, mirar para desarmar, etc).
extends SceneTree

const BATTLES := 200

var _pending: Dictionary = {}


func _initialize() -> void:
	randomize()
	await process_frame
	var hero_stats: Loadout = load("res://units/r7.tres")
	var foe_stats: Loadout = load("res://units/sentinel_v9.tres")

	for policy in ["sem_mira", "aleatoria", "desarmar"]:
		var wins := 0
		var by_disarm := 0
		var rounds := 0
		for i in BATTLES:
			var outcome := _run_battle(hero_stats, foe_stats, policy)
			wins += 1 if outcome["won"] else 0
			by_disarm += 1 if outcome["disarm"] else 0
			rounds += int(outcome["rounds"])
		print("jogador %-9s | vitórias %3d%% | por desarme %3d%% | rodadas médias %4.1f" % [
			policy, roundi(100.0 * wins / BATTLES), roundi(100.0 * by_disarm / BATTLES),
			float(rounds) / BATTLES])
	quit(0)


func _run_battle(hero_stats: Loadout, foe_stats: Loadout, policy: String) -> Dictionary:
	var hero := _make(hero_stats, true)
	var foe := _make(foe_stats, false)
	var manager := BattleManager.new()
	root.add_child(manager)

	_pending = {}
	manager.action_performed.connect(func(result: Dictionary) -> void: _pending = result)
	manager.awaiting_input.connect(func(actor: Combatant) -> void:
		var move := _player_move(actor, foe, policy)
		manager.perform(actor, move["action"], move["target"], move["aimed"]))

	manager.start([hero], [foe])
	var guard := 0
	while not manager.finished and guard < 400:
		guard += 1
		if not _pending.is_empty():
			var result := _pending
			_pending = {}
			manager.commit(result)
		if not manager.finished:
			manager.next_turn()

	var outcome := {
		"won": foe.hp == 0 or not foe.has_offense(),
		"disarm": not manager.end_reason.is_empty(),
		"rounds": manager.round_number,
	}
	manager.free()
	hero.free()
	foe.free()
	return outcome


## O que o jogador simulado faz no turno dele.
func _player_move(actor: Combatant, foe: Combatant, policy: String) -> Dictionary:
	var aimed: BodyPart = null
	if policy == "desarmar":
		aimed = _disarm_target(foe)
	elif policy == "aleatoria" and randf() < 0.5:
		var options: Array = foe.body.intact_parts()
		if not options.is_empty():
			aimed = options[randi() % options.size()]

	# Recuar para aparar o golpe e recarregar, como a IA faz.
	var hp_ratio := float(actor.hp) / float(actor.max_hp)
	if hp_ratio < 0.5 and actor.mp < Actions.cost("plasma") and randf() < 0.4:
		return {"action": "guard", "target": actor, "aimed": null}

	if actor.can_use("plasma") and randf() < 0.55:
		return {"action": "plasma", "target": foe, "aimed": aimed}
	if actor.can_use("attack"):
		return {"action": "attack", "target": foe, "aimed": aimed}
	if actor.can_use("plasma"):
		return {"action": "plasma", "target": foe, "aimed": aimed}
	return {"action": "guard", "target": actor, "aimed": null}


## Mesma prioridade que a IA usa: tirar a arma pesada, depois a mobilidade.
func _disarm_target(foe: Combatant) -> BodyPart:
	var plasma_arm := foe.body.part_by_key("part:arm_left")
	if plasma_arm != null and plasma_arm.is_intact():
		return plasma_arm
	for key in ["leg_left", "leg_right"]:
		var leg := foe.body.part_by_key(key)
		if leg != null and leg.is_intact():
			return leg
	return null


func _make(loadout: Loadout, is_player: bool) -> Combatant:
	var combatant := Combatant.new()
	var sprite := RobotSprite.new()
	sprite.name = "Sprite"
	sprite.bob_enabled = false
	combatant.add_child(sprite)
	combatant.loadout = loadout
	combatant.is_player = is_player
	root.add_child(combatant)
	return combatant
