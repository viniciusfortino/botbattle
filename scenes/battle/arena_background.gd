## Arena em camadas de arte (sky/backdrop/floor de scenarios/<arena_id>/), com o
## desenho procedural de sempre como fallback — vazio ou faltando qualquer camada
## (§9.1: meia arena desenhada é pior que nenhuma).
@tool
extends Node2D

const SCENARIOS_PATH := "res://assets/source/scenarios"
const LAYER_NAMES := ["sky", "backdrop", "floor"]

## Vazio = desenho procedural. Preenchido = camadas de scenarios/<id>/.
@export var arena_id: String = "":
	set(value):
		arena_id = value
		_load_layers()
		queue_redraw()

@export var view_size := Vector2(1080.0, 1920.0):
	set(value):
		view_size = value
		queue_redraw()

## Linha do horizonte, em fração da altura. 151/384 = onde o grid de floor.png
## começa (§9.1) — o mesmo valor serve ao desenho procedural, para as duas versões
## da arena concordarem sobre onde o chão fica.
@export_range(0.2, 0.8, 0.001) var horizon: float = 151.0 / 384.0:
	set(value):
		horizon = value
		queue_redraw()

@export var sky_top := Color("0a1020")
@export var sky_bottom := Color("2a3f63")
@export var floor_color := Color("101a2c")
@export var grid_color := Color("3d7fb8")

## As 3 camadas resolvidas para `arena_id`, na ordem sky/backdrop/floor — vazio
## quando `arena_id` está vazio ou falta alguma camada.
var _layers: Array[Texture2D] = []


func _ready() -> void:
	_load_layers()


func _load_layers() -> void:
	_layers.clear()
	if arena_id.is_empty():
		return
	var base := "%s/%s" % [SCENARIOS_PATH, arena_id]
	var loaded: Array[Texture2D] = []
	for layer_name in LAYER_NAMES:
		var path := "%s/%s.png" % [base, layer_name]
		if not ResourceLoader.exists(path):
			return
		loaded.append(load(path))
	_layers = loaded


func _draw() -> void:
	if _layers.size() == LAYER_NAMES.size():
		_draw_layers()
	else:
		_draw_procedural()
	# As plataformas continuam por código nos dois casos — não fazem parte da arte
	# gerada, e é nelas que o jogador lê onde cada lutador está pisando.
	_platform(Vector2(view_size.x * 0.5, 900.0), Vector2(230.0, 46.0))
	_platform(Vector2(view_size.x * 0.5, 1560.0), Vector2(400.0, 70.0))


## As três camadas, esticadas de 216×384 para `view_size` — escala inteira (×5 em
## 1080×1920, ver §9). sky → backdrop → floor, nessa ordem.
func _draw_layers() -> void:
	var rect := Rect2(Vector2.ZERO, view_size)
	for layer in _layers:
		draw_texture_rect(layer, rect, false)


func _draw_procedural() -> void:
	var width := view_size.x
	var height := view_size.y
	var horizon_y := height * horizon

	# Céu em faixas (gradiente barato e sem shader).
	var bands := 48
	for i in bands:
		var t := float(i) / float(bands - 1)
		var band_height := horizon_y / float(bands) + 1.0
		draw_rect(Rect2(0.0, t * horizon_y, width, band_height), sky_top.lerp(sky_bottom, t))

	# Estrelas.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	for i in 90:
		var pos := Vector2(rng.randf() * width, rng.randf() * horizon_y * 0.85)
		var alpha := rng.randf_range(0.15, 0.7)
		draw_circle(pos, rng.randf_range(1.0, 3.0), Color(1, 1, 1, alpha))

	# Piso.
	draw_rect(Rect2(0.0, horizon_y, width, height - horizon_y), floor_color)
	draw_line(Vector2(0.0, horizon_y), Vector2(width, horizon_y), grid_color.lightened(0.3), 3.0)

	# Linhas em fuga.
	var vanish := Vector2(width * 0.5, horizon_y)
	var lines := 15
	for i in lines + 1:
		var t := float(i) / float(lines)
		var x := lerpf(-width * 1.6, width * 2.6, t)
		draw_line(vanish, Vector2(x, height), Color(grid_color, 0.18), 2.0)

	# Linhas horizontais com espaçamento crescente.
	var step := 8.0
	var y := horizon_y + step
	while y < height:
		draw_line(Vector2(0.0, y), Vector2(width, y), Color(grid_color, 0.13), 2.0)
		step *= 1.32
		y += step


func _platform(center: Vector2, radius: Vector2) -> void:
	_ellipse(center, radius * 1.25, Color(grid_color, 0.10))
	_ellipse(center, radius, Color(grid_color, 0.22))
	_ellipse(center, radius * 0.82, floor_color.lightened(0.06))


func _ellipse(center: Vector2, radius: Vector2, color: Color, segments: int = 48) -> void:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
