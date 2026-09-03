## Um pedaço do robô em cena: um osso do esqueleto ou uma peça montada num encaixe.
##
## Ele não sabe o que representa. Recebe a arte quando ela existe e, quando não existe,
## chama o desenho procedural que o RobotSprite entrega pronto. É isso que permite
## migrar a arte peça por peça: no dia em que o .aseprite aparecer, este nó troca
## sozinho, sem que ninguém mexa no desenho dos vizinhos.
##
## A posição, a profundidade e a âncora da arte vêm da anatomia — aqui só se desenha.
@tool
class_name PartNode
extends Node2D

## A chave da anatomia que este nó representa: "torso", "back_1"…
var key := ""
## Onde o pé da arte encosta, em coordenadas locais.
var art_offset := Vector2.ZERO
## Altura da arte em unidades de jogo; a largura sai da proporção da imagem.
var art_height := 100.0
## Desenho de reserva, chamado quando não há arte. Recebe este nó como CanvasItem.
var fallback := Callable()

## Como este pedaço resolve a própria arte: recebe a condição e devolve a textura, ou
## null quando não há arte para aquele estado. Vazio = só desenho procedural.
var art_resolver := Callable()

var _texture: Texture2D = null
var _condition := BodyPart.Condition.INTACT


## Troca a fonte da arte — muda quando a peça montada no encaixe muda.
func set_art_resolver(resolver: Callable) -> void:
	art_resolver = resolver
	_refresh_art()


## Em que estado este pedaço está. É daqui que sai a variante da arte, e é onde os VFX
## de faísca e fumaça vão se pendurar (ver feature_parts.md §4.2).
func set_condition(value: BodyPart.Condition) -> void:
	_condition = value
	_refresh_art()


## O estado atual, para quem desenha ou anima em cima deste nó: o desenho de reserva e,
## mais tarde, os VFX precisam saber disso sem ter de consultar o corpo outra vez.
func condition() -> BodyPart.Condition:
	return _condition


## Guarda a textura resolvida e só pede redesenho quando ela muda de verdade. O ganho
## ainda não aparece no `_sync()` — ele termina em `_redraw_all()`, que redesenha todo
## mundo —, mas vale para quem mexer só na condição deste pedaço.
func _refresh_art() -> void:
	var texture: Texture2D = art_resolver.call(_condition) if art_resolver.is_valid() else null
	if texture == _texture:
		return
	_texture = texture
	queue_redraw()


## Se este pedaço tem arte hoje, ou está caindo no desenho procedural.
func has_art() -> bool:
	return _texture != null


func _draw() -> void:
	if _texture != null:
		_draw_art()
	elif fallback.is_valid():
		fallback.call(self)


## A arte é ancorada pelo pé e centrada em X — o mesmo pivô que o pipeline do Aseprite
## usa (ver feature_parts.md §8). Assim uma peça encosta na vizinha em qualquer
## proporção que a imagem tenha, e trocar a arte não desloca o resto do corpo.
func _draw_art() -> void:
	var size := _texture.get_size()
	if size.y <= 0.0:
		return
	var draw_size := size * (art_height / size.y)
	var origin := art_offset - Vector2(draw_size.x * 0.5, draw_size.y)
	draw_texture_rect(_texture, Rect2(origin, draw_size), false)
