## Critério 5 da §10: o robô não muda de tamanho ao girar. Confere que o canvas
## devolvido por CharacterArt é sempre o mesmo, em qualquer direção.
extends SceneTree

func _initialize() -> void:
	var dirs := ["south", "south-east", "east", "north-east", "north",
		"north-west", "west", "south-west"]
	var art_ids := ["mk1_head", "mk1_torso", "mk1_arm_left", "mk1_arm_right", "mk1_leg_left", "mk1_leg_right"]
	for art_id in art_ids:
		var sizes: Array[Vector2] = []
		for dir in dirs:
			var t := CharacterArt.texture(art_id, dir)
			assert(t != null, "%s/%s não carregou" % [art_id, dir])
			sizes.append(t.get_size())
		for s in sizes:
			assert(s == sizes[0], "%s: tamanho mudou entre direções (%s vs %s)" % [art_id, s, sizes[0]])
		print(art_id, " ok, ", sizes[0], " em todas as 8 direções")

	var hip_sizes: Array[Vector2] = []
	for dir in dirs:
		var t := CharacterArt.texture("mk1_hip", dir)
		assert(t != null)
		hip_sizes.append(t.get_size())
	for s in hip_sizes:
		assert(s == hip_sizes[0])
	print("hip ok, ", hip_sizes[0], " em todas as 8 direções")

	print("OK — bbox estável nas 8 direções, nada foi recortado.")
	quit(0)
