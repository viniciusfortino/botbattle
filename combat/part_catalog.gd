## Índice das peças disponíveis.
##
## A lista é explícita de propósito: ela sobrevive à exportação (varrer diretórios não
## é confiável dentro do .pck) e a ordem aqui é a ordem em que o hangar mostra as peças.
## Para adicionar uma peça: crie o .tres em res://parts/ e acrescente o id abaixo.
class_name PartCatalog
extends RefCounted

const IDS := [
	"laser_cannon", "sensor",
	"generator", "dorsal_armor",
	"power_cell",
	"short_sword", "plasma_cannon",
	"blade_forearm",
	"heavy_arm",
	"agile_leg", "heavy_leg",
]

static var _cache: Dictionary = {}


static func all() -> Array[Part]:
	_ensure_loaded()
	var parts: Array[Part] = []
	for id in IDS:
		if _cache.has(id):
			parts.append(_cache[id])
	return parts


static func get_part(id: String) -> Part:
	_ensure_loaded()
	return _cache.get(id)


## As peças que cabem num encaixe deste tipo.
static func for_slot(slot: Part.Slot) -> Array[Part]:
	return all().filter(func(part: Part) -> bool: return part.slot == slot)


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	for id in IDS:
		var path := "res://parts/%s.tres" % id
		if ResourceLoader.exists(path):
			_cache[id] = load(path)
		else:
			push_warning("Peça não encontrada no catálogo: %s" % path)
