## Uma forma de ocupar um encaixe. É o que antes vivia em `Loadout.ArmMode`, só para os
## braços — generalizado, e derivado da peça em vez de guardado à parte.
@tool
class_name MountDef
extends Resource

## O tipo de peça que entra por este modo.
@export var accepts: Part.Slot = Part.Slot.BACK
## Como o hangar chama este modo: "braço de fábrica", "antebraço trocado".
@export var label: String = ""
## A peça vira a própria hitbox do osso hospedeiro, em vez de pendurar nele.
@export var replaces_host: bool = false
