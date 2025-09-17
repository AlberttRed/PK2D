extends Node

## GameStateManager - Gestiona el estado temporal del juego en memoria
## Almacena datos clave del progreso durante la sesión actual

# === DATOS DEL ESTADO DEL JUEGO ===
var current_map_id: String = "test_map"
var current_spawn_id: String = "spawn_1"
var facing_dir: Vector2 = Vector2.DOWN

# Flags de eventos (Dictionary para flexibilidad)
var event_flags: Dictionary = {}

# === INICIALIZACIÓN ===
func _ready() -> void:
	print("GameStateManager: Inicializado con estado temporal")
	# Inicializar con datos de ejemplo
	_initialize_default_state()

## Inicializa el estado con valores por defecto
func _initialize_default_state() -> void:
	current_map_id = "test_map"
	current_spawn_id = "spawn_1"
	facing_dir = Vector2.LEFT
	event_flags = {}
	
	print("GameStateManager: Estado inicializado - Mapa: %s, Spawn: %s" % [current_map_id, current_spawn_id])

# === MÉTODOS DE LECTURA ===
## Retorna el ID del mapa actual
func get_current_map_id() -> String:
	return current_map_id

## Retorna el ID del spawn actual
func get_current_spawn_id() -> String:
	return current_spawn_id

## Retorna la dirección a la que mira el jugador
func get_facing_direction() -> Vector2:
	return facing_dir

## Retorna el valor de un flag de evento
func get_event_flag(flag_name: String) -> bool:
	return event_flags.get(flag_name, false)

## Retorna todos los flags de eventos
func get_all_event_flags() -> Dictionary:
	return event_flags.duplicate()

# === MÉTODOS DE ESCRITURA ===
## Establece el ID del mapa actual
func set_current_map_id(map_id: String) -> void:
	current_map_id = map_id
	print("GameStateManager: Mapa cambiado a: %s" % map_id)

## Establece el ID del spawn actual
func set_current_spawn_id(spawn_id: String) -> void:
	current_spawn_id = spawn_id
	print("GameStateManager: Spawn cambiado a: %s" % spawn_id)

## Establece la dirección a la que mira el jugador
func set_facing_direction(direction: Vector2) -> void:
	facing_dir = direction
	print("GameStateManager: Dirección cambiada a: %s" % direction)

## Establece el valor de un flag de evento
func set_event_flag(flag_name: String, value: bool) -> void:
	event_flags[flag_name] = value
	print("GameStateManager: Flag '%s' establecido a: %s" % [flag_name, value])

## Elimina un flag de evento
func clear_event_flag(flag_name: String) -> void:
	if event_flags.has(flag_name):
		event_flags.erase(flag_name)
		print("GameStateManager: Flag '%s' eliminado" % flag_name)

# === MÉTODOS DE TRANSICIÓN ===
## Cambia de mapa y actualiza el spawn
func change_map(map_id: String, spawn_id: String) -> void:
	set_current_map_id(map_id)
	set_current_spawn_id(spawn_id)
	print("GameStateManager: Transición a mapa '%s' en spawn '%s'" % [map_id, spawn_id])

## Actualiza el spawn después de una transición de mapa
func update_spawn_after_transition(spawn_id: String) -> void:
	set_current_spawn_id(spawn_id)

# === MÉTODOS DE UTILIDAD ===
## Retorna la posición del spawn actual (placeholder)
func get_spawn_position() -> Vector2i:
	# TODO: Integrar con sistema de spawns real
	# Por ahora retorna una posición por defecto
	match current_spawn_id:
		"spawn_1":
			return Vector2i(1, 7)
		"spawn_2":
			return Vector2i(10, 10)
		"spawn_3":
			return Vector2i(15, 15)
		_:
			return Vector2i(5, 5)

## Resetea el estado a los valores por defecto
func reset_to_default() -> void:
	_initialize_default_state()

## Retorna un resumen del estado actual
func get_state_summary() -> String:
	var summary = "=== ESTADO DEL JUEGO ===\n"
	summary += "Mapa: %s\n" % current_map_id
	summary += "Spawn: %s\n" % current_spawn_id
	summary += "Dirección: %s\n" % facing_dir
	summary += "Flags: %s\n" % event_flags
	return summary
