## Gera a biblioteca de animações de corpo da anatomia humanoide.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/make_animations.gd
##
## As poses saem da própria anatomia (a posição de repouso de cada osso), então mexer
## na pose e rodar isto de novo mantém as animações coerentes. O arquivo gerado é
## editável no Godot como qualquer outro — daqui para frente, é o editor que manda.
extends SceneTree

const ANATOMY := "res://anatomy/humanoid.tres"
const OUT := "res://anatomy/humanoid_animations.tres"

## Período da respiração: o mesmo `sin(t * 2.2)` que o desenho antigo usava.
const BREATH_PERIOD := TAU / 2.2
const BREATH_AMPLITUDE := 3.0


func _initialize() -> void:
	await process_frame
	var anatomy: Anatomy = load(ANATOMY)
	if anatomy == null:
		push_error("Anatomia não encontrada: %s" % ANATOMY)
		quit(1)
		return

	var hip_y := anatomy.bone("hip").rest_position.y
	var torso_y := anatomy.bone("torso").rest_position.y

	var library := AnimationLibrary.new()
	library.add_animation("idle", _idle(torso_y))
	library.add_animation("recoil", _recoil(hip_y))
	library.add_animation("crouch_fire", _crouch_fire(hip_y, torso_y))

	var err := ResourceSaver.save(library, OUT)
	if err != OK:
		push_error("Falha ao salvar %s (erro %d)" % [OUT, err])
		quit(1)
		return
	print("### %d animações salvas em %s" % [library.get_animation_list().size(), OUT])
	quit(0)


## Respiração: o tórax sobe e desce, e o que pende dele acompanha. É o que antes era
## `sin(_time * 2.2) * 3.0` somado à mão em cada coordenada do desenho.
func _idle(torso_y: float) -> Animation:
	var anim := Animation.new()
	anim.length = BREATH_PERIOD
	anim.loop_mode = Animation.LOOP_LINEAR
	_curve(anim, "hip/torso:position:y", [
		[0.0, torso_y],
		[BREATH_PERIOD * 0.25, torso_y + BREATH_AMPLITUDE],
		[BREATH_PERIOD * 0.5, torso_y],
		[BREATH_PERIOD * 0.75, torso_y - BREATH_AMPLITUDE],
		[BREATH_PERIOD, torso_y],
	])
	return anim


## Coice: o corpo inteiro afunda de leve e volta. É deslocamento vertical de propósito
## — inclinação seria espelhada na vista de costas e leria ao contrário.
func _recoil(hip_y: float) -> Animation:
	var anim := Animation.new()
	anim.length = 0.42
	_curve(anim, "hip:position:y", [
		[0.0, hip_y],
		[0.08, hip_y + 7.0],
		[0.42, hip_y],
	])
	return anim


## Agachar para disparar: o quadril desce, o tórax desce junto, segura, e volta. É a
## animação que uma arma pesada pede por `Part.body_animation`.
func _crouch_fire(hip_y: float, torso_y: float) -> Animation:
	var anim := Animation.new()
	anim.length = 0.8
	_curve(anim, "hip:position:y", [
		[0.0, hip_y],
		[0.15, hip_y + 22.0],
		[0.5, hip_y + 22.0],
		[0.8, hip_y],
	])
	_curve(anim, "hip/torso:position:y", [
		[0.0, torso_y],
		[0.15, torso_y + 6.0],
		[0.5, torso_y + 6.0],
		[0.8, torso_y],
	])
	return anim


## Uma trilha de valor com interpolação cúbica — o que dá a suavidade de seno com
## poucos quadros-chave.
func _curve(anim: Animation, path: String, keys: Array) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(path))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	anim.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for key in keys:
		anim.track_insert_key(track, float(key[0]), float(key[1]))
