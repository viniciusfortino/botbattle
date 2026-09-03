## Resolve a arte gerada no PixelLab: osso de personagem e peça de equipamento.
##
## Ao contrário do ArtLibrary (pipeline Aseprite), aqui a textura é devolvida INTEIRA,
## sem recorte: cada peça tem bbox diferente e cada direção tem bbox diferente da mesma
## peça, então recortar faz o robô mudar de tamanho a cada giro. Ver §11.1 do plano.
class_name CharacterArt
extends RefCounted

const CHARACTERS := "res://assets/source/characters"
const PARTS := "res://assets/source/parts"

static var _tex_cache: Dictionary = {}
static var _meta_cache: Dictionary = {}


## A arte de um osso do chassi, no estado de dano dado.
static func bone_texture(char_id: String, bone: String, direction: String,
		cond: BodyPart.Condition = BodyPart.Condition.INTACT,
		pose: String = "Idle") -> Texture2D:
	return _staged("%s/%s/%s" % [CHARACTERS, char_id, bone], pose, direction, cond)


## A arte de uma peça montada. Peça não tem chassi: a raiz é outra.
static func part_texture(part_id: String, direction: String,
		cond: BodyPart.Condition = BodyPart.Condition.INTACT,
		pose: String = "Idle") -> Texture2D:
	return _staged("%s/%s" % [PARTS, part_id], pose, direction, cond)


## As poses disponíveis, lidas do metadata.json — nunca hardcode nome de pasta.
static func poses(base_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for state in _metadata(base_path).get("states", []):
		var folder := String(state.get("folder", ""))
		if not folder.is_empty():
			out.append(folder)
	return out


static func clear_cache() -> void:
	_tex_cache.clear()
	_meta_cache.clear()


## Cascata de estado, igual à do ArtLibrary._staged(): pose específica -> pose base ->
## null (e aí o PartNode cai no desenho procedural). O sufixo é na POSE, não no arquivo:
## "Idle_critical/rotations/south.png". Enquanto a arte de dano não existir para um osso,
## toda condição resolve para a íntegra — que é o comportamento desejado.
static func _staged(base_path: String, pose: String, direction: String,
		cond: BodyPart.Condition) -> Texture2D:
	var suffix := ""
	match cond:
		BodyPart.Condition.CRITICAL, BodyPart.Condition.DESTROYED:
			suffix = "_critical"
		BodyPart.Condition.DAMAGED:
			suffix = "_damaged"

	if not suffix.is_empty():
		var staged := _load(base_path, pose + suffix, direction)
		if staged != null:
			return staged
	return _load(base_path, pose, direction)


static func _load(base_path: String, pose: String, direction: String) -> Texture2D:
	var path := "%s/%s/rotations/%s.png" % [base_path, pose, direction]
	if _tex_cache.has(path):
		var cached = _tex_cache[path]
		return cached if cached is Texture2D else null
	if not ResourceLoader.exists(path):
		_tex_cache[path] = false
		return null
	var tex: Texture2D = load(path)
	_tex_cache[path] = tex
	return tex


static func _metadata(base_path: String) -> Dictionary:
	if _meta_cache.has(base_path):
		return _meta_cache[base_path]
	var out := {}
	var path := "%s/metadata.json" % base_path
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				out = parsed
	_meta_cache[base_path] = out
	return out
