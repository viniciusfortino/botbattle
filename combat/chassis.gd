## O exoesqueleto: a base que todo robô tem antes de qualquer peça.
##
## Ele define os atributos de fábrica, a capacidade de carga e a vida das partes
## estruturais que ele mesmo fornece (as que não foram substituídas por peças).
class_name Chassis
extends Resource

@export var id: String = "mk1"
@export var display_name: String = "Exoesqueleto MK-I"

## A forma deste robô: que ossos e encaixes ele tem. res://anatomy/humanoid.tres se vazio.
@export var anatomy: Anatomy

## O vocabulário de atributos que este chassi usa. res://stats/default.tres se vazio.
@export var schema: StatSchema
## Valores base: {"strength": 12, "agility": 10, "capacity": 120}. O que não estiver
## aqui usa o default_base do StatDef correspondente.
@export var base_stats: Dictionary[String, int] = {}

@export_group("Restrições")
## Lista de keys de slots (ex: "back_2", "chest_2") que este chassis não possui.
@export var disabled_slots: Array[String] = []
## Lista de tags de peças (ex: "HEAVY") que este chassis não consegue equipar.
@export var restricted_tags: Array[String] = []

@export_group("Resistência de fábrica")
## Sobrescreve a resistência de fábrica de ossos específicos: {"torso": 34}. O que não
## estiver aqui usa o BoneDef.resistance correspondente.
@export var bone_resistance: Dictionary[String, int] = {}
