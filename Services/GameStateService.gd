extends Node

const BAG_SCRIPT = preload("res://Scripts/Resources/Classes/Bag.gd")

## GameStateService - Gestiona el estado temporal del juego en memoria
## Almacena datos clave del progreso durante la sesión actual
## Accesible globalmente como autoload: GameStateService

# === SEÑALES ===
signal flag_changed(flag_name: String, new_value: bool)
signal variable_changed(variable_name: String, new_value: Variant)
signal self_switch_changed(event_id: String, switch_letter: String, new_value: bool)
signal trainer_battle_result_changed(trainer_id: String, result: String)

# === DATOS DEL ESTADO DEL JUEGO ===
var current_map_id: String = ""
var current_position: Vector2i = Vector2i.ZERO
var facing_dir: Vector2 = Vector2.DOWN

# Flags globales (Dictionary: nombre -> bool)
var global_flags: Dictionary = {	"CHOOSING_STARTER": false}

# Variables globales del juego (Dictionary: nombre -> valor)
var game_variables: Dictionary = {	"BADGE_COUNT": 0}

# Self flags por evento (Dictionary: "event_uid:flag" -> bool)
# Ejemplo: "map_route1_trainer01:A" -> true
var event_self_flags: Dictionary = {}

# Resultados de combates contra entrenadores (Dictionary: trainer_id -> "V" o "D")
# trainer_id: identificador único del trainer (nombre del .res sin extensión)
# Valor: "V" si se ganó, "D" si se perdió
var defeated_trainers: Dictionary = {}

# Inventario global del jugador
var bag = BAG_SCRIPT.new()

# Cola de cambios diferidos que se aplicarán en el próximo warp
# Cada cambio es un Dictionary con "type" y "params"
var deferred_changes: Array[Dictionary] = []

# === INICIALIZACIÓN ===
func _ready() -> void:
	pass  # No inicializar automáticamente - se hará cuando sea necesario

## Inicializa el estado con valores por defecto para nueva partida
func initialize_new_game() -> void:
	current_map_id = "Pueblo_Paleta"
	current_position = Vector2i(1, 0)  # Posición por defecto en el mapa
	facing_dir = Vector2.DOWN
	bag = BAG_SCRIPT.new()
	_seed_test_bag_items()
	#global_flags = {}
	#game_variables = {}
	#event_self_flags = {}

## Carga items iniciales de prueba para validar BagUI rápidamente.
## TODO: mover a configuración de inventario inicial de diseño/juego.
func _seed_test_bag_items() -> void:
	var player_bag = get_bag()
	player_bag.add_item(17, 5)   # Poción (Medicine)
	player_bag.add_item(3, 10)   # Super Ball (Balls)
	player_bag.add_item(77, 2)   # Repelente Máximo (Items)
	player_bag.add_item(132, 3)  # Baya Aranja (Berries)
	# Muchas Poké Ball distintas para probar scroll/overflow en BagUI (bolsillo BALLS).
	player_bag.add_item(1, 1)    # Master Ball
	player_bag.add_item(2, 12)   # Ultra Ball
	player_bag.add_item(4, 8)    # Poké Ball
	player_bag.add_item(5, 6)    # Safari Ball
	player_bag.add_item(6, 5)    # Malla Ball
	player_bag.add_item(7, 5)    # Buceo Ball
	player_bag.add_item(8, 5)    # Nido Ball
	player_bag.add_item(9, 5)    # Acopio Ball
	player_bag.add_item(10, 5)   # Turno Ball
	player_bag.add_item(11, 5)   # Lujo Ball
	player_bag.add_item(12, 5)   # Honor Ball
	player_bag.add_item(13, 5)   # Ocaso Ball
	player_bag.add_item(14, 5)   # Sana Ball
	player_bag.add_item(15, 5)   # Veloz Ball
	player_bag.add_item(16, 5)   # Gloria Ball
	player_bag.add_item(449, 4)  # Cebo Ball
	player_bag.add_item(450, 4)  # Nivel Ball
	player_bag.add_item(451, 4)  # Luna Ball
	player_bag.add_item(452, 4)  # Peso Ball
	player_bag.add_item(453, 4)  # Rapid Ball
	player_bag.add_item(454, 4)  # Amigo Ball
	player_bag.add_item(455, 4)  # Amor Ball
	player_bag.add_item(456, 4)  # Parque Ball
	player_bag.add_item(457, 4)  # Competi Ball
	player_bag.add_item(617, 3)  # Ensueño Ball
	player_bag.add_item(887, 2)  # Ente Ball
	print("GameStateService: Bag de prueba inicializado con %d entradas." % get_bag_save_data().size())

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

