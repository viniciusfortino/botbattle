## Migração dos nove campos nomeados de encaixe (Loadout.head_top, .arm_left_part…)
## para o dicionário genérico `slots`, que a Fase 5 do plano de anatomia introduziu.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/migrate_loadouts.gd
##
## Só roda contra os campos legados enquanto eles existirem em combat/loadout.gd — depois
## de confirmado o diff, os campos saem do script e este arquivo fica no repositório como
## registro da migração (não há mais nada para ele fazer depois disso).
extends SceneTree

const PATHS := ["res://content/units/r7.tres", "res://content/units/sentinel_v9.tres"]

const LEGACY_KEYS := [
	"head_top", "back_1", "back_2", "chest_1", "chest_2",
	"arm_left_part", "arm_right_part", "leg_left_part", "leg_right_part",
]

## Nome do campo legado -> chave do encaixe no dicionário novo.
const SLOT_OF := {
	"head_top": "head_top", "back_1": "back_1", "back_2": "back_2",
	"chest_1": "chest_1", "chest_2": "chest_2",
	"arm_left_part": "arm_left", "arm_right_part": "arm_right",
	"leg_left_part": "leg_left", "leg_right_part": "leg_right",
}


func _initialize() -> void:
	for path in PATHS:
		var loadout: Loadout = load(path)
		# Só mexe em `slots` se achar campo legado — depois que ele sai do script,
		# `get()` devolve null pra todos, e rodar de novo só resalva (o que já limpa
		# as linhas legadas do .tres, porque o script não as declara mais).
		for legacy_key in LEGACY_KEYS:
			var part: Part = loadout.get(legacy_key)
			if part != null:
				loadout.slots[SLOT_OF[legacy_key]] = part
		ResourceSaver.save(loadout, path)
		print("montagem migrada: ", path)
	quit(0)
