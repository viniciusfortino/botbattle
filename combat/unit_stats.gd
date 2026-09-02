## Ficha de um combatente. Duplique um .tres em res://units/ para criar novas unidades.
##
## A vida não é um número único: cada hitbox tem a sua, e o total do combatente é a
## soma das seis (cabeça, tórax, dois braços e duas pernas).
class_name UnitStats
extends Resource

@export var display_name: String = "Unidade"

@export_group("Vida por hitbox")
@export var head_hp: int = 16
@export var torso_hp: int = 44
## Vale para cada braço.
@export var arm_hp: int = 14
## Vale para cada perna.
@export var leg_hp: int = 16

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


func hp_for(kind: BodyPart.Kind) -> int:
	match kind:
		BodyPart.Kind.HEAD:
			return head_hp
		BodyPart.Kind.TORSO:
			return torso_hp
		BodyPart.Kind.ARM_LEFT, BodyPart.Kind.ARM_RIGHT:
			return arm_hp
		_:
			return leg_hp


## Soma das hitboxes — a vida total da unidade.
func total_hp() -> int:
	return head_hp + torso_hp + arm_hp * 2 + leg_hp * 2
