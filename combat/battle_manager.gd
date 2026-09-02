## Regras da batalha por turnos. Não conhece a UI: só emite sinais.
##
## Fluxo de um turno:
##   next_turn() -> awaiting_input (jogador) ou perform() automático (IA)
##   perform()   -> calcula o resultado e emite action_performed
##   a view anima, chama commit(result) e depois next_turn()
class_name BattleManager
extends Node

signal message(text: String)
signal round_started(number: int)
signal awaiting_input(actor: Combatant)
signal action_performed(result: Dictionary)
signal action_committed(result: Dictionary)
signal battle_finished(player_won: bool)

var party: Array[Combatant] = []
var foes: Array[Combatant] = []
var current: Combatant = null
var round_number: int = 0
var finished: bool = false
## Por que a batalha acabou: "" (vida zerada) ou o texto do desarme.
var end_reason: String = ""

var _queue: Array[Combatant] = []


func start(player_side: Array[Combatant], enemy_side: Array[Combatant]) -> void:
	party = player_side
	foes = enemy_side
	finished = false
	end_reason = ""
	round_number = 0
	_queue.clear()
	message.emit("Sistemas de combate on-line.")
	next_turn()


func next_turn() -> void:
	if finished or _check_end():
		return

	while not _queue.is_empty() and not _queue[0].is_alive():
		_queue.pop_front()
	if _queue.is_empty():
		_start_round()

	current = _queue.pop_front()
	current.guarding = false

	if current.is_player:
		awaiting_input.emit(current)
	else:
		var choice := _choose_ai_action(current)
		perform(current, choice["action"], choice["target"], choice.get("aimed"))


## Calcula o efeito da ação sem aplicá-lo ainda (a view anima antes de commit).
## `aimed` é a hitbox que o atacante escolheu; null significa golpe sem mira.
func perform(actor: Combatant, action_id: String, target: Combatant,
		aimed: BodyPart = null) -> Dictionary:
	var action := Actions.get_action(action_id).duplicate()
	action["id"] = action_id
	var result := {
		"actor": actor,
		"target": target,
		"action_id": action_id,
		"action": action,
		"kind": action.get("kind", Actions.DAMAGE),
		"mp_cost": int(action.get("mp", 0)),
		"damage": 0,
		"healed": 0,
		"crit": false,
		"missed": false,
		"part": null,
		"aimed": aimed,
	}

	match result["kind"]:
		Actions.DAMAGE:
			if randf() > float(action.get("accuracy", 1.0)):
				result["missed"] = true
			else:
				var roll := _roll_damage(actor, target, action, aimed)
				result["damage"] = roll["damage"]
				result["crit"] = roll["crit"]
				result["part"] = roll["part"]
		Actions.HEAL:
			result["healed"] = int(action.get("amount", 0))
		Actions.GUARD:
			pass

	action_performed.emit(result)
	return result


## Aplica o resultado ao estado do jogo. Chamado pela view no impacto.
func commit(result: Dictionary) -> void:
	var actor: Combatant = result["actor"]
	var target: Combatant = result["target"]
	var cost: int = result["mp_cost"]
	if cost > 0:
		actor.change_mp(-cost)

	match result["kind"]:
		Actions.DAMAGE:
			if result["missed"]:
				message.emit("%s errou o golpe." % actor.stats.display_name)
			else:
				var info := target.apply_damage(result["damage"], result["part"])
				result["destroyed"] = info["destroyed"]
				var part: BodyPart = info["part"]
				var suffix := " CRÍTICO!" if result["crit"] else ""
				var aimed_at: BodyPart = result["aimed"]
				if aimed_at != null and aimed_at != part:
					message.emit("%s mira %s e acerta %s: %d de dano.%s" % [
						actor.stats.display_name, aimed_at.narrative_name,
						_part_label(part), info["dealt"], suffix])
				else:
					message.emit("%s acertou %s: %d de dano.%s" % [
						actor.stats.display_name, _part_label(part), info["dealt"], suffix])
				for broken in info["destroyed"]:
					message.emit("%s perdeu %s!%s" % [
						target.stats.display_name, broken.narrative_name,
						_capability_loss(target, broken)])
		Actions.HEAL:
			var restored := target.heal(result["healed"])
			result["healed"] = restored
			message.emit("%s recuperou %d de vida." % [target.stats.display_name, restored])
		Actions.GUARD:
			actor.guarding = true
			actor.change_mp(int(result["action"].get("mp_regen", 0)))
			message.emit("%s está em posição defensiva." % actor.stats.display_name)

	action_committed.emit(result)
	_check_end()


func living(group: Array[Combatant]) -> Array[Combatant]:
	return group.filter(func(c: Combatant) -> bool: return c.is_alive())


func first_target_for(actor: Combatant) -> Combatant:
	var pool := living(foes if actor.is_player else party)
	return pool[0] if not pool.is_empty() else null


