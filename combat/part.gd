## Uma peça montável no exoesqueleto.
##
## Peça é ao mesmo tempo três coisas: um pacote de atributos que soma no robô, uma
## hitbox própria (a `resistance` é a vida dela) e, às vezes, a origem de uma ação de
## combate. Perder a peça em batalha tira as três coisas de uma vez.
class_name Part
extends Resource

@export var id: String = ""
@export var display_name: String = "Peça"
## Como o log se refere a ela: "o turbo esquerdo".
@export var narrative_name: String = "a peça"
## Tags que classificam esta peça (ex: "HEAVY", "AGILE", "ENERGY", "MELEE"). Ainda sem
## consumidor — nenhum conteúdo de hoje usa (Docs/plan_montagem.md, Fase 7).
@export var tags: Array[String] = []

@export_group("Montagem")
## Os padrões de socket em que esta peça entra ("MK-A1", "RAIL-1"). É a peça que decide
## onde encaixa, nunca o anfitrião (Docs/feature_montagem.md §4).
@export var fits: Array[String] = []
## Onde esta peça deixa outras peças entrarem (um acoplamento). Vazio = peça folha.
@export var sockets: Array[SocketDef] = []

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
## Id da pasta em res://assets/source/parts/<art_id>/ — lido por `CharacterArt.texture()`.
## Vazio = desenho procedural.
@export var art_id: String = ""
