extends Node
class_name TileEffectSystem


## Sistema coordinador de efectos visuales de terreno
## Delega en handlers específicos según el tipo de terreno
##
## Este sistema escucha step_finished del jugador y NPCs, y coordina
## la ejecución de efectos visuales según el tipo de terreno del tile.
## La lógica específica de cada efecto está en handlers especializados.

signal tile_effect_triggered(tile_pos: Vector2i, encounter_type: String, actor: Node2D)

var context: OverworldContext = null
var world_system: WorldSystem = null

# Registro de handlers por tipo de terreno
var effect_handlers: Dictionary = {}  # {String: TileEffectHandler}

# Configuración de escenas (se pasan a los handlers)
@export var grass_effect_scene: PackedScene
@export var tall_grass_overlay_scene: PackedScene
@export var grass_stepped_effect_scene: PackedScene
@export var ripple_effect_scene: PackedScene
@export var exit_arrow_scene: PackedScene
# Futuro: @export var sand_footprint_scene: PackedScene

# Estado temporal para detectar colisiones
var _tile_before_step: Vector2i = Vector2i(-9999, -9999)

# Registro de chunks activos para detectar cambios
var _previous_active_chunks: Array[String] = []


func _ready() -> void:
	# Intentar conectar al jugador si ya existe
	call_deferred("_connect_to_player")


## Inicializa el sistema con el contexto
func initialize(overworld_context: OverworldContext) -> void:
	context = overworld_context
	world_system = context.get_world_system()

	# Registrar handlers
	_register_effect_handlers()

	# Conectar a señales del jugador
	_connect_to_player()

	# Conectar también a NPCs/Events activos (deferred para asegurar que estén listos)
	call_deferred("_connect_to_active_actors")

	# Conectar a cambios de chunks para conectar/desconectar eventos dinámicamente
	_connect_to_chunk_system()

	# Conectar a señales de warp para limpiar efectos cuando termina el warp
	_connect_to_warp_signals()


## Registra todos los handlers de efectos
func _register_effect_handlers() -> void:
	var grass_handler = GrassEffectHandler.new(self)
	grass_handler.setup_effects(grass_effect_scene, tall_grass_overlay_scene, grass_stepped_effect_scene)
	effect_handlers["grass"] = grass_handler

	var ripple_handler = RippleEffectHandler.new(self)
	ripple_handler.setup_effects(ripple_effect_scene)
	effect_handlers["water_ripple"] = ripple_handler

	# ReflectionEffectHandler maneja reflejos en agua (comparte "water" con ripple)
	var reflection_handler = ReflectionEffectHandler.new(self)
	effect_handlers["water_reflection"] = reflection_handler

	# ExitArrowEffectHandler maneja la flecha de salida (no está basado en terrain_type)
	var exit_arrow_handler = ExitArrowEffectHandler.new(self)
	if exit_arrow_scene:
		exit_arrow_handler.setup_effects(exit_arrow_scene)
	effect_handlers["exit_arrow"] = exit_arrow_handler


## Obtiene el handler para un tipo de terreno
func get_handler_for_terrain(terrain_type: String) -> TileEffectHandler:
	return effect_handlers.get(terrain_type, null)

