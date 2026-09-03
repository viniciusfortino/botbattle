## Um pedaço estrutural do corpo: existe em todo robô que use esta anatomia, mesmo
## sem nenhuma peça montada.
@tool
class_name BoneDef
extends Resource

## Identidade dentro do corpo: "hip", "torso", "arm_left"…
@export var key: String = ""
@export var kind: BodyPart.Kind = BodyPart.Kind.TORSO
## Nome curto, para a UI ("Braço dir.").
@export var display_name: String = ""
## Nome com artigo, para o log ("o braço direito").
@export var narrative_name: String = ""
## O osso que sustenta este: pai de transformação **e** de cascata de dano.
## Vazio = raiz.
@export var parent: String = ""

@export_group("Hitbox")
## Falso = osso só de transformação, sem vida e sem aparecer no painel de hitboxes.
@export var hitbox: bool = true
## Vida de fábrica. O chassi pode sobrescrever por `bone_resistance`.
@export var resistance: int = 20
## Área aparente — peso no sorteio de acerto.
@export var hit_weight: float = 1.0
## Quanto este osso amplifica o dano que recebe.
@export var damage_multiplier: float = 1.0
## Ordem em que recebe o excedente de um golpe em outra hitbox (menor = antes).
@export var absorb_priority: int = 9

@export_group("Pose")
## Posição de repouso **relativa ao osso pai**.
@export var rest_position: Vector2 = Vector2.ZERO
@export var rest_rotation: float = 0.0
## O ponto em torno do qual a arte gira (o ombro, o quadril).
@export var pivot: Vector2 = Vector2.ZERO
## Altura de desenho em unidades de jogo; a largura sai da proporção da imagem.
## Onde o pé da arte encosta, em coordenadas locais. O pivô da arte é o centro
## inferior dela (ver feature_parts.md §8); isto diz onde esse pé fica.
@export var art_offset: Vector2 = Vector2.ZERO
@export var art_height: float = 100.0
@export var z_index: int = 0
## Profundidade na vista de costas, quando ela difere. Vale `z_index` se não definida.
@export var z_index_back: int = 0
