## Migração de `Part.grants_action` (String) para `Part.grants_actions` (Array[String]),
## que a Fase 6 do plano de anatomia introduziu — uma peça pode conceder mais de uma ação.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/migrate_parts.gd
##
## Só faz alguma coisa enquanto `grants_action` existir em combat/part.gd — depois que o
## campo legado sai do script, `get()` devolve null e rodar de novo só resalva (o que
## limpa a linha antiga do .tres, porque o script não a declara mais). Fica no
## repositório como registro da migração.
extends SceneTree


func _initialize() -> void:
	for id in PartCatalog.IDS:
		var path := "res://parts/%s.tres" % id
		var part: Part = load(path)
		var legacy = part.get("grants_action")
		if legacy != null and not String(legacy).is_empty() and part.grants_actions.is_empty():
			part.grants_actions = [String(legacy)]
		ResourceSaver.save(part, path)
		print("peça migrada: ", path)
	quit(0)
