## Verificação da §6.1.3 do plano PixelLab: CharacterArt devolve o quadro inteiro,
## sem recorte, e a cascata de estado de dano funciona.
extends SceneTree


func _initialize() -> void:
	var t := CharacterArt.texture("mk1_torso", "south")
	assert(t != null, "mk1_torso/Idle/rotations/south.png não carregou")
	assert(t.get_size() == Vector2(128, 128), "a textura foi recortada — ver §11.1")

	var h := CharacterArt.texture("mk1_hip", "south")
	assert(h.get_size() == Vector2(136, 136), "o canvas do quadril é 136, não 128")

	# cascata: o braço não tem arte de dano, então tem de cair na íntegra
	var a := CharacterArt.texture("mk1_arm_left", "south", BodyPart.Condition.CRITICAL)
	assert(a != null and a == CharacterArt.texture("mk1_arm_left", "south"))

	# a cabeça TEM arte de dano, então não pode cair na íntegra
	var d := CharacterArt.texture("mk1_head", "south", BodyPart.Condition.DAMAGED)
	assert(d != CharacterArt.texture("mk1_head", "south"))

	assert(CharacterArt.texture("laser_cannon", "south") != null)
	assert("Idle_critical" in CharacterArt.poses("mk1_head"))

	print("OK — §6.1.3 passou: 128x128, 136x136, cascata de dano, poses().")
	quit(0)
