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

## Tile inválido usado para resetear estado
const INVALID_TILE := Vector2i(-9999, -9999)
const OVERLAY_Z_LOW := 0  # Durante movimiento (player delante)
const OVERLAY_Z_HIGH := 5  # Al llegar (player debajo)

## Escena del efecto visual de hierba (animación corta al pisar)
@export var grass_effect_scene: PackedScene

## Escena del overlay de hierba alta (imagen que cubre al player mientras está en hierba)
@export var tall_grass_overlay_scene: PackedScene

## Escena del efecto de hierba "aplastada" (animación de 2 frames que se autodestruye)
@export var grass_stepped_effect_scene: PackedScene

## Flag para deshabilitar encuentros (útil para debug o eventos especiales)
@export var encounters_enabled: bool = true

@onready var player: Node2D = get_parent()
var grid_motion: GridMotion
var world_system: WorldSystem
var context: OverworldContext = null

## Cache del MapAreaEncounters del mapa actual (optimización)
var current_map_encounters: MapAreaEncounters = null
var current_map_name: String = ""

## Flag para controlar si la señal está conectada (optimización)
var _signal_connected: bool = false

## Referencia al overlay de hierba alta activo (si el player está en hierba)
var _active_tall_grass_overlay: Sprite2D = null

## Último tile donde se mostró el GrassEffect (para evitar repetir en el mismo tile)
var _last_grass_effect_tile: Vector2i = INVALID_TILE

## Último tile donde hay un overlay activo
var _last_overlay_tile: Vector2i = INVALID_TILE

## Tile donde estaba el player al empezar el step (para detectar colisiones)
var _tile_before_step: Vector2i = INVALID_TILE


func _ready() -> void:
	# Obtener GridMotion del padre (Player)
	grid_motion = player.get_node_or_null("GridMotion")
	if not grid_motion:
		push_error("WildEncounterDetector: No se encontró GridMotion en el Player")
		return

	# Conectar a step_started para destruir overlay cuando se mueve a otro tile
	grid_motion.step_started.connect(_on_step_started)

	# MapSystem se obtendrá del contexto cuando esté disponible

	# Inicializar cache y conectar/desconectar señal según corresponda
	_update_encounters_cache()

	print("WildEncounterDetector: Sistema de encuentros inicializado")


## Se ejecuta cuando el jugador EMPIEZA un paso (antes de moverse)
func _on_step_started() -> void:
	var active_grid := _get_active_grid()
	if not active_grid:
		return

	_tile_before_step = active_grid.world_to_tile(player.global_position)

	# Solo manejar overlay si NO es first step (en first step se mantiene)
	if not grid_motion.initial_step:
		var destination_tile := _tile_before_step + Vector2i(grid_motion.dir)
		var can_move := active_grid.can_step_to(player, _tile_before_step, destination_tile)

		if can_move:
			_handle_movement_to_destination(active_grid, destination_tile)


## Se ejecuta cuando el jugador termina un paso
## NOTA: Esta función solo se ejecuta si el mapa tiene encuentros configurados
func _on_step_finished(tile: Vector2i) -> void:
	var active_grid := _get_active_grid()
	if not active_grid:
		return

	var encounter_type: Variant = _get_encounter_type_from_tile(active_grid, tile)
	var is_grass_tile: bool = encounter_type == EncounterAreaTypeEnum.Values.LAND
	var had_collision: bool = (tile == _tile_before_step) and not grid_motion.initial_step

	# Manejar efectos visuales de hierba
	if is_grass_tile:
		_handle_grass_tile_arrival(active_grid, tile, had_collision)
	else:
		_clear_grass_state()

	# Intentar generar encuentro
	if encounter_type and encounters_enabled and current_map_encounters:
		if current_map_encounters.has_encounters_for_area(encounter_type):
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


## Obtiene el grid activo con validación
func _get_active_grid() -> OverworldGrid:
	# Actualizar referencia a WorldSystem si es necesario
	if not world_system and context:
		world_system = context.get_world_system()

	if not world_system:
		return null
	return world_system.get_active_grid()


