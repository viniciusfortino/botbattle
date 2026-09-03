## Uma peça montável no exoesqueleto.
##
## Peça é ao mesmo tempo três coisas: um pacote de atributos que soma no robô, uma
## hitbox própria (a `resistance` é a vida dela) e, às vezes, a origem de uma ação de
## combate. Perder a peça em batalha tira as três coisas de uma vez.
class_name Part
extends Resource

enum Slot {
	HEAD_TOP,   ## topo da cabeça — 1 por robô
	BACK,       ## costas — 2 por robô
	CHEST,      ## peito — 2 por robô
	ARM_MOUNT,  ## acoplado ao antebraço do exoesqueleto
	FOREARM,    ## substitui o antebraço
	ARM_FULL,   ## substitui o braço inteiro
	LEG_FULL,   ## substitui a perna inteira
}

@export var id: String = ""
@export var display_name: String = "Peça"
## Como o log se refere a ela: "o turbo esquerdo".
@export var narrative_name: String = "a peça"
@export var slot: Slot = Slot.BACK
## Tags que classificam esta peça (ex: "HEAVY", "AGILE", "ENERGY", "MELEE").
@export var tags: Array[String] = []

@export_group("Atributos")
## Soma no dano causado.
@export var strength: int = 0
## Soma na ordem dos turnos (antes da penalidade de carga).
@export var agility: int = 0
## A vida da hitbox desta peça.
@export var resistance: int = 6
## Reduz o dano recebido pelo robô inteiro.
@export var defense: int = 0
## Custo de carga no exoesqueleto.
@export var weight: int = 8
## Soma na energia máxima.
@export var energy: int = 0

@export_group("Combate")
## Id de uma ação em Actions.LIST que esta peça concede, ou vazio.
@export var grants_action: String = ""
## Peso relativo no sorteio de acerto (peças pequenas são alvos difíceis).
@export var hit_weight: float = 0.8
## Quanto esta peça amplifica o dano que recebe.
@export var damage_multiplier: float = 1.0


func is_arm_piece() -> bool:
	return slot == Slot.ARM_MOUNT or slot == Slot.FOREARM or slot == Slot.ARM_FULL


## Rótulo curto do encaixe, para a UI do hangar.
static func slot_label(value: Slot) -> String:
	match value:
		Slot.HEAD_TOP:
			return "Topo da cabeça"
		Slot.BACK:
			return "Costas"
		Slot.CHEST:
			return "Peito"
		Slot.ARM_MOUNT:
			return "Acoplamento"
		Slot.FOREARM:
			return "Antebraço"
		Slot.ARM_FULL:
			return "Braço completo"
		_:
			return "Pernas"
