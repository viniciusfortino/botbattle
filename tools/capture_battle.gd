## Ferramenta descartável: sobe a cena real da batalha e salva um PNG, pra julgar as
## fileiras de ações (ActionStatusRow) que substituíram as barras de HP.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/capture_battle.gd
extends SceneTree

const OUT := "res://.captures/battle.png"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://.captures/")
	DisplayServer.window_set_size(Vector2i(1080, 1920))

	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)

	await create_timer(1.2).timeout
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("### captura salva em ", OUT)
	quit(0)