## Obtiene la lista de handlers activos para un tile según su información
## @param tile_info: Dictionary con la información del tile (terrain, exit_dir, etc.)
## @param actor: Actor que está interactuando con el tile (para verificar si es Player, etc.)
## @return: Array de TileEffectHandler que deben ejecutarse para este tile
func _get_active_handlers_for_tile(tile_info: Dictionary, actor: Node2D) -> Array[TileEffectHandler]:
	var active_handlers: Array[TileEffectHandler] = []

	# Handlers basados en terrain
	var terrain_type = tile_info.get("terrain", "")
	if terrain_type == "grass":
		active_handlers.append(effect_handlers.get("grass"))

	# Reflection handler siempre se ejecuta (se gestiona internamente según el terreno)
	var has_reflection = tile_info.get("water_reflection", false)
	var reflection_handler: ReflectionEffectHandler = effect_handlers.get("water_reflection", "")
	if has_reflection:
		active_handlers.append(reflection_handler)

	# Reflection handler siempre se ejecuta (se gestiona internamente según el terreno)
	var show_ripple = tile_info.get("water_ripple", false)
	if show_ripple:
		active_handlers.append(effect_handlers.get("water_ripple", "") )

	# Exit arrow handler solo si hay exit_dir y el actor es el jugador
	var exit_dir = tile_info.get("exit_dir", "")
	if not exit_dir.is_empty() and actor.is_in_group("Player"):
		active_handlers.append(effect_handlers.get("exit_arrow"))

	return active_handlers


## Registra un nuevo handler (para extensibilidad)
func register_handler(terrain_type: String, handler: TileEffectHandler) -> void:
	effect_handlers[terrain_type] = handler


## Obtiene el grid y la info del tile en una posición mundial
func _get_tile_info_at_world_pos(world_pos: Vector2) -> Dictionary:
	var result = world_system.find_grid_and_tile_at_world_position(world_pos)
	var grid = result.get("grid")
	var tile = result.get("tile", Vector2i.ZERO)

	if grid:
		return {
			"grid": grid,
			"tile": tile,
			"info": grid.get_tile_info(tile)
		}
	return {
		"grid": null,
		"tile": Vector2i.ZERO,
		"info": {"terrain": "ground", "encounter_type": ""}
	}


## Se ejecuta cuando un actor EMPIEZA un paso
func _on_actor_step_started(actor: Node2D) -> void:
	var active_grid = world_system.get_active_grid()
	if not active_grid:
		return

	_tile_before_step = active_grid.world_to_tile(actor.global_position)
	var grid_motion = actor.get_node_or_null("GridMotion")
	if not grid_motion or grid_motion.initial_step:
		return

	var destination_tile = _tile_before_step + Vector2i(grid_motion.dir)
	if not active_grid.can_step_to(actor, _tile_before_step, destination_tile):
		return

	# Obtener info del tile actual (puede estar en otro mapa)
	var from_data = _get_tile_info_at_world_pos(actor.global_position)

	# Obtener info del tile destino
	var dest_world_pos = active_grid.tile_to_world_center(destination_tile)
	var to_data = _get_tile_info_at_world_pos(dest_world_pos)

	# Obtener handlers activos para el tile de origen y ejecutar on_step_exited_tile
	if from_data.grid:
		var active_handlers = _get_active_handlers_for_tile(from_data.info, actor)
		for handler in active_handlers:
			handler.on_step_exited_tile(from_data.grid, from_data.tile, actor)

	# Manejar entrada al tile destino
	if to_data.grid:
		_handle_movement_to_destination(to_data.grid, to_data.tile, actor)


## Se ejecuta cuando un actor TERMINA un paso
func _on_actor_step_finished(tile: Vector2i, actor: Node2D) -> void:
	# Obtener el grid correcto según el tipo de actor
	var grid: OverworldGrid = null
	if actor.is_in_group("Player"):
		grid = world_system.get_active_grid()
	elif actor is Event:
		var occupancy := actor.get_node_or_null("Occupancy")
		if occupancy and occupancy.home_grid:
			grid = occupancy.home_grid

	if not grid:
		return

	var tile_info = grid.get_tile_info(tile)
	var grid_motion = actor.get_node("GridMotion")
	var had_collision = (tile == _tile_before_step) and not grid_motion.initial_step

	# Obtener handlers activos para este tile y ejecutarlos
	var active_handlers = _get_active_handlers_for_tile(tile_info, actor)
	for handler in active_handlers:
		handler.on_step_finished_on_tile(grid, tile, actor, had_collision)

	# Emitir señal de efecto de tile si hay encounter_type
	if not tile_info.encounter_type.is_empty() and actor.is_in_group("Player"):
		tile_effect_triggered.emit(tile, tile_info.encounter_type, actor)


