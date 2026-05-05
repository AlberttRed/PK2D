extends Node

const BAG_SCRIPT = preload("res://Scripts/Resources/Classes/Bag.gd")
const PARTY_SCRIPT = preload("res://Scripts/Resources/Classes/Party.gd")
const POKEDEX_SCRIPT = preload("res://Scripts/Runtime/Pokedex.gd")
const POKEMON_RUNTIME_SERDE = preload("res://Scripts/Runtime/PokemonRuntimeSerde.gd")
const SAVE_VERSION: int = 1
const SAVE_DIR_PATH := "user://saves"
const DEFAULT_SAVE_SLOT: int = 0
## Último “Centro Pokémon” / punto de blanqueo por defecto (partidas antiguas sin `respawn_point` o dato inválido).
const DEFAULT_RESPAWN_MAP_ID: String = "Pueblo_Paleta"
const DEFAULT_RESPAWN_POSITION: Vector2i = Vector2i(1, 0)
## Flag global: el jugador ya tiene la Pokédex (entradas de menú de pausa, etc.).
const FLAG_HAS_POKEDEX: String = "HAS_POKEDEX"

## GameStateService - Gestiona el estado temporal del juego en memoria
## Almacena datos clave del progreso durante la sesión actual
## Accesible globalmente como autoload: GameStateService
##
## Modo debug de contenido/arranque: lo fija `Main.debug_mode` en la primera
## carga (export). Afecta p. ej. a `initialize_new_game` (seeds de prueba) y
## al flujo (menú vs entrada directa). Cualquier script: `if GameStateService.debug_mode:`.
## No confundir con `OS.is_debug_build()` (plantilla de export) ni con
## `Engine.is_editor_hint()` (jugar desde el editor).
var debug_mode: bool = false

# === SEÑALES ===
signal flag_changed(flag_name: String, new_value: bool)
signal variable_changed(variable_name: String, new_value: Variant)
signal self_switch_changed(event_id: String, switch_letter: String, new_value: bool)
signal trainer_battle_result_changed(trainer_id: String, result: String)

# === DATOS DEL ESTADO DEL JUEGO ===
var current_map_id: String = ""
var current_position: Vector2i = Vector2i.ZERO
var facing_dir: Vector2 = Vector2.DOWN
var respawn_point: Dictionary = {
	"map_id": "",
	"position": Vector2i.ZERO,
	"facing": Vector2.DOWN,
}
## Dinero del jugador (PBI 587). Solo modelo + save; sin tiendas aún.
var money: int = 0

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

# Equipo del jugador (máx. 6 Pokémon); sin dependencia de UI
var party = PARTY_SCRIPT.new()

# Pokédex global del jugador (por species_id)
var pokedex = POKEDEX_SCRIPT.new()
var unlocked_pokedex_ids: Array[String] = []
var active_pokedex_id: String = ""

# Cola de cambios diferidos que se aplicarán en el próximo warp
# Cada cambio es un Dictionary con "type" y "params"
var deferred_changes: Array[Dictionary] = []

# === INICIALIZACIÓN ===
func _ready() -> void:
	pass  # No inicializar automáticamente - se hará cuando sea necesario

## Inicializa el estado con valores por defecto para nueva partida
func initialize_new_game() -> void:
	current_map_id = "Casa_Red"
	current_position = Vector2i(27, 4)  # Posición por defecto en el mapa (coordenada de tile)
	facing_dir = Vector2.UP
	if debug_mode:
		# Spawn clásico de debug para iterar rápido: Pueblo Paleta.
		current_map_id = "Pueblo_Paleta"
		current_position = Vector2i(1, 0)
		facing_dir = Vector2.DOWN
	money = 0
	set_respawn_point(current_map_id, current_position, facing_dir)
	bag = BAG_SCRIPT.new()
	party = PARTY_SCRIPT.new()
	pokedex = POKEDEX_SCRIPT.new()
	unlocked_pokedex_ids = ["kanto", "updated-johto", "national"]
	active_pokedex_id = "kanto"
	if debug_mode:
		set_event_flag(FLAG_HAS_POKEDEX, true)
		_seed_test_pokedex_progress()
		_seed_test_bag_items()
		_seed_test_party_placeholder()
	#global_flags = {}
	#game_variables = {}
	#event_self_flags = {}