## Retorna el valor de un flag global
func get_event_flag(flag_name: String) -> bool:
	return global_flags.get(flag_name, false)

## Retorna todos los flags globales
func get_all_event_flags() -> Dictionary:
	return global_flags.duplicate()

## Retorna el valor de una variable global
## Puede ser de cualquier tipo: int, bool, String, float, etc.
func get_variable(var_name: String, default_value: Variant = 0) -> Variant:
	return game_variables.get(var_name, default_value)

## Verifica si una variable global existe en el diccionario
func has_variable(var_name: String) -> bool:
	return game_variables.has(var_name)

## Retorna el valor de un self-switch (event_self_flag)
## event_id: ID único del evento (ej: "map_route1_trainer01")
## switch_letter: "A", "B", "C" o "D"
func get_self_switch(event_id: String, switch_letter: String) -> bool:
	var key = "%s:%s" % [event_id, switch_letter]
	return event_self_flags.get(key, false)

## Retorna el resultado de un combate contra un entrenador
## trainer_id: Identificador único del trainer (nombre del .res sin extensión)
## Retorna: "V" si se ganó, "D" si se perdió, o "" si no hay registro
func get_trainer_battle_result(trainer_id: String) -> String:
	return defeated_trainers.get(trainer_id, "")

## Retorna el inventario global del jugador
func get_bag():
	if bag == null:
		bag = BAG_SCRIPT.new()
	return bag

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

## Establece el valor de un flag global
func set_event_flag(flag_name: String, value: bool) -> void:
	var old_value = global_flags.get(flag_name, null)
	global_flags[flag_name] = value

	# Emitir señal solo si el valor cambió
	if old_value != value:
		flag_changed.emit(flag_name, value)

## Elimina un flag global
func clear_event_flag(flag_name: String) -> void:
	if global_flags.has(flag_name):
		global_flags.erase(flag_name)
		flag_changed.emit(flag_name, false)

## Establece el valor de una variable global
## El valor puede ser de cualquier tipo: int, bool, String, float, etc.
func set_variable(var_name: String, value: Variant) -> void:
	var old_value = game_variables.get(var_name, null)
	game_variables[var_name] = value

	# Emitir señal solo si el valor cambió
	if old_value != value:
		variable_changed.emit(var_name, value)

## Establece el valor de un self-switch (event_self_flag)
## event_id: ID único del evento (ej: nombre del nodo Event)
## switch_letter: "A", "B", "C" o "D"
func set_self_switch(event_id: String, switch_letter: String, value: bool) -> void:
	var key = "%s:%s" % [event_id, switch_letter]
	var old_value = event_self_flags.get(key, null)
	event_self_flags[key] = value

	# Emitir señal solo si el valor cambió
	if old_value != value:
		self_switch_changed.emit(event_id, switch_letter, value)

## Registra el resultado de un combate contra un entrenador
## trainer_id: Identificador único del trainer (nombre del .res sin extensión)
## result: "V" si se ganó, "D" si se perdió
func register_trainer_battle_result(trainer_id: String, result: String) -> void:
	if trainer_id.is_empty():
		push_warning("GameStateService: No se puede registrar resultado de combate con trainer_id vacío")
		return

	if result != "V" and result != "D":
		push_error("GameStateService: Resultado de combate inválido '%s'. Debe ser 'V' o 'D'" % result)
		return

	defeated_trainers[trainer_id] = result
	print("GameStateService: Registrado resultado trainer_id='%s', result='%s'. Emitiendo señal trainer_battle_result_changed" % [trainer_id, result])
	trainer_battle_result_changed.emit(trainer_id, result)
	print("GameStateService: Señal trainer_battle_result_changed emitida para trainer_id='%s'" % trainer_id)

