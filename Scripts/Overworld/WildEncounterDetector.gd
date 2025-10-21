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
var map_system: MapSystem

## Cache del MapAreaEncounters del mapa actual (optimización)
var current_map_encounters: MapAreaEncounters = null
var current_map_name: String = ""

## Flag para controlar si la señal está conectada (optimización)
var _signal_connected: bool = false

## Referencia al overlay de hierba alta activo (si el player está en hierba)
var _active_tall_grass_overlay: Sprite2D = null

## Último tile donde se mostró el GrassEffect (para evitar repetir en el mismo tile)
var _last_grass_effect_tile: Vector2i = Vector2i(-9999, -9999)

## Último tile donde hay un overlay activo
var _last_overlay_tile: Vector2i = Vector2i(-9999, -9999)

## Tile donde estaba el player al empezar el step (para detectar colisiones)
var _tile_before_step: Vector2i = Vector2i(-9999, -9999)


func _ready() -> void:
	# Obtener GridMotion del padre (Player)
	grid_motion = player.get_node_or_null("GridMotion")
	if not grid_motion:
		push_error("WildEncounterDetector: No se encontró GridMotion en el Player")
		return
	
	# Conectar a step_started para destruir overlay cuando se mueve a otro tile
	grid_motion.step_started.connect(_on_step_started)
	
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


## Se ejecuta cuando el jugador EMPIEZA un paso (antes de moverse)
func _on_step_started() -> void:
	# Guardar el tile actual para detectar colisiones en step_finished
	if not map_system:
		return
	
	var active_grid: OverworldGrid = map_system.get_active_grid()
	if not active_grid:
		return
	
	_tile_before_step = active_grid.world_to_tile(player.global_position)
	
	# Solo destruir/crear overlay si NO es first step
	if not grid_motion.initial_step:
		# Calcular el tile de destino
		var direction: Vector2 = grid_motion.dir
		var destination_tile: Vector2i = _tile_before_step + Vector2i(int(direction.x), int(direction.y))
		
		# Verificar si podemos movernos al tile de destino
		var can_move: bool = active_grid.can_step_to(player, _tile_before_step, destination_tile)
		
		if can_move:
			# Podemos movernos: destruir overlay anterior
			_hide_tall_grass_overlay()
			_last_overlay_tile = Vector2i(-9999, -9999)
			
			# Verificar si el tile de destino es de hierba
			var encounter_type: Variant = _get_encounter_type_from_tile(active_grid, destination_tile)
			
			if encounter_type == EncounterAreaTypeEnum.Values.LAND:
				# Tile de destino es hierba: crear efectos en la posición de destino
				var destination_world_pos: Vector2 = active_grid.tile_to_world_center(destination_tile)
				
				# Crear efecto de hierba "aplastada" (debajo del player, se autodestruye)
				_show_grass_stepped_effect(active_grid, destination_tile)
				
				# Crear overlay con z_index bajo (0) para que el player quede delante durante el movimiento
				_show_tall_grass_overlay_at_position(destination_world_pos, 0)
				_last_overlay_tile = destination_tile
		# Si NO podemos movernos (colisión): mantener overlay existente
	# Si es first step (giro en sitio): mantener overlay existente


## Se ejecuta cuando el jugador termina un paso
## NOTA: Esta función solo se ejecuta si el mapa tiene encuentros configurados
func _on_step_finished(tile: Vector2i) -> void:
	
	# Obtener el grid activo
	if not map_system:
		return
	
	var active_grid: OverworldGrid = map_system.get_active_grid()
	if not active_grid:
		return
	
	# Detectar si hubo colisión (no nos movimos realmente)
	var had_collision: bool = (tile == _tile_before_step) and not grid_motion.initial_step
	
	# Obtener el tipo de encuentro del tile
	var encounter_type: Variant = _get_encounter_type_from_tile(active_grid, tile)
	
	# Determinar si estamos en un tile de hierba
	var is_grass_tile: bool = encounter_type == EncounterAreaTypeEnum.Values.LAND
	var was_on_different_tile: bool = tile != _last_grass_effect_tile
	
	# Manejar efectos visuales de hierba
	if is_grass_tile:
		# Si hubo colisión, el overlay ya existe (no se destruyó en step_started)
		if had_collision:
			# Colisión: solo asegurar que el overlay tenga z_index correcto
			if _active_tall_grass_overlay != null and is_instance_valid(_active_tall_grass_overlay):
				_active_tall_grass_overlay.z_index = 5
			else:
				# Por alguna razón no hay overlay: recrear
				var current_world_pos: Vector2 = active_grid.tile_to_world_center(tile)
				_show_tall_grass_overlay_at_position(current_world_pos, 5)
				_last_overlay_tile = tile
		else:
			# No hubo colisión: movimiento normal o first step
			# Solo mostrar GrassEffect si es un NUEVO tile (no repetir en el mismo)
			if was_on_different_tile:
				_show_grass_effect(active_grid, tile)
				_last_grass_effect_tile = tile
			
			# Gestionar overlay
			if _active_tall_grass_overlay != null and is_instance_valid(_active_tall_grass_overlay):
				# El overlay existe: verificar si está en la posición correcta
				var current_world_pos: Vector2 = active_grid.tile_to_world_center(tile)
				if _active_tall_grass_overlay.global_position.distance_to(current_world_pos) > 1.0:
					# Overlay está en posición incorrecta
					# Destruir y recrear en posición correcta
					_hide_tall_grass_overlay()
					_show_tall_grass_overlay_at_position(current_world_pos, 5)
					_last_overlay_tile = tile
				else:
					# Overlay en posición correcta: solo subir z_index
					_active_tall_grass_overlay.z_index = 5
			else:
				# No hay overlay: crear en la posición actual
				var current_world_pos: Vector2 = active_grid.tile_to_world_center(tile)
				_show_tall_grass_overlay_at_position(current_world_pos, 5)
				_last_overlay_tile = tile
	else:
		# Si NO estamos en hierba, destruir overlay y resetear variables
		_hide_tall_grass_overlay()
		_last_grass_effect_tile = Vector2i(-9999, -9999)
		_last_overlay_tile = Vector2i(-9999, -9999)
	
	# Si no hay encuentros configurados, no intentar batalla
	if encounter_type == null or not encounters_enabled:
		return

	# Verificar si este tipo de área tiene encuentros configurados
	if not current_map_encounters.has_encounters_for_area(encounter_type):
		return
	
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


