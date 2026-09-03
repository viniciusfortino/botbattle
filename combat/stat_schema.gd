## O vocabulário de atributos do jogo — declarado uma vez, em res://stats/default.tres.
##
## Chassis, Part, Loadout.resolve() e os rótulos do hangar leem daqui em vez de cada um
## repetir a mesma lista de nomes.
class_name StatSchema
extends Resource

## Na ordem em que o hangar os mostra.
@export var stats: Array[StatDef] = []


## A definição de um atributo. Quem resolve os números precisa do rótulo, da abreviação e
## do piso que moram aqui — o `.tres` de uma peça guarda só a chave e o valor.
func stat(key: String) -> StatDef:
	for def in stats:
		if def.key == key:
			return def
	return null


## Os atributos na ordem em que o hangar os mostra. É sobre esta lista que
## `Loadout.resolve()` e os rótulos do hangar iteram, em vez de repetir os nomes.
func keys() -> Array[String]:
	var result: Array[String] = []
	for def in stats:
		result.append(def.key)
	return result
