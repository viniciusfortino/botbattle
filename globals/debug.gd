## Flag global de debug do app (autoload `Debug`).
##
## Liga/desliga as ferramentas de inspeção — hoje, o painel de hitboxes do oponente.
##
## De onde vem o valor inicial, em ordem de prioridade:
##   1. `--` seguido de `--debug-on` ou `--debug-off` na linha de comando
##   2. a configuração `botbattle/debug/enabled` do projeto
##   3. `false`
##
## Em tempo de execução, F3 alterna (ou toque com três dedos, no celular).
extends Node

signal changed(enabled: bool)

const SETTING := "botbattle/debug/enabled"

var enabled: bool = false:
	set(value):
		if enabled == value:
			return
		enabled = value
		changed.emit(enabled)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var initial := bool(ProjectSettings.get_setting(SETTING, false))
	var args := OS.get_cmdline_user_args()
	if args.has("--debug-on"):
		initial = true
	elif args.has("--debug-off"):
		initial = false
	enabled = initial
	if enabled:
		print("[debug] modo de depuração ligado (F3 alterna)")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		toggle()
	elif event is InputEventScreenTouch and event.pressed and event.index == 2:
		toggle()


func toggle() -> void:
	enabled = not enabled
	print("[debug] modo de depuração ", "ligado" if enabled else "desligado")
