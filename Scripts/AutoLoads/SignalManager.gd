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

# === SEÑALES DEL GRID ACTIVO ===
signal active_grid_changed(grid: OverworldGrid)

# === SEÑALES DE INPUT DEL MESSAGEBOX ===
signal messagebox_input_accept()
signal messagebox_input_cancel()

# === SEÑALES DEL SISTEMA DE BATALLA ===
signal battle_requested(participants: Array, rules: BattleRules)
signal battle_started()
signal battle_finished(winner_side)


# --- Utilidades ---

##Desconecta todas las conexiones de una señal
func disconnect_all(signal_obj: Signal) -> void:

	for connection in signal_obj.get_connections():
		signal_obj.disconnect(connection.callable)

func _ready() -> void:
	print("SignalManager: Bus de señales globales inicializado")
