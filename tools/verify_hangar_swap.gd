## Critério 3 da §10: no hangar, trocar uma peça muda visivelmente o robô montado.
extends SceneTree

const OUT := "res://.captures/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_size(Vector2i(1080, 1920))

	var hangar: Node = load("res://scenes/hangar/hangar.tscn").instantiate()
	root.add_child(hangar)
	await process_frame
	await process_frame

	hangar.loadout.equip("arm_left", load("res://content/catalog/parts/plasma_cannon.tres"))
	hangar._refresh()
	await process_frame
	await create_timer(0.3).timeout
	_shot("hangar_plasma")

	hangar.loadout.equip("arm_left", load("res://content/catalog/parts/heavy_arm.tres"))
	hangar._refresh()
	await process_frame
	await create_timer(0.3).timeout
	_shot("hangar_heavy_arm")

	quit(0)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
