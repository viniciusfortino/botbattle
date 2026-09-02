## Teste de fumaça: joga uma batalha inteira sozinho e salva PNGs em res://.captures/.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/smoke_test.gd
##
## Sai com código 0 se a batalha terminou, 1 se travou.
extends SceneTree

const OUT := "res://.captures/"
const TIMEOUT_SECONDS := 90.0

var battle: Node
var manager: BattleManager


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1080, 1920))

	battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	manager = battle.get_node("BattleManager")
	manager.awaiting_input.connect(_on_awaiting_input)
	manager.battle_finished.connect(_on_finished)
	manager.message.connect(func(text: String) -> void: print("[log] ", text))

	await create_timer(1.4).timeout
	_shot("01_inicio")
	await create_timer(TIMEOUT_SECONDS).timeout
	push_error("A batalha não terminou em %d s." % TIMEOUT_SECONDS)
	quit(1)


func _on_awaiting_input(_actor: Combatant) -> void:
	await create_timer(0.3).timeout
	_shot("02_rodada_%d" % manager.round_number)

	var ids := ["attack", "plasma", "guard"]
	var id: String = ids[randi() % ids.size()]
	if not battle.hero.can_use(id):
		id = "attack" if battle.hero.can_use("attack") else "guard"
	print("[jogador] %s | R-7 %d HP / %d EN | %s %d HP" % [
		id, battle.hero.hp, battle.hero.mp, battle.enemy.stats.display_name, battle.enemy.hp])
	battle._on_action_pressed(id)

	# Ataque abre o seletor de alvo: metade dos golpes mira, metade fica no aleatório.
	if String(Actions.get_action(id).get("kind", "")) != Actions.DAMAGE:
		return
	await create_timer(0.25).timeout
	var aim: BodyPart = null
	if randf() < 0.5:
		var options: Array = battle.enemy.body.intact_parts()
		if not options.is_empty():
			aim = options[randi() % options.size()]
			print("       mirando %s (%d%% de chance)" % [
				aim.display_name, roundi(battle.enemy.body.aim_chance(aim) * 100.0)])
	battle._on_target_chosen(aim)


func _on_finished(player_won: bool) -> void:
	await create_timer(1.6).timeout
	_shot("99_fim")
	var reason := "desarme" if not manager.end_reason.is_empty() else "vida zerada"
	print("### Fim da batalha — jogador venceu: %s | rodadas: %d | motivo: %s" % [
		player_won, manager.round_number, reason])
	quit(0)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
