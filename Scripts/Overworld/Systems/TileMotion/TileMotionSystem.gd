extends Node
class_name TileMotionSystem

## Sistema coordinador de movimientos especiales basados en tiles
## Delega en handlers específicos según el tipo de tile
##
## Este sistema intercepta step_started de actores (Player y NPCs/Events) y coordina
## la ejecución de movimientos especiales (ledges, stairs, etc.) según el tipo de tile.
## La lógica específica de cada movimiento está en handlers especializados.

var context: OverworldContext = null
var world_system: WorldSystem = null

# Registro de handlers por tipo de movimiento
var motion_handlers: Dictionary = {}  # {String: TileMotionHandler}

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
	_register_motion_handlers()

	# Conectar a señales del jugador
	_connect_to_player()

	# Conectar también a NPCs/Events activos (deferred para asegurar que estén listos)
	call_deferred("_connect_to_active_actors")

	# Conectar a cambios de chunks para conectar/desconectar eventos dinámicamente
	_connect_to_chunk_system()


## Registra todos los handlers de movimiento
func _register_motion_handlers() -> void:
	var ledge_handler = LedgeMotionHandler.new("ledge", self)
	motion_handlers["ledge"] = ledge_handler


## Obtiene el handler para un tipo de movimiento
func get_handler_for_motion(motion_type: String) -> TileMotionHandler:
	return motion_handlers.get(motion_type, null)


## Obtiene la lista de handlers activos para un tile según su información
## @param tile_info: Dictionary con la información del tile (custom_data, etc.)
## @param actor: Actor que está intentando moverse
## @param direction: Dirección del movimiento
## @param from_tile: Tile de origen
## @param to_tile: Tile de destino
## @return: Array de TileMotionHandler que deben ejecutarse para este movimiento
func _get_active_handlers_for_movement(
	tile_info: Dictionary,
	actor: Node2D,
	direction: Vector2,
	from_tile: Vector2i,
	to_tile: Vector2i
) -> Array[TileMotionHandler]:
	var active_handlers: Array[TileMotionHandler] = []

	# Verificar cada handler registrado
	for handler in motion_handlers.values():
		if handler and handler.can_handle(tile_info, actor, direction, from_tile, to_tile):
			active_handlers.append(handler)

	return active_handlers


## Registra un nuevo handler (para extensibilidad)
func register_handler(motion_type: String, handler: TileMotionHandler) -> void:
	motion_handlers[motion_type] = handler


## Método público que GridMotion puede llamar para verificar si debe interceptar un movimiento
## Retorna true si el movimiento fue consumido por un handler, false si debe continuar con movimiento normal
## Este método es async porque los handlers pueden ejecutar animaciones asíncronas
func try_handle_motion(
	grid: OverworldGrid,
	from_tile: Vector2i,
	to_tile: Vector2i,
	actor: Node2D,
	direction: Vector2
) -> bool:
	# Verificar si el movimiento es válido primero
	if not grid.can_step_to(actor, from_tile, to_tile):
		return false

	# Obtener información del tile destino
	var to_tile_info = grid.get_tile_info(to_tile)

	# Obtener handlers activos para este movimiento
	var active_handlers = _get_active_handlers_for_movement(
		to_tile_info, actor, direction, from_tile, to_tile
	)

	# Si hay handlers activos, darles oportunidad de consumir el movimiento
	for handler in active_handlers:
		# Llamar al handler - puede ejecutar de forma async
		var consumed = await handler.on_step_started_to_tile(
			grid, from_tile, to_tile, actor, direction
		)
		if consumed:
			# El handler consumió el movimiento, no ejecutar movimiento normal
			# El handler es responsable de ejecutar su animación y emitir step_finished
			return true

	return false


## Se ejecuta cuando un actor EMPIEZA un paso
## NOTA: Este método NO procesa movimientos porque GridMotion ya llama directamente
## a try_handle_motion() antes de ejecutar el movimiento normal.
## Se mantiene conectado a la señal step_started por compatibilidad, pero está vacío
## para evitar bucles infinitos (jump_to_tile emite step_started durante el salto).
func _on_actor_step_started(actor: Node2D) -> void:
	# No hacer nada - GridMotion ya llama a try_handle_motion() directamente
	pass


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
	var direction = Vector2.ZERO
	var grid_motion = actor.get_node_or_null("GridMotion")
	if grid_motion:
		direction = grid_motion.dir

	# Obtener handlers activos y ejecutar on_step_finished_on_tile
	var active_handlers = _get_active_handlers_for_movement(
		tile_info, actor, direction, tile, tile
	)
	for handler in active_handlers:
		handler.on_step_finished_on_tile(grid, tile, actor)


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

	# Solo conectar step_finished - step_started no es necesario porque
	# GridMotion ya llama directamente a try_handle_motion() antes de ejecutar el movimiento
	# Conectar step_started causaría bucles infinitos cuando jump_to_tile emite step_started
	if not grid_motion.step_finished.is_connected(_on_actor_step_finished):
		grid_motion.step_finished.connect(_on_actor_step_finished.bind(actor))


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

	# Llamar a deactivate_actor en todos los handlers para que limpien su estado
	for handler in motion_handlers.values():
		if handler and handler.has_method("deactivate_actor"):
			handler.deactivate_actor(actor)