## Carga items iniciales de prueba para validar BagUI rápidamente.
## TODO: mover a configuración de inventario inicial de diseño/juego.
func _seed_test_bag_items() -> void:
	var player_bag = get_bag()
	player_bag.add_item(17, 5)   # Poción (Medicine)
	player_bag.add_item(18, 8)   # Antídoto (Medicine)
	player_bag.add_item(28, 3)   # Revivir (Medicine)
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


## Añade un Pokémon de prueba al equipo para validar PartyUI / resumen HGSS.
## TODO: sustituir por starter real o carga de partida guardada.
func _seed_test_party_placeholder() -> void:
	var player_party: Party = get_party()
	if player_party.count() > 0:
		return
	# [species_id, level] — Bulbasaur, Squirtle, Charmander, Pikachu, Eevee (+ Snorlax comentado: 5 en equipo).
	var test_mons: Array[Vector2i] = [
		Vector2i(1, 15), Vector2i(7, 12), Vector2i(4, 13), Vector2i(25, 11), Vector2i(133, 10),
		# Vector2i(143, 9),  # Snorlax (último añadido; descomentar para 6º slot)
	]
	var added := 0
	for spec: Vector2i in test_mons:
		var species_id := spec.x
		var lvl := spec.y
		if DatabaseService.get_pokemon(species_id) == null:
			push_warning("GameStateService: species_id=%d no existe; se omite esa entrada de prueba." % species_id)
			continue
		var mon := Pokemon.new(species_id, lvl, 0, 0, 0, true)
		if mon == null or mon.base == null:
			push_warning("GameStateService: no se pudo instanciar Pokémon de prueba (species_id=%d)." % species_id)
			continue
		mon.is_wild = false
		mon.original_trainer = "Debug"
		if player_party.add_pokemon(mon):
			added += 1
		else:
			push_warning("GameStateService: add_pokemon falló (species_id=%d)." % species_id)
	if added > 0:
		print("GameStateService: Party de prueba con %d Pokémon." % added)
		# Debug: un Pokémon debilitado (Revivir) y Pikachu envenenado (Antídoto).
		var bulba: Pokemon = player_party.get_pokemon(0)
		if bulba != null:
			bulba.hp_actual = 0
			bulba.major_status = CONST.STATUS.OK
		var pika: Pokemon = player_party.get_pokemon(3)
		if pika != null and pika.hp_actual > 0:
			pika.major_status = CONST.STATUS.POISON


## Rellena progreso de Pokédex de prueba (mezcla vistos/capturados) para validar UI.
## Nota: "capturado" implica "visto" en el modelo.
func _seed_test_pokedex_progress() -> void:
	var pdx = get_pokedex()
	# 20 especies aleatorias de Kanto para pruebas visuales.
	var seen_only_species: Array[int] = [5, 8, 11, 14, 19, 23, 27, 32, 41, 54, 58, 66, 74, 92]
	var caught_species: Array[int] = [1, 4, 7, 25, 39, 52]
	for species_id in seen_only_species:
		pdx.mark_seen(species_id)
	for species_id in caught_species:
		pdx.mark_caught(species_id)
	print("GameStateService: Pokédex de prueba -> vistos=%d capturados=%d" % [
		pdx.get_seen_count(),
		pdx.get_caught_count()
	])


## Carga un estado guardado (placeholder para futuro)
func load_saved_game() -> bool:
	return load_game(DEFAULT_SAVE_SLOT)

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