## Maneja el movimiento hacia un tile de destino (destruye overlay anterior y crea nuevo si es hierba)
func _handle_movement_to_destination(grid: OverworldGrid, destination_tile: Vector2i) -> void:
	_hide_tall_grass_overlay()
	_last_overlay_tile = INVALID_TILE

	var encounter_type: Variant = _get_encounter_type_from_tile(grid, destination_tile)
	if encounter_type == EncounterAreaTypeEnum.Values.LAND:
		var destination_pos := grid.tile_to_world_center(destination_tile)
		_show_grass_stepped_effect(grid, destination_tile)
		_show_tall_grass_overlay_at_position(destination_pos, OVERLAY_Z_LOW)
		_last_overlay_tile = destination_tile


## Maneja la llegada a un tile de hierba (efectos + overlay)
func _handle_grass_tile_arrival(grid: OverworldGrid, tile: Vector2i, had_collision: bool) -> void:
	if had_collision:
		# Colisión: solo ajustar z_index del overlay existente
		_ensure_overlay_z_index(OVERLAY_Z_HIGH)
		if not _active_tall_grass_overlay:
			_ensure_overlay_at_position(grid, tile, OVERLAY_Z_HIGH)
	else:
		# Movimiento normal: mostrar GrassEffect si es tile nuevo
		if tile != _last_grass_effect_tile:
			_show_grass_effect()
			_last_grass_effect_tile = tile

		# Gestionar overlay: verificar posición y ajustar z_index
		_ensure_overlay_at_position(grid, tile, OVERLAY_Z_HIGH)


## Limpia el estado de hierba (overlay y tiles memorizados)
func _clear_grass_state() -> void:
	_hide_tall_grass_overlay()
	_last_grass_effect_tile = INVALID_TILE
	_last_overlay_tile = INVALID_TILE


## Asegura que el overlay esté en la posición correcta con el z_index adecuado
func _ensure_overlay_at_position(grid: OverworldGrid, tile: Vector2i, z_idx: int) -> void:
	var target_pos := grid.tile_to_world_center(tile)

	if _active_tall_grass_overlay and is_instance_valid(_active_tall_grass_overlay):
		# Verificar si está en posición correcta
		if _active_tall_grass_overlay.global_position.distance_to(target_pos) > 1.0:
			_hide_tall_grass_overlay()
			_show_tall_grass_overlay_at_position(target_pos, z_idx)
			_last_overlay_tile = tile
		else:
			_active_tall_grass_overlay.z_index = z_idx
	else:
		_show_tall_grass_overlay_at_position(target_pos, z_idx)
		_last_overlay_tile = tile


## Asegura que el overlay tenga el z_index correcto (si existe)
func _ensure_overlay_z_index(z_idx: int) -> void:
	if _active_tall_grass_overlay and is_instance_valid(_active_tall_grass_overlay):
		_active_tall_grass_overlay.z_index = z_idx


## Agrega un efecto a la escena (como hermano del player)
func _add_effect_to_scene(effect: Node2D) -> void:
	var player_parent := player.get_parent()
	if player_parent:
		player_parent.add_child(effect)
	else:
		get_tree().root.add_child(effect)


## Muestra el efecto visual de hierba en el tile (animación corta)
func _show_grass_effect() -> void:
	if not grass_effect_scene:
		return
	var effect := grass_effect_scene.instantiate() as Node2D
	effect.global_position = player.global_position
	_add_effect_to_scene(effect)


## Muestra el efecto de hierba "aplastada" en un tile específico (se autodestruye)
func _show_grass_stepped_effect(grid: OverworldGrid, tile: Vector2i) -> void:
	if not grass_stepped_effect_scene:
		return
	var effect := grass_stepped_effect_scene.instantiate() as AnimatedSprite2D
	effect.global_position = grid.tile_to_world_center(tile)
	_add_effect_to_scene(effect)


