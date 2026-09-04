## Ficha de um combatente. Duplique um .tres em res://content/units/ para criar novas unidades.
##
## A vida não é um número único: cada osso e cada peça montada tem a sua própria hitbox
## — a vida do combatente é a soma de todas elas (`Body.max_total_hp()`), não um valor
## fixo por robô (Docs/feature_montagem.md §7).
class_name UnitStats
extends Resource

@export var display_name: String = "Unidade"

@export_group("Atributos")
## Energia usada pelas habilidades.
@export var max_mp: int = 30
## Base do dano causado.
@export var attack: int = 15
## Reduz o dano recebido.
@export var defense: int = 8
## Define a ordem dos turnos (maior age primeiro).
@export var speed: int = 10

@export_group("Visual")
@export var body_color: Color = Color("4f9dde")
@export var accent_color: Color = Color("8ef0ff")