func get_respawn_point() -> Dictionary:
	## Nunca devolver mapa vacío: el blanqueo siempre apunta a un sitio seguro.
	var mid: String = str(respawn_point.get("map_id", ""))
	if mid.is_empty():
		mid = DEFAULT_RESPAWN_MAP_ID
	var pos: Vector2i = _variant_to_vector2i(respawn_point.get("position", DEFAULT_RESPAWN_POSITION), DEFAULT_RESPAWN_POSITION)
	var fac: Vector2 = _variant_to_vector2(respawn_point.get("facing", Vector2.DOWN), Vector2.DOWN)
	return {
		"map_id": mid,
		"position": pos,
		"facing": fac,
	}

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


## Equipo Pokémon del jugador (estado global de sesión)
func get_party():
	if party == null:
		party = PARTY_SCRIPT.new()
	return party


## Equipo leído solo del JSON del slot (no modifica el party en memoria). Para UI, p. ej. iconos en «Continuar».
func get_save_party_preview_pokemon(slot_id: int = DEFAULT_SAVE_SLOT) -> Array[Pokemon]:
	var out: Array[Pokemon] = []
	var save_data: Dictionary = _read_save_data(slot_id)
	if save_data.is_empty():
		return out
	var party_any: Variant = save_data.get("party", [])
	if not (party_any is Array):
		return out
	var serde: PokemonRuntimeSerde = POKEMON_RUNTIME_SERDE.new() as PokemonRuntimeSerde
	for entry_any: Variant in party_any:
		if not (entry_any is Dictionary):
			continue
		var mon: Pokemon = serde.deserialize(entry_any) as Pokemon
		if mon != null and mon.base != null:
			out.append(mon)
		if out.size() >= 6:
			break
	return out


## Pokédex global de sesión
func get_pokedex():
	if pokedex == null:
		pokedex = POKEDEX_SCRIPT.new()
	return pokedex


func get_unlocked_pokedex_ids() -> Array[String]:
	return unlocked_pokedex_ids.duplicate()


func is_pokedex_unlocked(dex_id: String) -> bool:
	return unlocked_pokedex_ids.has(dex_id)


func unlock_pokedex(dex_id: String) -> void:
	if dex_id.is_empty():
		return
	if unlocked_pokedex_ids.has(dex_id):
		return
	unlocked_pokedex_ids.append(dex_id)
	if active_pokedex_id.is_empty():
		active_pokedex_id = dex_id


func get_active_pokedex_id() -> String:
	if active_pokedex_id.is_empty() and not unlocked_pokedex_ids.is_empty():
		active_pokedex_id = unlocked_pokedex_ids[0]
	return active_pokedex_id


func set_active_pokedex_id(dex_id: String) -> bool:
	if dex_id.is_empty():
		return false
	if not unlocked_pokedex_ids.has(dex_id):
		return false
	active_pokedex_id = dex_id
	return true


## Lista densa de Pokémon del equipo (fallback combate salvaje si no hay `Battler`).
func get_player_party() -> Array:
	var p: Party = get_party()
	var out: Array = []
	for i in range(p.count()):
		out.append(p.get_pokemon(i))
	return out

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


func set_respawn_point(map_id: String, position: Vector2i, facing: Vector2 = Vector2.DOWN) -> void:
	if map_id.is_empty():
		push_warning("GameStateService.set_respawn_point: map_id vacío, se ignora")
		return
	respawn_point = {
		"map_id": map_id,
		"position": position,
		"facing": facing,
	}


## Acepta diccionario con al menos `map_id`, `position` (Vector2i o {x,y}), `facing` opcional.
func set_respawn_point_data(data: Dictionary) -> void:
	var m := str(data.get("map_id", ""))
	if m.is_empty():
		push_warning("GameStateService.set_respawn_point_data: map_id vacío")
		return
	var p: Vector2i = _variant_to_vector2i(data.get("position", Vector2i.ZERO), Vector2i.ZERO)
	var f: Vector2 = _variant_to_vector2(data.get("facing", Vector2.DOWN), Vector2.DOWN)
	set_respawn_point(m, p, f)


