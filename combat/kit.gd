## Um lançamento: o esqueleto e as peças que vêm nele de fábrica. Não tem atributo
## próprio — os números saem do que está montado (Docs/feature_montagem.md §6).
##
## Substitui `Chassis`: onde ele guardava `base_stats` e `bone_resistance` como bloco
## monolítico, o kit só aponta o esqueleto e o que vem instalado nele de fábrica.
##
## Ver Docs/feature_montagem.md §5.
class_name Kit
extends Resource

@export var id: String = "mk1"
## Nome para a UI do hangar: "Exoesqueleto MK-I". Equivalente ao `Chassis.display_name`
## de antes — mesma lacuna do `full_art_id`, só apareceu quando a Fase 7 precisou listar
## kits na aba de troca.
@export var display_name: String = "Exoesqueleto"
@export var skeleton: Skeleton
## Socket → peça, o mesmo formato de `Loadout.mounted`: o kit é a montagem de fábrica.
@export var factory_parts: Dictionary[String, Part] = {}

## `art_id` do retrato fullbody (res://assets/source/parts/<full_art_id>/) — vazio
## quando este lançamento não tem visão fullbody. Equivalente ao `Chassis.full_art_id`
## de antes.
@export var full_art_id: String = ""


## O ponto de partida de uma montagem nova: uma cópia das peças de fábrica, por caminho
## de socket. `Loadout.mounted` parte daqui e depois vive por conta própria — remontar
## não volta a consultar o kit (Docs/plan_montagem.md, Fase 3).
func default_mounted() -> Dictionary[String, Part]:
	var out: Dictionary[String, Part] = {}
	for socket_path in factory_parts:
		out[socket_path] = factory_parts[socket_path]
	return out
