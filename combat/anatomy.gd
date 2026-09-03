## A forma de um robô: que ossos ele tem, onde as peças entram e como ele se move.
##
## É a declaração única do esqueleto — `Body`, `Loadout`, `Combatant` e `RobotSprite`
## leem daqui em vez de cada um manter a sua cópia.
@tool
class_name Anatomy
extends Resource

@export var id: String = "humanoid"
@export var display_name: String = "Humanoide"
@export var bones: Array[BoneDef] = []
## Na ordem em que o hangar lista os encaixes.
@export var slots: Array[SlotDef] = []
## Animações de corpo, escritas contra os caminhos de nó que saem das chaves dos ossos.
@export var animations: AnimationLibrary


## O osso de uma chave. Os ossos vivem em array e não em dicionário porque a ordem deles
## é a ordem das hitboxes no `Body` — procurar de um em um é o preço de manter isso.
func bone(key: String) -> BoneDef:
	for b in bones:
		if b.key == key:
			return b
	return null


## O encaixe de uma chave, pelo mesmo motivo do `bone()`: `slots` é array porque a ordem
## dele é a ordem em que o hangar lista os encaixes.
func slot(key: String) -> SlotDef:
	for s in slots:
		if s.key == key:
			return s
	return null


## As chaves dos encaixes, na ordem da anatomia. Saem daqui e não de uma constante como a
## antiga `Loadout.SLOT_KEYS` porque um robô de outra forma tem outros encaixes — quem
## percorre a montagem não deveria precisar saber de que forma ela é.
func slot_keys() -> Array[String]:
	var keys: Array[String] = []
	for s in slots:
		keys.append(s.key)
	return keys


## Os ossos em ordem de hierarquia (pai antes de filho). Com todo `parent` vazio (como
## na Fase 3), isso equivale à ordem de declaração — cada osso é a própria raiz.
func bones_in_order() -> Array[BoneDef]:
	var by_key := {}
	for b in bones:
		by_key[b.key] = b

	var result: Array[BoneDef] = []
	var visited := {}
	var visit: Callable
	visit = func(b: BoneDef, self_ref: Callable) -> void:
		if visited.has(b.key):
			return
		visited[b.key] = true
		if not b.parent.is_empty() and by_key.has(b.parent):
			self_ref.call(by_key[b.parent], self_ref)
		result.append(b)
	for b in bones:
		visit.call(b, visit)
	return result


## Os tipos de peça que este encaixe aceita, somando todos os modos.
func accepted_slots(slot_key: String) -> Array[Part.Slot]:
	var result: Array[Part.Slot] = []
	var def := slot(slot_key)
	if def == null:
		return result
	for mount in def.mounts:
		if not result.has(mount.accepts):
			result.append(mount.accepts)
	return result


## O modo pelo qual esta peça entra neste encaixe (null se ela não cabe).
func mount_for(slot_key: String, part: Part) -> MountDef:
	if part == null:
		return null
	var def := slot(slot_key)
	if def == null:
		return null
	for mount in def.mounts:
		if mount.accepts == part.slot:
			return mount
	return null


## A chave da hitbox que esta peça ocupa: o osso hospedeiro quando ela o substitui,
## senão "part:<slot_key>". É a única resposta para essa pergunta no projeto inteiro.
func hitbox_key(slot_key: String, part: Part) -> String:
	var mount := mount_for(slot_key, part)
	var def := slot(slot_key)
	if mount != null and mount.replaces_host and def != null:
		return def.host_bone
	return "part:%s" % slot_key


## O caminho do nó desta peça dentro do RobotSprite: "hip/torso/back_1".
func node_path(slot_key: String) -> String:
	var def := slot(slot_key)
	if def == null:
		return slot_key
	return "%s/%s" % [_bone_path(def.host_bone), slot_key]


func _bone_path(bone_key: String) -> String:
	var b := bone(bone_key)
	if b == null or b.parent.is_empty():
		return bone_key
	return "%s/%s" % [_bone_path(b.parent), bone_key]