func get_money() -> int:
	return money


func can_afford(amount: int) -> bool:
	return amount >= 0 and money >= amount


## Añade dinero; `amount` debe ser >= 0.
func add_money(amount: int) -> void:
	if amount < 0:
		push_warning("GameStateService.add_money: amount negativo ignorado")
		return
	money = mini(money + amount, 2147483647)


## Quitar dinero. Devuelve false si no había suficiente (el saldo no cambia).
func remove_money(amount: int) -> bool:
	if amount < 0:
		push_warning("GameStateService.remove_money: amount negativo rechazado")
		return false
	if money < amount:
		return false
	money -= amount
	return true


func _normalize_money_value(value: Variant) -> int:
	var n: int = 0
	if value is int:
		n = int(value)
	elif value is float:
		n = int(floor(float(value)))
	elif str(value).is_valid_int():
		n = int(str(value))
	else:
		push_warning("GameStateService: money en save con tipo no numérico; se usa 0")
		return 0
	if n < 0:
		push_warning("GameStateService: money negativo en save (%d); se normaliza a 0" % n)
		return 0
	return n

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


## Serializa la party para guardado futuro (datos planos por Pokémon)
func get_party_save_data() -> Array[Dictionary]:
	return get_party().to_serializable_data()


## Restaura la party desde datos serializados
func load_party_save_data(entries: Array[Dictionary]) -> void:
	get_party().load_serializable_data(entries)


## Serializa la Pokédex para guardado futuro.
func get_pokedex_save_data() -> Dictionary:
	return get_pokedex().to_serializable_data()


## Restaura la Pokédex desde datos serializados.
func load_pokedex_save_data(data: Dictionary) -> void:
	get_pokedex().load_serializable_data(data)


func get_pokedex_registry_save_data() -> Dictionary:
	return {
		"unlocked_dex_ids": unlocked_pokedex_ids.duplicate(),
		"active_dex_id": get_active_pokedex_id(),
	}


func load_pokedex_registry_save_data(data: Dictionary) -> void:
	unlocked_pokedex_ids.clear()
	var unlocked_any: Variant = data.get("unlocked_dex_ids", [])
	if unlocked_any is Array:
		for dex_any in unlocked_any:
			var dex_id := str(dex_any)
			if dex_id.is_empty():
				continue
			if not unlocked_pokedex_ids.has(dex_id):
				unlocked_pokedex_ids.append(dex_id)
	if unlocked_pokedex_ids.is_empty():
		unlocked_pokedex_ids = ["kanto"]
	var desired_active := str(data.get("active_dex_id", ""))
	if desired_active.is_empty() or not unlocked_pokedex_ids.has(desired_active):
		active_pokedex_id = unlocked_pokedex_ids[0]
	else:
		active_pokedex_id = desired_active


func get_save_path(slot_id: int = DEFAULT_SAVE_SLOT) -> String:
	var safe_slot := maxi(0, slot_id)
	return "%s/slot_%02d.save.json" % [SAVE_DIR_PATH, safe_slot]


func has_save(slot_id: int = DEFAULT_SAVE_SLOT) -> bool:
	var path := get_save_path(slot_id)
	return FileAccess.file_exists(path)


func has_valid_save(slot_id: int = DEFAULT_SAVE_SLOT) -> bool:
	return not _read_save_data(slot_id).is_empty()


