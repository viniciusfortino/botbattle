## O exoesqueleto: a base que todo robô tem antes de qualquer peça.
##
## Ele define os atributos de fábrica, a capacidade de carga e a vida das partes
## estruturais que ele mesmo fornece (as que não foram substituídas por peças).
class_name Chassis
extends Resource

@export var id: String = "mk1"
@export var display_name: String = "Exoesqueleto MK-I"

@export_group("Atributos base")
@export var strength: int = 12
@export var agility: int = 10
@export var defense: int = 4
@export var energy: int = 18
## Carga máxima. Acima da metade dela a agilidade começa a cair.
@export var capacity: int = 120

@export_group("Restrições")
## Lista de keys de slots (ex: "back_2", "chest_2") que este chassis não possui.
@export var disabled_slots: Array[String] = []
## Lista de tags de peças (ex: "HEAVY") que este chassis não consegue equipar.
@export var restricted_tags: Array[String] = []

@export_group("Resistência de fábrica")
@export var head_resistance: int = 14
@export var torso_resistance: int = 34
@export var arm_resistance: int = 20
@export var leg_resistance: int = 18
