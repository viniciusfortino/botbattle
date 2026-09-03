## Um encaixe do exoesqueleto: onde uma peça entra, e o que ela vira quando entra.
@tool
class_name SlotDef
extends Resource

## Identidade do encaixe: "head_top", "back_1", "arm_left"…
@export var key: String = ""
## Rótulo para o hangar: "Topo da cabeça".
@export var label: String = ""
## O osso que sustenta a peça — ou que ela substitui, conforme o modo.
@export var host_bone: String = ""
## Os modos de montagem deste encaixe, na ordem em que o hangar os lista.
@export var mounts: Array[MountDef] = []
## Ordem em que a peça montada recebe o excedente de um golpe.
@export var attachment_absorb_priority: int = 6

@export_group("Pose")
@export var rest_position: Vector2 = Vector2.ZERO
@export var rest_rotation: float = 0.0
## Onde o pé da arte encosta, em coordenadas locais. O pivô da arte é o centro
## inferior dela (ver feature_parts.md §8); isto diz onde esse pé fica.
@export var art_offset: Vector2 = Vector2.ZERO
@export var art_height: float = 80.0
@export var z_index: int = 0
@export var z_index_back: int = 0