func get_save_metadata(slot_id: int = DEFAULT_SAVE_SLOT) -> Dictionary:
	var save_data := _read_save_data(slot_id)
	if save_data.is_empty():
		return {"ok": false}

	var player_state_any: Variant = save_data.get("player_state", {})
	var player_state: Dictionary = player_state_any if player_state_any is Dictionary else {}
	var map_id := str(player_state.get("current_map_id", ""))
	var route_text := map_id.replace("_", " ").strip_edges()
	if route_text.is_empty():
		route_text = "—"

	var flags_any: Variant = save_data.get("flags", {})
	var flags_data: Dictionary = flags_any if flags_any is Dictionary else {}
	var vars_any: Variant = flags_data.get("game_variables", {})
	var game_vars: Dictionary = vars_any if vars_any is Dictionary else {}
	var player_name := str(game_vars.get("PLAYER_NAME", "PLAYER")).strip_edges()
	if player_name.is_empty():
		player_name = "PLAYER"
	var badges := int(game_vars.get("BADGE_COUNT", 0))

	var pokedex_any: Variant = save_data.get("pokedex", {})
	var pokedex_data: Dictionary = pokedex_any if pokedex_any is Dictionary else {}
	var entries_any: Variant = pokedex_data.get("entries", {})
	var entries: Dictionary = entries_any if entries_any is Dictionary else {}
	var caught_count := 0
	for key in entries.keys():
		var entry_any: Variant = entries.get(key, {})
		if entry_any is Dictionary and bool((entry_any as Dictionary).get("caught", false)):
			caught_count += 1

	return {
		"ok": true,
		"slot_id": slot_id,
		"route_text": route_text,
		"player_name": player_name,
		"badges": badges,
		"pokedex_caught": caught_count,
		# TODO: sustituir por tiempo real persistido cuando exista contador de juego global.
		"play_time": "00:00",
	}


func save_game(slot_id: int = DEFAULT_SAVE_SLOT) -> Dictionary:
	var path := get_save_path(slot_id)
	var dir_path := path.get_base_dir()
	var mk_err := DirAccess.make_dir_recursive_absolute(dir_path)
	if mk_err != OK:
		var mk_msg := "No se pudo crear directorio de guardado (%s). error=%d" % [dir_path, mk_err]
		push_error("GameStateService.save_game: %s" % mk_msg)
		return {"ok": false, "message": mk_msg, "path": path, "error_code": mk_err}

	var payload := _build_save_payload()
	var json_text := JSON.stringify(payload, "\t")
	if json_text.is_empty():
		var json_msg := "Error serializando payload de guardado."
		push_error("GameStateService.save_game: %s" % json_msg)
		return {"ok": false, "message": json_msg, "path": path}

	var temp_path := "%s.tmp" % path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_err := FileAccess.get_open_error()
		var open_msg := "No se pudo abrir temporal de guardado (%s). error=%d" % [temp_path, open_err]
		push_error("GameStateService.save_game: %s" % open_msg)
		return {"ok": false, "message": open_msg, "path": path, "error_code": open_err}
	file.store_string(json_text)
	file.flush()
	file = null

	if FileAccess.file_exists(path):
		var rm_err := DirAccess.remove_absolute(path)
		if rm_err != OK:
			var rm_msg := "No se pudo reemplazar save previo (%s). error=%d" % [path, rm_err]
			push_error("GameStateService.save_game: %s" % rm_msg)
			DirAccess.remove_absolute(temp_path)
			return {"ok": false, "message": rm_msg, "path": path, "error_code": rm_err}

	var rename_err := DirAccess.rename_absolute(temp_path, path)
	if rename_err != OK:
		var rename_msg := "No se pudo finalizar guardado atómico (%s). error=%d" % [path, rename_err]
		push_error("GameStateService.save_game: %s" % rename_msg)
		DirAccess.remove_absolute(temp_path)
		return {"ok": false, "message": rename_msg, "path": path, "error_code": rename_err}

	print("GameStateService.save_game: slot=%d guardado en %s (party=%d, bag=%d, pokedex_seen=%d, pokedex_caught=%d, flags=%d)" % [
		slot_id,
		path,
		get_party().count(),
		get_bag_save_data().size(),
		get_pokedex().get_seen_count(),
		get_pokedex().get_caught_count(),
		global_flags.size(),
	])
	return {"ok": true, "message": "Partida guardada.", "path": path, "slot_id": slot_id}


