## Um atributo do jogo. O chassi dá o valor base, as peças somam e multiplicam.
##
## Existir aqui, e não como campo fixo em Chassis/Part, é o que faz um atributo novo
## virar um recurso em vez de um refactor em quatro arquivos.
class_name StatDef
extends Resource

## "strength" — a chave usada em Chassis.base_stats e Part.modifiers/scalers.
@export var key: String = ""
## Nome para a UI: "Força".
@export var display_name: String = ""
## Rótulo curto do hangar: "FOR".
@export var abbreviation: String = ""
@export var description: String = ""
## Valor quando o chassi não declara nada em base_stats.
@export var default_base: int = 0
## Piso aplicado depois de somar e multiplicar.
@export var minimum: int = 0
## Campo de UnitStats que este atributo alimenta ("attack", "speed"…). Vazio = o
## atributo soma e aparece no hangar do mesmo jeito, mas quem precisa dele lê por
## Loadout.stat(key) em vez de um campo nomeado — é o caso de "capacity" hoje.
@export var maps_to: String = ""
