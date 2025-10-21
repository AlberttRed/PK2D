extends Node
class_name WildEncounterDetector
## Sistema de detección de encuentros salvajes en el Overworld.
## Detecta cuando el jugador pisa tiles con encounter_type y genera combates.
##
## Este nodo debe ser hijo del Player y se conecta automáticamente a GridMotion.
##
## OPTIMIZACIÓN: La señal step_finished se conecta/desconecta dinámicamente según si el mapa
## tiene encuentros configurados. En mapas sin encuentros, la señal está desconectada por completo,
## eliminando cualquier procesamiento innecesario.

## Escena del efecto visual de hierba
@export var grass_effect_scene: PackedScene

## Flag para deshabilitar encuentros (útil para debug o eventos especiales)
@export var encounters_enabled: bool = true

@onready var player: Node2D = get_parent()
var grid_motion: GridMotion
var map_system: MapSystem

## Cache del MapAreaEncounters del mapa actual (optimización)
var current_map_encounters: MapAreaEncounters = null
var current_map_name: String = ""

## Flag para controlar si la señal está conectada (optimización)
var _signal_connected: bool = false


func _ready() -> void:
	# Obtener GridMotion del padre (Player)
	grid_motion = player.get_node_or_null("GridMotion")
	if not grid_motion:
		push_error("WildEncounterDetector: No se encontró GridMotion en el Player")
		return
	
	# Obtener MapSystem
	map_system = get_tree().get_first_node_in_group("MapSystem")
	if not map_system:
		push_warning("WildEncounterDetector: MapSystem no encontrado")
	
	# Conectar a cambios de mapa para actualizar cache y señal
	SignalManager.seamless_map_crossed.connect(_on_map_changed)
	SignalManager.warp_finished.connect(_on_map_changed_warp)
	
	# Inicializar cache y conectar/desconectar señal según corresponda
	_update_encounters_cache()
	
	print("WildEncounterDetector: Sistema de encuentros inicializado")


## Se ejecuta cuando el jugador termina un paso
## NOTA: Esta función solo se ejecuta si el mapa tiene encuentros configurados
func _on_step_finished(tile: Vector2i) -> void:
	if not encounters_enabled:
		return
	
	# Obtener el grid activo
	if not map_system:
		return
	
	var active_grid: OverworldGrid = map_system.get_active_grid()
	if not active_grid:
		return
	
	# Obtener el tipo de encuentro del tile
	var encounter_type: Variant = _get_encounter_type_from_tile(active_grid, tile)
	if encounter_type == null:
		return  # Este tile no tiene encuentros
	
	# Verificar si este tipo de área tiene encuentros configurados
	if not current_map_encounters.has_encounters_for_area(encounter_type):
		return  # Este tipo de área no tiene encuentros configurados
	
	# Mostrar efecto visual si es hierba
	if encounter_type == EncounterAreaTypeEnum.Values.LAND:
		_show_grass_effect(active_grid, tile)
	
	# Intentar generar un encuentro salvaje
	_try_trigger_encounter(encounter_type)


## Obtiene el tipo de encuentro desde los custom_data del tile
func _get_encounter_type_from_tile(grid: OverworldGrid, tile: Vector2i) -> Variant:
	var tile_data_array := grid.get_tile_data(tile)
	if tile_data_array.is_empty():
		return null
	
	# Buscar en todas las capas del tile
	for tile_data in tile_data_array:
		if tile_data == null:
			continue
		
		# Intentar obtener el custom_data "encounter_type"
		var encounter_type_str: Variant = tile_data.get_custom_data("encounter_type")
		
		if encounter_type_str is String and not encounter_type_str.is_empty():
			# Convertir string a enum
			return EncounterAreaTypeEnum.parse_type(encounter_type_str)
	
	return null


## Muestra el efecto visual de hierba en el tile
func _show_grass_effect(grid: OverworldGrid, tile: Vector2i) -> void:
	if not grass_effect_scene:
		return
	
	# Instanciar el efecto
	var effect: Node2D = grass_effect_scene.instantiate()
	
	# Posicionar en el tile
	var world_pos := grid.tile_to_world_center(tile)
	effect.global_position = world_pos
	
	# Agregar al mapa (no al player, para que no se mueva con él)
	var current_map = grid.get_parent()
	if current_map:
		current_map.add_child(effect)
	else:
		# Fallback: agregar al root
		get_tree().root.add_child(effect)


## Intenta generar un encuentro salvaje
func _try_trigger_encounter(encounter_type: EncounterAreaTypeEnum.Values) -> void:
	# Usar el cache de encuentros (ya verificado que existe)
	if not current_map_encounters:
		return  # No hay encuentros configurados en este mapa
	
	# Intentar generar un encuentro
	var encounter_data := current_map_encounters.try_wild_encounter(encounter_type)
	
	if encounter_data.is_empty():
		return  # No hubo encuentro esta vez
	
	# Hay un encuentro, generar el combate
	print("WildEncounterDetector: ¡Encuentro salvaje!")
	print("  Pokémon: %d, Nivel: %d" % [encounter_data["pokemon_id"], encounter_data["level"]])
	
	_start_wild_battle(encounter_data)