func load_game(slot_id: int = DEFAULT_SAVE_SLOT) -> bool:
	var save_data := _read_save_data(slot_id)
	if save_data.is_empty():
		return false
	var save_version := int(save_data.get("save_version", 0))
	_apply_save_payload(save_data)
	var path := get_save_path(slot_id)
	print("GameStateService.load_game: slot=%d cargado desde %s (save_version=%d)." % [slot_id, path, save_version])
	return true


func _build_save_payload() -> Dictionary:
	var now_iso := Time.get_datetime_string_from_system(true, true)
	var rp := get_respawn_point()
	return {
		"save_version": SAVE_VERSION,
		"saved_at": now_iso,
		"player_state": {
			"current_map_id": current_map_id,
			"current_position": _vector2i_to_dict(current_position),
			"facing_dir": _vector2_to_dict(facing_dir),
			"money": int(money),
		},
		"respawn_point": {
			"map_id": str(rp.get("map_id", current_map_id)),
			"position": _vector2i_to_dict(_variant_to_vector2i(rp.get("position", current_position), current_position)),
			"facing": _vector2_to_dict(_variant_to_vector2(rp.get("facing", facing_dir), facing_dir)),
		},
		"party": get_party_save_data(),
		"bag": get_bag_save_data(),
		"pokedex": get_pokedex_save_data(),
		"pokedex_registry": get_pokedex_registry_save_data(),
		"flags": {
			"global_flags": global_flags.duplicate(true),
			"game_variables": game_variables.duplicate(true),
			"event_self_flags": event_self_flags.duplicate(true),
			"defeated_trainers": defeated_trainers.duplicate(true),
		},
	}


func _apply_save_payload(save_data: Dictionary) -> void:
	var player_state_any: Variant = save_data.get("player_state", {})
	var player_state: Dictionary = player_state_any if player_state_any is Dictionary else {}
	current_map_id = str(player_state.get("current_map_id", "Pueblo_Paleta"))
	current_position = _variant_to_vector2i(player_state.get("current_position", Vector2i(1, 0)), Vector2i(1, 0))
	facing_dir = _variant_to_vector2(player_state.get("facing_dir", Vector2.DOWN), Vector2.DOWN)
	if player_state.has("money"):
		money = _normalize_money_value(player_state.get("money", 0))
	else:
		money = 0

	var respawn_any: Variant = save_data.get("respawn_point", null)
	if respawn_any == null or (respawn_any is Dictionary and (respawn_any as Dictionary).is_empty()) or not (respawn_any is Dictionary):
		set_respawn_point(DEFAULT_RESPAWN_MAP_ID, DEFAULT_RESPAWN_POSITION, Vector2.DOWN)
	else:
		var respawn_data: Dictionary = respawn_any as Dictionary
		var rp_map := str(respawn_data.get("map_id", ""))
		if rp_map.is_empty():
			set_respawn_point(DEFAULT_RESPAWN_MAP_ID, DEFAULT_RESPAWN_POSITION, Vector2.DOWN)
		else:
			var rp_pos := _variant_to_vector2i(respawn_data.get("position", DEFAULT_RESPAWN_POSITION), DEFAULT_RESPAWN_POSITION)
			var rp_facing := _variant_to_vector2(respawn_data.get("facing", Vector2.DOWN), Vector2.DOWN)
			set_respawn_point(rp_map, rp_pos, rp_facing)

	var bag_any: Variant = save_data.get("bag", [])
	if bag_any is Array:
		var safe_bag_entries: Array[Dictionary] = []
		for entry_any in bag_any:
			if entry_any is Dictionary:
				safe_bag_entries.append(entry_any)
		load_bag_save_data(safe_bag_entries)
	else:
		load_bag_save_data([])

	var party_any: Variant = save_data.get("party", [])
	if party_any is Array:
		var safe_party_entries: Array[Dictionary] = []
		for entry_any in party_any:
			if entry_any is Dictionary:
				safe_party_entries.append(entry_any)
		load_party_save_data(safe_party_entries)
	else:
		load_party_save_data([])

	var pokedex_any: Variant = save_data.get("pokedex", {})
	var raw_pokedex: Dictionary = pokedex_any if pokedex_any is Dictionary else {}
	load_pokedex_save_data(_sanitize_pokedex_save_data(raw_pokedex))

	var pdx_registry_any: Variant = save_data.get("pokedex_registry", {})
	if pdx_registry_any is Dictionary:
		load_pokedex_registry_save_data(pdx_registry_any)
	else:
		load_pokedex_registry_save_data({})

	var flags_any: Variant = save_data.get("flags", {})
	var flags_data: Dictionary = flags_any if flags_any is Dictionary else {}
	global_flags = _variant_to_dictionary(flags_data.get("global_flags", {}))
	game_variables = _variant_to_dictionary(flags_data.get("game_variables", {}))
	event_self_flags = _variant_to_dictionary(flags_data.get("event_self_flags", {}))
	defeated_trainers = _variant_to_dictionary(flags_data.get("defeated_trainers", {}))


