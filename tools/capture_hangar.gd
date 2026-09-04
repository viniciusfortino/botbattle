## Ferramenta descartável: sobe a cena real do hangar e salva um PNG, pra julgar o
## enquadramento novo (robô grande, painéis finos) sem abrir o editor.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/capture_hangar.gd
extends SceneTree

const OUT := "res://.captures/hangar.png"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://.captures/")
	DisplayServer.window_set_size(Vector2i(1080, 1920))

	var hangar: Node = load("res://scenes/hangar/hangar.tscn").instantiate()
	root.add_child(hangar)

	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("### captura salva em ", OUT)
	quit(0)
