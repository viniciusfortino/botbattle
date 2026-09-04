## Um ponto de encaixe. Vive num osso ou numa peça — é o que torna o modelo de montagem
## recursivo: a mesma classe descreve onde um braço entra no esqueleto e onde uma mira
## entra num canhão.
##
## Ver Docs/feature_montagem.md §4-5.
@tool
class_name SocketDef
extends Resource

## Identidade dentro do anfitrião: "main", "rail_1", "dorsal_2".
@export var key: String = ""
## O padrão mecânico deste socket: "MK-A1", "RAIL-1". A compatibilidade entre peça e
## anfitrião se resolve comparando isto com `Part.fits` — e só isso, nunca uma lista de
## exceções (Docs/feature_montagem.md §4).
@export var standard: String = ""
## Rótulo para o hangar: "Costas 1", "Acoplamento". Vazio nos sockets "main" — o hangar
## usa o `display_name` do osso ali, o mesmo texto que o osso já tem, sem duplicar.
## Faltava no desenho original do §5, mesmo motivo do `art_height` (Fase 5): só apareceu
## quando a Fase 6 do Docs/plan_montagem.md precisou de verdade.
@export var label: String = ""

@export_group("Pose")
## Posição de repouso da peça que entrar aqui, relativa ao anfitrião.
@export var rest_position: Vector2 = Vector2.ZERO
## Onde o pé da arte encosta, em coordenadas locais.
@export var art_offset: Vector2 = Vector2.ZERO
## Altura da arte em unidades de jogo; a largura sai da proporção da imagem. Faltava no
## desenho original do §5 — a Fase 5 do Docs/plan_montagem.md sentiu a falta ao desenhar
## de verdade e fechou aqui, do mesmo jeito que `BoneDef.art_height` já funciona.
@export var art_height: float = 100.0
@export var z_index: int = 0