## Muestra el overlay de hierba alta en una posición específica
func _show_tall_grass_overlay_at_position(world_position: Vector2, z_idx: int = OVERLAY_Z_HIGH) -> void:
	if _active_tall_grass_overlay and is_instance_valid(_active_tall_grass_overlay):
		return
	if not tall_grass_overlay_scene:
		return

	var overlay := tall_grass_overlay_scene.instantiate() as Sprite2D
	overlay.global_position = world_position
	overlay.z_index = z_idx
	_add_effect_to_scene(overlay)
	_active_tall_grass_overlay = overlay


## Oculta y destruye el overlay de hierba alta
func _hide_tall_grass_overlay() -> void:
	if _active_tall_grass_overlay != null and is_instance_valid(_active_tall_grass_overlay):
		_active_tall_grass_overlay.queue_free()
		_active_tall_grass_overlay = null


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

	if not world_system:
		_disconnect_signal()
		return

	var active_grid := world_system.get_active_grid()
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
func _on_map_changed(from_map: String, _to_map: String) -> void:
	# Solo limpiar si REALMENTE cambiamos de mapa (no solo al mirar hacia otro mapa)
	if from_map != current_map_name:
		_clear_grass_state()
	_update_encounters_cache()


## Callback cuando se hace warp
func _on_map_changed_warp(_map_id: String, _spawn_id: String) -> void:
	_clear_grass_state()
	_update_encounters_cache()


## Inicia un combate salvaje
func _start_wild_battle(encounter_data: Dictionary) -> void:
	# Crear un Pokémon salvaje
	var wild_pokemon_instance = _create_wild_pokemon(encounter_data["pokemon_id"], encounter_data["level"])  # Pokemon
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

	# Iniciar combate usando DisplayManager
	print("WildEncounterDetector: Solicitando combate salvaje...")
	var winner = await DisplayManager.start_battle(participants, rules)
	print("WildEncounterDetector: Combate terminado. Ganador: %s" % winner)


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

	# OPCIÓN 2: Usar GameStateService (fallback para sistemas antiguos)
	var player_team: Array = GameStateService.get_player_party()
	if player_team.is_empty():
		push_error("WildEncounterDetector: El jugador no tiene Pokémon en el party")
		return null

	# Convertir equipo a BattlePokemon
	var battle_team: Array[BattlePokemon] = []
	for pokemon_instance in player_team:
		if pokemon_instance is Pokemon:
			var battle_pkmn: BattlePokemon = pokemon_instance.to_battle_pokemon()
			battle_team.append(battle_pkmn)

	# Crear participante manual
	var participant := BattleParticipant.new(battle_team)
	participant.name = "Player"  # TODO: Obtener del GameState
	participant.is_player = true

	return participant

## Crea un Pokémon salvaje
func _create_wild_pokemon(pokemon_id: int, level: int):  # return: Pokemon
	var pokemon_data = DatabaseService.get_pokemon(pokemon_id)
	var pokemon = Pokemon.new(
		pokemon_data,  # pokemon_data
		level,         # pokemon_level
		0,             # pokemon_gender (0 = aleatorio)
		0,             # pokemon_ability (0 = aleatorio)
		0,             # pokemon_nature (0 = aleatorio)
		true           # randomize_stats
	)
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

## Establece el contexto del Overworld (llamado desde Player)
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	if context:
		world_system = context.get_world_system()
		# Conectar a las señales locales relevantes
		if not context.seamless_map_crossed.is_connected(_on_map_changed):
			context.seamless_map_crossed.connect(_on_map_changed)
		var warp_sys = context.get_warp_system()
		if warp_sys and not warp_sys.warp_finished.is_connected(_on_map_changed_warp):
			warp_sys.warp_finished.connect(_on_map_changed_warp)
		# Actualizar cache de encuentros tras obtener WorldSystem
		_update_encounters_cache()