# === SISTEMA DE CAMBIOS DIFERIDOS ===
## Registra un cambio diferido que se aplicará cuando se des-renderice el mapa donde se registró
## change_type: "variable", "flag", o "self_switch"
## params: Dictionary con los parámetros específicos del tipo de cambio
func defer_change(change_type: String, params: Dictionary) -> void:
	var map_id = get_current_map_id()
	deferred_changes.append({
		"type": change_type,
		"params": params,
		"map_id": map_id  # Asociar el cambio con el mapa donde se registró
	})

## Aplica los cambios diferidos asociados a un mapa específico
## Se llama automáticamente cuando se des-renderiza un mapa
## @param map_id: ID del mapa que se está des-renderizando (solo se aplican cambios de este mapa)
func apply_deferred_changes(map_id: String = "") -> void:
	if deferred_changes.is_empty():
		return

	# Si no se especifica map_id, aplicar todos (compatibilidad hacia atrás)
	# Pero es mejor especificar el map_id para aplicar solo los cambios del mapa que se des-renderiza
	var changes_to_apply: Array[Dictionary] = []
	var changes_to_keep: Array[Dictionary] = []

	for change in deferred_changes:
		if map_id.is_empty() or change.get("map_id", "") == map_id:
			# Este cambio pertenece al mapa que se está des-renderizando
			changes_to_apply.append(change)
		else:
			# Este cambio pertenece a otro mapa, mantenerlo
			changes_to_keep.append(change)

	if changes_to_apply.is_empty():
		return

	for change in changes_to_apply:
		match change.type:
			"variable":
				set_variable(change.params.name, change.params.value)
			"flag":
				set_event_flag(change.params.name, change.params.value)
			"self_switch":
				set_self_switch(change.params.event_id, change.params.switch_letter, change.params.value)
			_:
				push_warning("GameStateService: Tipo de cambio diferido desconocido: %s" % change.type)

	# Reemplazar la cola con solo los cambios que no se aplicaron
	deferred_changes = changes_to_keep

## Limpia todos los cambios diferidos sin aplicarlos
func clear_deferred_changes() -> void:
	deferred_changes.clear()

# === MÉTODOS DE TRANSICIÓN ===
## Cambia de mapa y actualiza la posición
func change_map(map_id: String, position: Vector2i) -> void:
	set_current_map_id(map_id)
	set_current_position(position)

## Actualiza la posición después de una transición de mapa
func update_position_after_transition(position: Vector2i) -> void:
	set_current_position(position)

# === MÉTODOS DE UTILIDAD ===
## Resetea el estado a los valores por defecto
func reset_to_default() -> void:
	initialize_new_game()

## Serializa el bag para guardado futuro (item_id + quantity)
func get_bag_save_data() -> Array[Dictionary]:
	return get_bag().to_serializable_data()

## Carga el bag desde una estructura serializada simple
func load_bag_save_data(entries: Array[Dictionary]) -> void:
	get_bag().load_serializable_data(entries)

## Retorna un resumen del estado actual
func get_state_summary() -> String:
	var summary = "=== ESTADO DEL JUEGO ===\n"
	summary += "Mapa: %s\n" % current_map_id
	summary += "Posición: %s\n" % current_position
	summary += "Dirección: %s\n" % facing_dir
	summary += "Flags: %s\n" % global_flags
	summary += "Variables: %s\n" % game_variables
	summary += "Self-switches: %s\n" % event_self_flags
	summary += "Bag entries: %d\n" % get_bag_save_data().size()
	return summary
