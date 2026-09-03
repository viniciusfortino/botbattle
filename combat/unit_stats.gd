## Ficha de um combatente. Duplique um .tres em res://units/ para criar novas unidades.
##
## A vida não é um número único: cada hitbox tem a sua, e o total do combatente é a
## soma das seis (cabeça, tórax, dois braços e duas pernas).
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
