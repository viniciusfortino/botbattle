## A montagem do jogador (autoload `PlayerLoadout`).
##
## Guarda o robô entre o hangar e a batalha, e entre execuções do jogo. O save grava
## **ids** de peça, não recursos serializados: assim mexer nos .tres do catálogo nunca
## corrompe o arquivo salvo — uma peça que sumiu vira encaixe vazio, com aviso.
##
## O hangar grava sozinho, sem perguntar, sempre que se aperta BATALHAR (`hangar.gd`).
## Isso é o certo para quem está jogando — é errado para quem só está verificando uma
## fase ou testando uma troca de chassi, e foi assim que uma checagem manual da Fase 9
## sobrescreveu o save de verdade do jogador com uma montagem de teste (ver a Tarefa 4 do
## plan_desvios.md). Com BOTBATTLE_SAVE_PATH definido o save vai para outro arquivo, o
## que dá a qualquer verificação que precise passar pelo hangar um lugar descartável para
## escrever:
##
##   BOTBATTLE_SAVE_PATH="user://_test_loadout.json" godot --headless ...
extends Node

const DEFAULT_LOADOUT := "res://content/units/r7.tres"

## Não é `const` de propósito: precisa ler a variável de ambiente uma vez, na primeira
## consulta.
static var _save_path := ""

var current: Loadout


func _ready() -> void:
	current = load_saved()


static func save_path() -> String:
	if _save_path.is_empty():
		var override := OS.get_environment("BOTBATTLE_SAVE_PATH")
		_save_path = override if not override.is_empty() else "user://loadout.json"
	return _save_path


## Carrega o save, ou devolve uma cópia da montagem padrão.
func load_saved() -> Loadout:
	var base: Loadout = load(DEFAULT_LOADOUT).duplicate(true)
	var path := save_path()
	if not FileAccess.file_exists(path):
		return base

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Não foi possível ler %s" % path)
		return base
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save de montagem inválido — usando o padrão.")
		return base

	return _from_dict(parsed as Dictionary, base)


func save(loadout: Loadout) -> void:
	current = loadout
	var path := save_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível gravar %s" % path)
		return
	file.store_string(JSON.stringify(_to_dict(loadout), "\t"))
	file.close()


func _to_dict(loadout: Loadout) -> Dictionary:
	var mounted := {}
	for entry in loadout.mounted_parts():
		mounted[entry["path"]] = (entry["part"] as Part).id
	return {
		"pilot_name": loadout.pilot_name,
		"kit": loadout.kit.id if loadout.kit != null else "",
		"mounted": mounted,
	}


## Um save antigo pode ter "body_color"/"accent_color" — cor não é mais escolha do
## jogador (§7), então essas chaves são ignoradas, não lidas.
func _from_dict(data: Dictionary, base: Loadout) -> Loadout:
	base.pilot_name = String(data.get("pilot_name", base.pilot_name))

	# Um save que aponta para um kit que sumiu do catálogo cai no de fábrica, do mesmo
	# jeito que uma peça removida vira socket vazio.
	var kit_id := String(data.get("kit", ""))
	if not kit_id.is_empty():
		var kit := KitCatalog.get_kit(kit_id)
		if kit == null:
			push_warning("Kit '%s' não existe mais — usando o de fábrica." % kit_id)
			kit = KitCatalog.default_kit()
		if kit != null:
			base.kit = kit

	# Um caminho de socket cujo pai não carregou (peça que sumiu do catálogo) fica
	# órfão no dicionário, mas nunca é alcançado pela travessia de `available_sockets()`
	# — o mesmo efeito de "encaixe liberado" sem precisar de um passo de revalidação à
	# parte.
	var mounted: Dictionary = data.get("mounted", {})
	var new_mounted: Dictionary[String, Part] = {}
	for path in mounted:
		var id := String(mounted[path])
		if id.is_empty():
			continue
		var part := PartCatalog.get_part(id)
		if part == null:
			push_warning("Peça '%s' não existe mais — socket %s ficou vazio." % [id, path])
			continue
		new_mounted[String(path)] = part
	base.mounted = new_mounted
	return base