func _read_save_data(slot_id: int) -> Dictionary:
	var path := get_save_path(slot_id)
	if not FileAccess.file_exists(path):
		print("GameStateService: no existe save para slot=%d (%s)." % [slot_id, path])
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameStateService: no se pudo abrir %s. error=%d" % [path, FileAccess.get_open_error()])
		return {}
	var raw_text := file.get_as_text()
	file = null
	if raw_text.is_empty():
		push_error("GameStateService: archivo de save vacío en %s." % path)
		return {}
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameStateService: JSON inválido en %s." % path)
		return {}
	return parsed


func _sanitize_pokedex_save_data(data: Dictionary) -> Dictionary:
	var safe: Dictionary = data.duplicate(true)
	var entries_any: Variant = safe.get("entries", {})
	if not (entries_any is Dictionary):
		safe["entries"] = {}
		return safe
	var entries: Dictionary = entries_any
	var filtered: Dictionary = {}
	for species_key in entries.keys():
		var id_text := str(species_key).strip_edges()
		if not id_text.is_valid_int():
			continue
		var species_id := int(id_text)
		if species_id <= 0:
			continue
		if DatabaseService.get_pokemon(species_id) == null:
			push_warning("GameStateService.load_game: species_id=%d no existe en DB; se ignora entrada de Pokédex." % species_id)
			continue
		var value_any: Variant = entries.get(species_key, {})
		if not (value_any is Dictionary):
			continue
		filtered[id_text] = value_any
	safe["entries"] = filtered
	return safe


func _variant_to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _vector2i_to_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}


func _vector2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


func _variant_to_vector2i(value: Variant, default_value: Vector2i = Vector2i.ZERO) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		var v2: Vector2 = value
		return Vector2i(int(v2.x), int(v2.y))
	if value is Dictionary:
		var d: Dictionary = value
		return Vector2i(int(d.get("x", default_value.x)), int(d.get("y", default_value.y)))
	return default_value


func _variant_to_vector2(value: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		var v2i: Vector2i = value
		return Vector2(float(v2i.x), float(v2i.y))
	if value is Dictionary:
		var d: Dictionary = value
		return Vector2(float(d.get("x", default_value.x)), float(d.get("y", default_value.y)))
	return default_value

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
	summary += "Party Pokémon: %d\n" % get_party().count()
	summary += "Pokédex vistos: %d\n" % get_pokedex().get_seen_count()
	summary += "Pokédex capturados: %d\n" % get_pokedex().get_caught_count()
	return summary
