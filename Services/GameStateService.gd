extends Node

## GameStateService - Gestiona el estado temporal del juego en memoria
## Almacena datos clave del progreso durante la sesión actual
## Accesible globalmente como autoload: GameStateService

# === SEÑALES ===
signal flag_changed(flag_name: String, new_value: bool)
signal variable_changed(variable_name: String, new_value: int)
signal self_switch_changed(event_id: String, switch_letter: String, new_value: bool)

# === DATOS DEL ESTADO DEL JUEGO ===
var current_map_id: String = ""
var current_position: Vector2i = Vector2i.ZERO
var facing_dir: Vector2 = Vector2.DOWN

# Flags de eventos (Dictionary para flexibilidad)
var event_flags: Dictionary = {	"CHOOSING_STARTER": true,
								"HAS_POKEDEX": false}

# Variables globales del juego (Dictionary: nombre -> valor)
var game_variables: Dictionary = {}

# Self-switches por evento (Dictionary: "event_id:switch" -> bool)
# Ejemplo: "map_route1_trainer01:A" -> true
var self_switches: Dictionary = {}

# === INICIALIZACIÓN ===
func _ready() -> void:
	pass  # No inicializar automáticamente - se hará cuando sea necesario

## Inicializa el estado con valores por defecto para nueva partida
func initialize_new_game() -> void:
	current_map_id = "Pueblo_Paleta"
	current_position = Vector2i(1, 0)  # Posición por defecto en el mapa
	facing_dir = Vector2.DOWN
	#event_flags = {}
	#game_variables = {}
	#self_switches = {}

## Carga un estado guardado (placeholder para futuro)
func load_saved_game() -> bool:
	# TODO: Implementar carga desde archivo de guardado
	# Por ahora, simular que no hay partida guardada
	return false

# === MÉTODOS DE LECTURA ===
## Retorna el ID del mapa actual
func get_current_map_id() -> String:
	return current_map_id

## Retorna la posición actual del jugador
func get_current_position() -> Vector2i:
	return current_position

## Retorna la dirección a la que mira el jugador
func get_facing_direction() -> Vector2:
	return facing_dir

## Retorna el valor de un flag de evento
func get_event_flag(flag_name: String) -> bool:
	return event_flags.get(flag_name, false)

## Retorna todos los flags de eventos
func get_all_event_flags() -> Dictionary:
	return event_flags.duplicate()

## Retorna el valor de una variable global
func get_variable(var_name: String, default_value: int = 0) -> int:
	return game_variables.get(var_name, default_value)

## Retorna el valor de un self-switch
## event_id: ID único del evento (ej: "map_route1_trainer01")
## switch_letter: "A", "B", "C" o "D"
func get_self_switch(event_id: String, switch_letter: String) -> bool:
	var key = "%s:%s" % [event_id, switch_letter]
	return self_switches.get(key, false)

# === MÉTODOS DE ESCRITURA ===
## Establece el ID del mapa actual
func set_current_map_id(map_id: String) -> void:
	current_map_id = map_id

## Establece la posición actual del jugador
func set_current_position(position: Vector2i) -> void:
	current_position = position

## Establece la dirección a la que mira el jugador
func set_facing_direction(direction: Vector2) -> void:
	facing_dir = direction

## Establece el valor de un flag de evento
func set_event_flag(flag_name: String, value: bool) -> void:
	var old_value = event_flags.get(flag_name, null)
	event_flags[flag_name] = value
	print("GameStateService: Flag '%s' establecido a: %s" % [flag_name, value])

	# Emitir señal solo si el valor cambió
	if old_value != value:
		flag_changed.emit(flag_name, value)

## Elimina un flag de evento
func clear_event_flag(flag_name: String) -> void:
	if event_flags.has(flag_name):
		event_flags.erase(flag_name)
		print("GameStateService: Flag '%s' eliminado" % flag_name)
		flag_changed.emit(flag_name, false)

## Establece el valor de una variable global
func set_variable(var_name: String, value: int) -> void:
	var old_value = game_variables.get(var_name, null)
	game_variables[var_name] = value
	print("GameStateService: Variable '%s' establecida a: %d" % [var_name, value])

	# Emitir señal solo si el valor cambió
	if old_value != value:
		variable_changed.emit(var_name, value)

## Establece el valor de un self-switch
## event_id: ID único del evento (ej: nombre del nodo Event)
## switch_letter: "A", "B", "C" o "D"
func set_self_switch(event_id: String, switch_letter: String, value: bool) -> void:
	var key = "%s:%s" % [event_id, switch_letter]
	var old_value = self_switches.get(key, null)
	self_switches[key] = value
	print("GameStateService: Self-switch '%s' establecido a: %s" % [key, value])

	# Emitir señal solo si el valor cambió
	if old_value != value:
		self_switch_changed.emit(event_id, switch_letter, value)

# === MÉTODOS DE TRANSICIÓN ===
## Cambia de mapa y actualiza la posición
func change_map(map_id: String, position: Vector2i) -> void:
	set_current_map_id(map_id)
	set_current_position(position)
	print("GameStateService: Transición a mapa '%s' en posición '%s'" % [map_id, position])

## Actualiza la posición después de una transición de mapa
func update_position_after_transition(position: Vector2i) -> void:
	set_current_position(position)

# === MÉTODOS DE UTILIDAD ===
## Resetea el estado a los valores por defecto
func reset_to_default() -> void:
	initialize_new_game()

## Retorna un resumen del estado actual
func get_state_summary() -> String:
	var summary = "=== ESTADO DEL JUEGO ===\n"
	summary += "Mapa: %s\n" % current_map_id
	summary += "Posición: %s\n" % current_position
	summary += "Dirección: %s\n" % facing_dir
	summary += "Flags: %s\n" % event_flags
	summary += "Variables: %s\n" % game_variables
	summary += "Self-switches: %s\n" % self_switches
	return summary
