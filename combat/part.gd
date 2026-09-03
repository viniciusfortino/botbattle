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
## Quanto a peça soma em cada atributo: {"strength": 6}.
@export var modifiers: Dictionary[String, int] = {}
## Quanto a peça multiplica, depois de todas as somas: {"agility": 1.2}.
@export var scalers: Dictionary[String, float] = {}

## A vida da hitbox desta peça.
@export var resistance: int = 6
## Custo de carga no exoesqueleto.
@export var weight: int = 8

@export_group("Combate")
## Ids de ações em Actions.LIST que esta peça concede. Uma peça pode conceder mais de
## uma (um braço que corta e atira); vazio para quem não concede nenhuma.
@export var grants_actions: Array[String] = []
## Sobrescreve a animação de corpo da ação, quando esta peça é a origem (Fase 8).
@export var body_animation: String = ""
## Peso relativo no sorteio de acerto (peças pequenas são alvos difíceis).
@export var hit_weight: float = 0.8
## Quanto esta peça amplifica o dano que recebe.
@export var damage_multiplier: float = 1.0

@export_group("Visual")
## Prefixo do arquivo de arte: res://assets/source/sprites/parts/<art_id>_front[_<estado>].
## Vazio = desenho procedural.
@export var art_id: String = ""


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