## Muestra el efecto visual de hierba en el tile (animación corta)
func _show_grass_effect(_grid: OverworldGrid, _tile: Vector2i) -> void:
	if not grass_effect_scene:
		return
	
	# Instanciar el efecto
	var effect: Node2D = grass_effect_scene.instantiate()
	
	# Posicionar en la posición actual del player (mismo tile)
	effect.global_position = player.global_position
	
	# Agregar como hermano del player (mismo padre)
	# Así comparten sistema de coordenadas y se ve correctamente
	var player_parent = player.get_parent()
	if player_parent:
		player_parent.add_child(effect)
	else:
		# Fallback: agregar al root
		get_tree().root.add_child(effect)


## Muestra el efecto de hierba "aplastada" en un tile específico (se autodestruye)
func _show_grass_stepped_effect(grid: OverworldGrid, tile: Vector2i) -> void:
	if not grass_stepped_effect_scene:
		return
	
	# Instanciar el efecto
	var effect: AnimatedSprite2D = grass_stepped_effect_scene.instantiate()
	
	# Posicionar en el tile especificado
	effect.global_position = grid.tile_to_world_center(tile)
	
	# Agregar como hermano del player (mismo padre)
	# z_index = 0 (definido en la escena) para quedar debajo del player
	var player_parent = player.get_parent()
	if player_parent:
		player_parent.add_child(effect)
	else:
		# Fallback: agregar al root
		get_tree().root.add_child(effect)


## Muestra el overlay de hierba alta en una posición específica
func _show_tall_grass_overlay_at_position(world_position: Vector2, z_idx: int = 5) -> void:
	# Si ya existe, no crear otro
	if _active_tall_grass_overlay != null and is_instance_valid(_active_tall_grass_overlay):
		return
	
	if not tall_grass_overlay_scene:
		return
	
	# Instanciar el overlay
	var overlay: Sprite2D = tall_grass_overlay_scene.instantiate()
	
	# IMPORTANTE: Posicionar en la posición especificada
	# El overlay se queda en esta posición (no sigue al player)
	overlay.global_position = world_position
	
	# Configurar z_index
	overlay.z_index = z_idx
	
	# Agregar como hermano del player (mismo padre)
	var player_parent = player.get_parent()
	if player_parent:
		player_parent.add_child(overlay)
		_active_tall_grass_overlay = overlay
	else:
		# Fallback: agregar al root
		get_tree().root.add_child(overlay)
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
func _on_map_changed(from_map: String, _to_map: String) -> void:
	# Solo limpiar si REALMENTE cambiamos de mapa (no solo al mirar hacia otro mapa)
	if from_map != current_map_name:
		# El mapa cambió realmente: limpiar overlay
		_hide_tall_grass_overlay()
		# Resetear el último tile de hierba al cambiar de mapa
		_last_grass_effect_tile = Vector2i(-9999, -9999)
		_last_overlay_tile = Vector2i(-9999, -9999)
	
	# Actualizar cache de encuentros (siempre, incluso si solo cargamos vecino)
	_update_encounters_cache()


## Callback cuando se hace warp
func _on_map_changed_warp(_map_id: String, _spawn_id: String) -> void:
	# Limpiar overlay al hacer warp
	_hide_tall_grass_overlay()
	# Resetear el último tile de hierba al cambiar de mapa
	_last_grass_effect_tile = Vector2i(-9999, -9999)
	_last_overlay_tile = Vector2i(-9999, -9999)
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