## Maneja el movimiento hacia un tile de destino
func _handle_movement_to_destination(grid: OverworldGrid, destination_tile: Vector2i, actor: Node2D) -> void:
	var tile_info = grid.get_tile_info(destination_tile)

	# Obtener handlers activos para el tile destino y ejecutarlos
	var active_handlers = _get_active_handlers_for_tile(tile_info, actor)
	for handler in active_handlers:
		handler.on_step_started_to_tile(grid, destination_tile, actor)



## Limpia el estado de todos los handlers
func _clear_all_handlers(actor: Node2D) -> void:
	var tile_data = _get_tile_info_at_world_pos(actor.global_position)
	if tile_data.grid:
		for handler in effect_handlers.values():
			if handler:
				handler.clear_state()


## Conecta a las señales del jugador
func _connect_to_player() -> void:
	if not context:
		await get_tree().process_frame
		_connect_to_player()
		return

	var player = context.get_player()
	if not player:
		await get_tree().process_frame
		_connect_to_player()
		return

	_connect_to_actor(player)

## Conecta a las señales de un actor (player o NPC/Event)
func _connect_to_actor(actor: Node2D) -> void:
	var grid_motion = actor.get_node_or_null("GridMotion")
	if not grid_motion:
		return

	# Verificar si ya está conectado
	if grid_motion.step_finished.is_connected(_on_actor_step_finished):
		return

	grid_motion.step_finished.connect(_on_actor_step_finished.bind(actor))
	grid_motion.step_started.connect(_on_actor_step_started.bind(actor))

	# Verificar reflejo inicial si el actor ya está posicionado
	var reflection_handler: ReflectionEffectHandler = effect_handlers.get("water_reflection", null)
	if reflection_handler:
		reflection_handler.check_initial_reflection(actor)

## Conecta a todos los NPCs/Events activos en el grid activo
func _connect_to_active_actors() -> void:
	if not world_system:
		return

	var active_grid = world_system.get_active_grid()
	if not active_grid:
		return

	# Buscar el contenedor "Events" directamente
	var events_container = active_grid.get_node_or_null("Events")
	if events_container:
		# Buscar todos los eventos en el contenedor
		for child in events_container.get_children():
			if child is Event:
				var event = child as Event
				# Verificar que tenga GridMotion antes de conectar
				if event.get_node_or_null("GridMotion"):
					_connect_to_actor(event)
	else:
		# Fallback: buscar recursivamente si no hay contenedor "Events"
		_connect_to_events_in_node(active_grid)

## Busca eventos recursivamente en un nodo y los conecta (fallback)
func _connect_to_events_in_node(node: Node) -> void:
	# Si es un Event con GridMotion, conectarlo
	if node is Event:
		var event = node as Event
		if event.get_node_or_null("GridMotion"):
			_connect_to_actor(event)

	# Buscar recursivamente en hijos
	for child in node.get_children():
		_connect_to_events_in_node(child)

## Conecta al sistema de chunks para conectar/desconectar eventos dinámicamente
func _connect_to_chunk_system() -> void:
	if not world_system:
		return

	var chunk_controller = world_system.get_node_or_null("WorldChunkController")
	if not chunk_controller:
		return

	# Conectar a la señal de cambio de chunks
	if not chunk_controller.chunk_changed.is_connected(_on_chunks_changed):
		chunk_controller.chunk_changed.connect(_on_chunks_changed)

	# Inicializar con los chunks activos actuales
	_previous_active_chunks = chunk_controller._cached_active_chunks.duplicate()

	# Conectar eventos de los chunks ya activos
	for chunk_id in _previous_active_chunks:
		var chunk_data = chunk_controller.chunk_registry.get(chunk_id)
		if chunk_data:
			_connect_chunk_events(chunk_data)

