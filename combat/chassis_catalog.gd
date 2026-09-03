## Índice dos exoesqueletos disponíveis.
##
## A lista é explícita de propósito: ela sobrevive à exportação (varrer diretórios não
## é confiável dentro do .pck) e a ordem aqui é a ordem em que o hangar os mostra.
## Para adicionar um exoesqueleto: crie o .tres em res://chassis/ e acrescente o id
## abaixo. É o mesmo molde do PartCatalog, pelo mesmo motivo.
class_name ChassisCatalog
extends RefCounted

const IDS := ["mk1", "mk2_goliath", "mk3_strider"]

## O de fábrica: para onde cai um save que aponta para um exoesqueleto que sumiu.
const DEFAULT_ID := "mk1"

static var _cache: Dictionary = {}


## Os exoesqueletos que o hangar oferece, na ordem de `IDS`. Um id que não carregou fica
## de fora da lista em vez de virar um buraco no meio dela.
static func all() -> Array[Chassis]:
	_ensure_loaded()
	var list: Array[Chassis] = []
	for id in IDS:
		if _cache.has(id):
			list.append(_cache[id])
	return list


## O exoesqueleto de um id, ou null quando ele não existe mais. É por esse null que um
## save apontando para um chassi removido é percebido, em vez de estourar ao carregar.
static func get_chassis(id: String) -> Chassis:
	_ensure_loaded()
	return _cache.get(id)


## Para onde cai quem não tem escolha válida: montagem nova, ou save apontando para um
## exoesqueleto que sumiu do catálogo.
static func default_chassis() -> Chassis:
	return get_chassis(DEFAULT_ID)


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	for id in IDS:
		var path := "res://chassis/%s.tres" % id
		if ResourceLoader.exists(path):
			_cache[id] = load(path)
		else:
			push_warning("Exoesqueleto não encontrado no catálogo: %s" % path)
