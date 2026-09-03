## Migração de atributos nomeados (Chassis.strength, Part.agility…) para os dicionários
## genéricos (base_stats, modifiers) que o StatSchema lê.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/migrate_stats.gd
##
## Fica no repositório depois de rodada uma vez — documenta a migração, e rodar de novo
## depois de apagar os campos antigos não deve gerar diff nenhum (usa `get()` dinâmico,
## que devolve null em vez de errar quando o campo já sumiu).
extends SceneTree

const STAT_KEYS := ["strength", "agility", "defense", "energy"]
const CHASSIS_PATHS := [
	"res://chassis/mk1.tres",
	"res://assets/chassis/mk2_goliath.tres",
	"res://assets/chassis/mk3_strider.tres",
]


func _initialize() -> void:
	for id in PartCatalog.IDS:
		_migrate_part("res://parts/%s.tres" % id)
	for path in CHASSIS_PATHS:
		_migrate_chassis(path)
	quit(0)


func _migrate_part(path: String) -> void:
	var part: Part = load(path)
	for key in STAT_KEYS:
		var value := _old_value(part, key)
		if value != 0:
			part.modifiers[key] = value
	ResourceSaver.save(part, path)
	print("peça migrada: ", path)


func _migrate_chassis(path: String) -> void:
	var chassis: Chassis = load(path)
	for key in STAT_KEYS + ["capacity"]:
		var value := _old_value(chassis, key)
		if value != 0:
			chassis.base_stats[key] = value
	chassis.schema = load("res://stats/default.tres")
	ResourceSaver.save(chassis, path)
	print("chassi migrado: ", path)


## O valor do campo antigo, ou 0 se ele já não existe (segunda rodada, pós-Fase 2d).
func _old_value(resource: Resource, key: String) -> int:
	var raw = resource.get(key)
	return int(raw) if raw != null else 0
