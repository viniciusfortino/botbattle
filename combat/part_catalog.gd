## Índice das peças disponíveis.
##
## A lista é explícita de propósito: ela sobrevive à exportação (varrer diretórios não
## é confiável dentro do .pck) e a ordem aqui é a ordem em que o hangar mostra as peças.
## Para adicionar uma peça: crie o .tres em res://content/catalog/parts/ e acrescente o id abaixo.
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
	# Peças de fábrica dos kits mk1/mk2/mk3 (Docs/plan_montagem.md, Fases 2 e 7) — entram
	# aqui para que `for_standard()` as devolva como opção de "voltar ao de fábrica" no
	# hangar.
	"mk1_head", "mk1_torso", "mk1_hip",
	"mk1_arm_left", "mk1_arm_right",
	"mk1_leg_left", "mk1_leg_right",
	"mk2_goliath_head", "mk2_goliath_torso",
	"mk2_goliath_arm_left", "mk2_goliath_arm_right",
	"mk2_goliath_leg_left", "mk2_goliath_leg_right",
	"mk3_strider_head", "mk3_strider_torso",
	"mk3_strider_arm_left", "mk3_strider_arm_right",
	"mk3_strider_leg_left", "mk3_strider_leg_right",
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


## As peças que entram num socket deste padrão ("MK-A1", "RAIL-1") — quem decide é a
## peça (`fits`), nunca o anfitrião (Docs/feature_montagem.md §4).
static func for_standard(standard: String) -> Array[Part]:
	return all().filter(func(part: Part) -> bool: return part.fits.has(standard))


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	for id in IDS:
		var path := "res://content/catalog/parts/%s.tres" % id
		if ResourceLoader.exists(path):
			_cache[id] = load(path)
		else:
			push_warning("Peça não encontrada no catálogo: %s" % path)
