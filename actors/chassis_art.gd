## Resolve os sprites pintados de um chassi, com cache e uma checagem de sanidade.
##
## Convenção: res://assets/sprites/chassis/<chassis_id>/<parte>_front[_<estado>].aseprite
##
## Um arquivo sem transparência de verdade — ainda com o fundo do Aseprite gravado nos
## pixels, seja o xadrez ou uma cor sólida — é tratado como inválido e quem pediu a
## textura recebe null, caindo para o desenho procedural. É o que faz a arte "ligar"
## sozinha peça por peça: corrigiu no Aseprite, aparece no jogo sem mexer em código.
class_name ChassisArt
extends RefCounted

const BASE_PATH := "res://assets/sprites/chassis"

## Acima disso a peça aparece intacta. Abaixo, "damaged"; mais abaixo, "critical" —
## os mesmos limiares do painel de debug (ui/hitbox_debug_panel.gd), para a arte e o
## HUD concordarem sobre o que é "muito danificado".
const DAMAGED_AT := 0.6
const CRITICAL_AT := 0.3

## caminho -> Texture2D recortada ao conteúdo, ou `false` quando ausente/inválida.
static var _cache: Dictionary = {}


## A textura para esta parte no estado correspondente à vida restante. Cai em cascata:
## estado específico (ex. "_critical") -> estado base -> null (desenho procedural).
static func part_texture(chassis_id: String, part: String, ratio: float = 1.0) -> Texture2D:
	if chassis_id.is_empty():
		return null

	var suffix := ""
	if ratio <= CRITICAL_AT:
		suffix = "_critical"
	elif ratio <= DAMAGED_AT:
		suffix = "_damaged"

	if not suffix.is_empty():
		var staged := _load("%s/%s_front%s" % [chassis_id, part, suffix])
		if staged != null:
			return staged
	return _load("%s/%s_front" % [chassis_id, part])


## Descarta o cache — chame depois de editar um .aseprite para recarregar sem reiniciar.
static func clear_cache() -> void:
	_cache.clear()


static func _load(relative: String) -> Texture2D:
	if _cache.has(relative):
		var cached = _cache[relative]
		return cached if cached is Texture2D else null

	var path := "%s/%s.aseprite" % [BASE_PATH, relative]
	if not ResourceLoader.exists(path):
		_cache[relative] = false
		return null

	var tex: Texture2D = load(path)
	var img := tex.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)

	if not _has_real_transparency(img):
		push_warning(
			"Sprite sem transparência real (fundo ainda opaco — xadrez ou cor sólida " +
			"gravados nos pixels): %s. Usando desenho procedural no lugar." % path)
		_cache[relative] = false
		return null

	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		_cache[relative] = false
		return null

	var cropped := ImageTexture.create_from_image(img.get_region(used))
	_cache[relative] = cropped
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
