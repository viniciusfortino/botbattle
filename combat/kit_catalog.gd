## Índice dos kits de fábrica disponíveis, no modelo novo (Docs/feature_montagem.md).
##
## Mesmo molde do ChassisCatalog, pelo mesmo motivo: a lista é explícita porque varrer
## diretórios não é confiável dentro do .pck exportado.
## Para adicionar um kit: crie o .tres em res://content/kits/ e acrescente o id abaixo.
class_name KitCatalog
extends RefCounted

const IDS := ["mk1", "mk2_goliath", "mk3_strider"]

## O de fábrica: para onde cai uma montagem sem kit válido.
const DEFAULT_ID := "mk1"

static var _cache: Dictionary = {}


## Os kits que o hangar oferece, na ordem de `IDS`. Um id que não carregou fica de fora
## da lista em vez de virar um buraco no meio dela.
static func all() -> Array[Kit]:
	_ensure_loaded()
	var list: Array[Kit] = []
	for id in IDS:
		if _cache.has(id):
			list.append(_cache[id])
	return list


static func get_kit(id: String) -> Kit:
	_ensure_loaded()
	return _cache.get(id)


static func default_kit() -> Kit:
	return get_kit(DEFAULT_ID)


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	for id in IDS:
		var path := "res://content/kits/%s.tres" % id
		if ResourceLoader.exists(path):
			_cache[id] = load(path)
		else:
			push_warning("Kit não encontrado no catálogo: %s" % path)
