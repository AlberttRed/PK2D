extends Node

## SignalManager - Bus de señales globales para comunicación entre sistemas
## Permite desacoplar nodos y sistemas sin dependencias directas

# === SEÑALES DEL SISTEMA DE EVENTOS ===
signal event_requested(event: Event, controller: EventController)
signal event_started(event: Event)
signal event_finished(event: Event)

# === SEÑALES DEL SISTEMA DE WARP ===
signal warp_requested(map_id: String, spawn_id: String)
signal warp_started(map_id: String, spawn_id: String)
signal warp_finished(map_id: String, spawn_id: String)
signal map_change_requested(from_map: String, to_map: String)

# === SEÑALES DEL SISTEMA SEAMLESS ===
signal seamless_map_crossed(from_map_id: String, to_map_id: String)

# === SEÑALES DE CONTROL DEL JUGADOR ===
signal player_control_blocked()
signal player_control_unblocked()

# === SEÑALES DE SISTEMAS ===
signal event_system_ready(system: Node)
signal warp_system_ready(system: Node)
signal map_system_ready(system: Node)

# === SEÑALES DEL MESSAGEBOX ===
signal message_requested(text: String, config: Dictionary)
signal message_finished()
signal message_input_received()

# === SEÑALES DEL SISTEMA DE FADE ===
signal fade_requested(mode: String, duration: float)
signal fade_finished()
signal battle_transition_requested(texture_path: String, duration: float)
signal battle_transition_finished()
signal battle_reveal_requested()
signal battle_reveal_finished()
signal hide_overworld_messagebox()  ## Se emite justo antes del fade a negro en transición de batalla

# === SEÑALES DEL GRID ACTIVO ===
signal active_grid_changed(grid: OverworldGrid)

# === SEÑALES DE INPUT DEL MESSAGEBOX ===
signal messagebox_input_accept()
signal messagebox_input_cancel()

# === SEÑALES DEL SISTEMA DE BATALLA ===
signal battle_requested(participants: Array, rules: BattleRules)
signal battle_started()
signal battle_finished(winner_side)

# === SEÑALES DEL SISTEMA DE GAME STATE ===
signal game_flag_changed(flag_name: String, new_value: bool)
signal game_variable_changed(variable_name: String, new_value: int)
signal game_self_switch_changed(event_id: String, switch_letter: String, new_value: bool)

# === SEÑALES DE INPUT GLOBAL ===
signal input_accept()
signal input_cancel()
signal input_start()
signal input_left()
signal input_right()
signal input_up()
signal input_down()
signal input_select()


# --- Utilidades ---

##Desconecta todas las conexiones de una señal
func disconnect_all(signal_obj: Signal) -> void:

	for connection in signal_obj.get_connections():
		signal_obj.disconnect(connection.callable)

func _ready() -> void:
	print("SignalManager: Bus de señales globales inicializado")
	
	# Conectar señales de GameStateManager para reenviarlas globalmente
	GameStateManager.flag_changed.connect(_on_game_flag_changed)
	GameStateManager.variable_changed.connect(_on_game_variable_changed)
	GameStateManager.self_switch_changed.connect(_on_game_self_switch_changed)

## Reenvía señal de flag cambiado
func _on_game_flag_changed(flag_name: String, new_value: bool) -> void:
	game_flag_changed.emit(flag_name, new_value)

## Reenvía señal de variable cambiada
func _on_game_variable_changed(variable_name: String, new_value: int) -> void:
	game_variable_changed.emit(variable_name, new_value)

## Reenvía señal de self-switch cambiado
func _on_game_self_switch_changed(event_id: String, switch_letter: String, new_value: bool) -> void:
	game_self_switch_changed.emit(event_id, switch_letter, new_value)
