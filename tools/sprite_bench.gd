## Banco de teste do RobotSprite: desenha o r7 em montada (calibração), o r7 em
## fullbody (visão de herói) e o sentinel_v9 em montada (visão de inimigo), com vida
## cheia e sem respiração, e salva um PNG. É a referência visual para comparar antes e
## depois de mexer no desenho.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/sprite_bench.gd
extends SceneTree

const OUT := "res://.captures/bench.png"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://.captures/")
	DisplayServer.window_set_size(Vector2i(1080, 1834))

	var bg := ColorRect.new()
	bg.color = Color("101827")
	bg.size = Vector2(1080, 1834)
	root.add_child(bg)

	var specs := [
		# [loadout, force_montada, direction, x]
		["res://units/r7.tres", true, "south", 200.0],
		["res://units/r7.tres", false, "east", 540.0],
		["res://units/sentinel_v9.tres", true, "south", 880.0],
	]
	for spec in specs:
		var lo: Loadout = load(String(spec[0]))
		var sprite := RobotSprite.new()
		sprite.bob_enabled = false
		sprite.force_montada = bool(spec[1])
		sprite.direction = String(spec[2])
		sprite.position = Vector2(float(spec[3]), 900.0)
		sprite.scale = Vector2.ONE * 1.0
		root.add_child(sprite)
		sprite.set_loadout(lo, Body.from_loadout(lo))

	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("### banco salvo em ", OUT)
	quit(0)
