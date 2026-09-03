## Resolve os sprites pintados do robô — os do chassi e os das peças montadas — com
## cache e uma checagem de sanidade.
##
## Convenções:
##   res://assets/sprites/chassis/<chassis_id>/<bone>_front[_<estado>].aseprite
##   res://assets/sprites/parts/<art_id>_front[_<estado>].aseprite
##
## Um arquivo sem transparência de verdade — ainda com o fundo do Aseprite gravado nos
## pixels, seja o xadrez ou uma cor sólida — é tratado como inválido e quem pediu a
## textura recebe null, caindo para o desenho procedural. É o que faz a arte "ligar"
## sozinha peça por peça: corrigiu no Aseprite, aparece no jogo sem mexer em código.
class_name ArtLibrary
extends RefCounted

const CHASSIS_PATH := "res://assets/sprites/chassis"
const PARTS_PATH := "res://assets/sprites/parts"

## caminho -> Texture2D recortada ao conteúdo, ou `false` quando ausente/inválida.
static var _cache: Dictionary = {}


## A textura de um osso do chassi (torso, cabeça…) no estado de dano dado.
static func bone_texture(chassis_id: String, bone: String, cond: BodyPart.Condition = BodyPart.Condition.INTACT) -> Texture2D:
	if chassis_id.is_empty():
		return null
	return _staged("%s/%s" % [CHASSIS_PATH, chassis_id], bone, cond)


## A textura de uma peça montada, pelo `art_id` dela, no estado de dano dado.
static func part_texture(art_id: String, cond: BodyPart.Condition = BodyPart.Condition.INTACT) -> Texture2D:
	if art_id.is_empty():
		return null
	return _staged(PARTS_PATH, art_id, cond)


## Descarta o cache — chame depois de editar um .aseprite para recarregar sem reiniciar.
static func clear_cache() -> void:
	_cache.clear()


## A textura para o nome dado no estado de dano dado. Cai em cascata: estado específico
## (ex. "_critical") -> estado base -> null (desenho procedural). Os limiares que
## decidem o estado moram em BodyPart, a única definição no projeto.
static func _staged(base_path: String, name: String, cond: BodyPart.Condition) -> Texture2D:
	var suffix := ""
	match cond:
		BodyPart.Condition.CRITICAL, BodyPart.Condition.DESTROYED:
			suffix = "_critical"
		BodyPart.Condition.DAMAGED:
			suffix = "_damaged"

	if not suffix.is_empty():
		var staged := _load("%s/%s_front%s" % [base_path, name, suffix])
		if staged != null:
			return staged
	return _load("%s/%s_front" % [base_path, name])


static func _load(path_without_ext: String) -> Texture2D:
	if _cache.has(path_without_ext):
		var cached = _cache[path_without_ext]
		return cached if cached is Texture2D else null

	var path := "%s.aseprite" % path_without_ext
	if not ResourceLoader.exists(path):
		_cache[path_without_ext] = false
		return null

	var tex: Texture2D = load(path)
	var img := tex.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)

	if not _has_real_transparency(img):
		push_warning(
			"Sprite sem transparência real (fundo ainda opaco — xadrez ou cor sólida " +
			"gravados nos pixels): %s. Usando desenho procedural no lugar." % path)
		_cache[path_without_ext] = false
		return null

	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		_cache[path_without_ext] = false
		return null

	var cropped := ImageTexture.create_from_image(img.get_region(used))
	_cache[path_without_ext] = cropped
	return cropped


## Se nenhum pixel amostrado for transparente, quase certo que o fundo foi exportado
## opaco (xadrez do Aseprite pintado, ou uma cor sólida) em vez de alpha 0.
static func _has_real_transparency(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var step := maxi(1, mini(w, h) / 40)
	for y in range(0, h, step):
		for x in range(0, w, step):
			if img.get_pixel(x, y).a < 0.05:
				return true
	return false