## Callback cuando cambian los chunks activos
func _on_chunks_changed(new_active_chunks: Array[String]) -> void:
	if not world_system:
		return

	var chunk_controller = world_system.get_node_or_null("WorldChunkController")
	if not chunk_controller:
		return

	# Desconectar eventos de chunks que se desactivaron
	for chunk_id in _previous_active_chunks:
		if not new_active_chunks.has(chunk_id):
			var chunk_data = chunk_controller.chunk_registry.get(chunk_id)
			if chunk_data:
				_disconnect_chunk_events(chunk_data)

	# Conectar eventos de chunks que se activaron
	for chunk_id in new_active_chunks:
		if not _previous_active_chunks.has(chunk_id):
			var chunk_data = chunk_controller.chunk_registry.get(chunk_id)
			if chunk_data:
				_connect_chunk_events(chunk_data)

	# Actualizar registro
	_previous_active_chunks = new_active_chunks.duplicate()

## Conecta eventos de un chunk
func _connect_chunk_events(chunk_data) -> void:
	for event_ref in chunk_data.event_refs:
		var event = event_ref.get_ref()
		if event and is_instance_valid(event):
			if event.get_node_or_null("GridMotion"):
				_connect_to_actor(event)

## Desconecta eventos de un chunk
func _disconnect_chunk_events(chunk_data) -> void:
	for event_ref in chunk_data.event_refs:
		var event = event_ref.get_ref()
		if event and is_instance_valid(event):
			_disconnect_from_actor(event)

## Desconecta de las señales de un actor
func _disconnect_from_actor(actor: Node2D) -> void:
	var grid_motion = actor.get_node_or_null("GridMotion")
	if not grid_motion:
		return

	# Desconectar señales si están conectadas
	if grid_motion.step_finished.is_connected(_on_actor_step_finished):
		grid_motion.step_finished.disconnect(_on_actor_step_finished)
	if grid_motion.step_started.is_connected(_on_actor_step_started):
		grid_motion.step_started.disconnect(_on_actor_step_started)

	# Llamar a deactivate_actor en todos los handlers para que limpien su estado
	for handler in effect_handlers.values():
		if handler and handler.has_method("deactivate_actor"):
			handler.deactivate_actor(actor)


## Agrega un efecto a la escena (método helper compartido)
## Añade el efecto a OverworldEffectsLayer si está disponible
func _add_effect_to_scene(effect: Node2D) -> void:
	if not context:
		push_error("TileEffectSystem: Contexto no disponible, no se puede añadir efecto")
		effect.queue_free()
		return

	var effects_layer = context.get_effects_layer()
	if not effects_layer:
		push_error("TileEffectSystem: OverworldEffectsLayer no disponible, no se puede añadir efecto")
		effect.queue_free()
		return

	effects_layer.add_child(effect)


## Limpia todos los efectos visuales del OverworldEffectsLayer
## Útil para limpiar efectos al cambiar de mapa o realizar warps
func clear_all_effects() -> void:
	if not context:
		return

	var effects_layer = context.get_effects_layer()
	if not effects_layer:
		return

	# Eliminar todos los nodos hijos del OverworldEffectsLayer
	var children = effects_layer.get_children()
	for child in children:
		if is_instance_valid(child):
			child.queue_free()

	# También limpiar el estado de todos los handlers
	for handler in effect_handlers.values():
		if handler and handler.has_method("clear_state"):
			handler.clear_state()


## Conecta a señales de warp para limpiar efectos al cambiar de mapa
func _connect_to_warp_signals() -> void:
	if not context:
		return

	# Conectar a warp_finished para limpiar efectos cuando termina el warp
	if not context.warp_finished.is_connected(_on_warp_finished):
		context.warp_finished.connect(_on_warp_finished)


## Callback cuando termina un warp
func _on_warp_finished(_map_id: String, _tile_pos: Vector2i) -> void:
	# Limpiar todos los efectos visuales cuando termina el warp (nuevo mapa cargado)
	clear_all_effects()