## Actualiza el cache de MapAreaEncounters del mapa actual
## Y conecta/desconecta la señal según corresponda
func _update_encounters_cache() -> void:
	current_map_encounters = null
	current_map_name = ""
	
	if not map_system:
		_disconnect_signal()
		return
	
	var active_grid := map_system.get_active_grid()
	if not active_grid:
		_disconnect_signal()
		return
	
	# MapAreaEncounters debería estar en el mapa (padre del grid)
	var current_map = active_grid.get_parent()
	if not current_map:
		_disconnect_signal()
		return
	
	current_map_name = current_map.name
	
	# Buscar MapAreaEncounters en el mapa
	var encounters_node = current_map.get_node_or_null("MapAreaEncounters")
	if encounters_node and encounters_node is MapAreaEncounters:
		current_map_encounters = encounters_node
		_connect_signal()
		print("WildEncounterDetector: Mapa '%s' → CON encuentros (señal CONECTADA)" % current_map_name)
		return
	
	# Buscar recursivamente
	for child in current_map.get_children():
		if child is MapAreaEncounters:
			current_map_encounters = child
			_connect_signal()
			print("WildEncounterDetector: Mapa '%s' → CON encuentros (señal CONECTADA)" % current_map_name)
			return
	
	# No se encontraron encuentros → desconectar señal
	_disconnect_signal()
	print("WildEncounterDetector: Mapa '%s' → SIN encuentros (señal DESCONECTADA)" % current_map_name)


## Conecta la señal step_finished si no está conectada
func _connect_signal() -> void:
	if _signal_connected or not grid_motion:
		return
	
	grid_motion.step_finished.connect(_on_step_finished)
	_signal_connected = true


## Desconecta la señal step_finished si está conectada
func _disconnect_signal() -> void:
	if not _signal_connected or not grid_motion:
		return
	
	grid_motion.step_finished.disconnect(_on_step_finished)
	_signal_connected = false


## Callback cuando se cambia de mapa (seamless)
func _on_map_changed(_from_map: String, _to_map: String) -> void:
	_update_encounters_cache()


## Callback cuando se hace warp
func _on_map_changed_warp(_map_id: String, _spawn_id: String) -> void:
	_update_encounters_cache()


## Inicia un combate salvaje
func _start_wild_battle(encounter_data: Dictionary) -> void:
	# Crear un Pokémon salvaje
	var wild_pokemon_instance := _create_wild_pokemon(encounter_data["pokemon_id"], encounter_data["level"])
	if not wild_pokemon_instance:
		push_error("WildEncounterDetector: No se pudo crear el Pokémon salvaje")
		return
	
	# Crear participante salvaje
	var wild_participant := BattleParticipantWild.new([wild_pokemon_instance.to_battle_pokemon()])
	
	# Obtener participante del jugador
	var player_participant := _get_player_participant()
	if not player_participant:
		push_error("WildEncounterDetector: No se pudo obtener el participante del jugador")
		return
	
	# Crear reglas de batalla
	var rules := BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE
	)
	
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	
	# Iniciar combate (GUI se encargará de bloquear/desbloquear el control)
	print("WildEncounterDetector: Solicitando combate salvaje...")
	SignalManager.battle_requested.emit(participants, rules)
	
	# Esperar a que termine el combate
	await SignalManager.battle_finished
	print("WildEncounterDetector: Combate terminado")


## Obtiene el BattleParticipant del jugador
func _get_player_participant() -> BattleParticipant:
	# OPCIÓN 1: Si el Player tiene un nodo Battler hijo, usarlo
	var battler = player.get_node_or_null("Battler")
	if battler and battler is Battler:
		if battler.can_battle():
			return battler.to_battle_participant()
		else:
			push_error("WildEncounterDetector: El jugador no tiene Pokémon vivos")
			return null
	
	# OPCIÓN 2: Usar GameStateManager (fallback para sistemas antiguos)
	var player_team: Array = GameStateManager.get_player_party()
	if player_team.is_empty():
		push_error("WildEncounterDetector: El jugador no tiene Pokémon en el party")
		return null
	
	# Convertir equipo a BattlePokemon
	var battle_team: Array[BattlePokemon] = []
	for pokemon_instance in player_team:
		if pokemon_instance is PokemonInstance:
			var battle_pkmn: BattlePokemon = pokemon_instance.to_battle_pokemon()
			battle_team.append(battle_pkmn)
	
	# Crear participante manual
	var participant := BattleParticipant.new(battle_team)
	participant.name = "Player"  # TODO: Obtener del GameState
	participant.is_player = true
	
	return participant

## Crea un Pokémon salvaje
func _create_wild_pokemon(pokemon_id: int, level: int) -> PokemonInstance:
	
	var pokemon = PokemonInstance.new().create(true, pokemon_id, level)
	pokemon.is_wild = true
	return pokemon

## Habilita o deshabilita los encuentros
func set_encounters_enabled(enabled: bool) -> void:
	encounters_enabled = enabled
	
	# Si se deshabilitan, desconectar señal
	# Si se habilitan, reconectar si el mapa tiene encuentros
	if enabled:
		if current_map_encounters != null:
			_connect_signal()
			print("WildEncounterDetector: Encuentros habilitados (señal CONECTADA)")
		else:
			print("WildEncounterDetector: Encuentros habilitados (pero mapa sin encuentros)")
	else:
		_disconnect_signal()
		print("WildEncounterDetector: Encuentros deshabilitados (señal DESCONECTADA)")


## Verifica si el mapa actual tiene encuentros configurados
func has_encounters_in_current_map() -> bool:
	return current_map_encounters != null


## Obtiene el nombre del mapa actual
func get_current_map_name() -> String:
	return current_map_name


## Obtiene información de debug del mapa actual
func get_current_map_debug_info() -> String:
	if not current_map_encounters:
		return "Mapa actual '%s': SIN encuentros configurados" % current_map_name
	
	var info := "Mapa actual '%s':\n" % current_map_name
	info += current_map_encounters.get_debug_info()
	return info