func _start_round() -> void:
	round_number += 1
	var order := living(party) + living(foes)
	order.shuffle()
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return a.stats.speed > b.stats.speed)
	_queue = order
	round_started.emit(round_number)


func _check_end() -> bool:
	if finished:
		return true
	if living(foes).is_empty():
		finished = true
		battle_finished.emit(true)
		return true
	if living(party).is_empty():
		finished = true
		battle_finished.emit(false)
		return true

	# Segunda condição de fim: um lado de pé, mas sem nenhuma forma de atacar.
	if not _side_can_fight(foes):
		return _finish_by_disarm(foes, true)
	if not _side_can_fight(party):
		return _finish_by_disarm(party, false)
	return false


func _side_can_fight(group: Array[Combatant]) -> bool:
	for combatant in living(group):
		if combatant.has_offense():
			return true
	return false


func _finish_by_disarm(group: Array[Combatant], player_won: bool) -> bool:
	finished = true
	var names: Array[String] = []
	for combatant in living(group):
		names.append(combatant.stats.display_name)
	end_reason = "%s sem meios de atacar" % " e ".join(names)
	message.emit("%s não tem mais como atacar. Fim de combate." % " e ".join(names))
	battle_finished.emit(player_won)
	return true


func _roll_damage(actor: Combatant, target: Combatant, action: Dictionary,
		aimed: BodyPart = null) -> Dictionary:
	var power := float(action.get("power", 1.0))
	var pierce := float(action.get("pierce", 0.0))
	var offense := float(actor.stats.attack) * power * actor.weapon_efficiency(String(action.get("id", "attack")))
	var defense := float(target.stats.defense) * (1.0 - pierce)
	if target.guarding:
		defense *= 2.0

	var raw := maxf(1.0, offense - defense * 0.5) * randf_range(0.9, 1.12)

	# Hitbox e crítico somam bônus em vez de se multiplicarem: empilhados, um acerto
	# crítico na cabeça com a arma pesada matava quase de um golpe só.
	var part := target.body.aimed_target(aimed)
	var bonus := 1.0
	if part != null:
		bonus += part.damage_multiplier - 1.0
	var crit := randf() < float(action.get("crit", 0.0))
	if crit:
		bonus += 0.75
	raw *= bonus

	if target.guarding:
		raw *= 0.55
	return {"damage": maxi(1, int(round(raw))), "crit": crit, "part": part}


## O que o alvo deixa de conseguir fazer por ter perdido essa hitbox.
static func _capability_loss(target: Combatant, part: BodyPart) -> String:
	var labels := target.capabilities_lost_with(part)
	if labels.is_empty():
		return ""
	var text := " e ".join(labels)
	if part.kind == BodyPart.Kind.LEG_LEFT or part.kind == BodyPart.Kind.LEG_RIGHT:
		return " Imobilizado — sem %s." % text
	return " Sem %s." % text


static func _part_label(part: BodyPart) -> String:
	return "o corpo" if part == null else part.narrative_name


func _choose_ai_action(actor: Combatant) -> Dictionary:
	var target := first_target_for(actor)
	var hp_ratio := float(actor.hp) / float(actor.max_hp)

	if actor.can_use("plasma") and randf() < 0.45:
		return {"action": "plasma", "target": target, "aimed": _ai_aim(target)}
	if hp_ratio < 0.5 and randf() < 0.18:
		return {"action": "guard", "target": actor, "aimed": null}
	if actor.can_use("attack"):
		return {"action": "attack", "target": target, "aimed": _ai_aim(target)}
	if actor.can_use("plasma"):
		return {"action": "plasma", "target": target, "aimed": _ai_aim(target)}
	return {"action": "guard", "target": actor, "aimed": null}


## Em 40% dos golpes a IA mira para desarmar: primeiro a peça que dá a arma mais
## perigosa, depois a mobilidade, depois a cabeça.
func _ai_aim(target: Combatant) -> BodyPart:
	if target == null or randf() >= 0.4:
		return null

	var best: BodyPart = null
	var best_power := 0.0
	for entry in target.available_actions():
		var id := String(entry["id"])
		if Actions.kind_of(id) != Actions.DAMAGE:
			continue
		var key := String(entry["key"])
		if key.is_empty():
			continue
		var hitbox := target.body.part_by_key(key)
		if hitbox == null or not hitbox.is_intact():
			continue
		var power := float(Actions.get_action(id).get("power", 1.0))
		if power > best_power:
			best_power = power
			best = hitbox
	if best != null:
		return best

	for key in ["leg_left", "leg_right"]:
		var leg := target.body.part_by_key(key)
		if leg != null and leg.is_intact():
			return leg

	var head := target.body.part_by_key("head")
	return head if head != null and head.is_intact() else null
