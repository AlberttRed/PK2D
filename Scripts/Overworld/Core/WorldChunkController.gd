extends Node
class_name WorldChunkController

#region DOCUMENTACIÓN
## ================================================================================
## WORLDCHUNKCONTROLLER - Sistema de Chunks Globales del Mundo
## ================================================================================
##
## DESCRIPCIÓN GENERAL:
## -------------------
## WorldChunkController gestiona la división del mundo en chunks globales para
## optimizar la carga y procesamiento de mapas, eventos y tiles según la posición
## del jugador.
##
## CONCEPTO CLAVE: CHUNKS GLOBALES
## --------------------------------
## Los chunks son una división del MUNDO COMPLETO (todos los mapas cargados),
## no de mapas individuales. Cada chunk tiene coordenadas globales basadas en
## posición mundial, y se crean bajo demanda cuando se necesita cubrir un área.
##
## EVALUACIÓN LAZY:
## ----------------
## - Chunks inactivos: Coste = 0, no se calcula nada
## - Chunk se activa (primera vez): Se calculan eventos/tiles de ese chunk
## - Chunk se reactiva: Usa datos ya calculados (sin recalcular)
## - Chunk se desactiva: Eventos/tiles dejan de procesar
##
## ================================================================================
#endregion

## Datos de un chunk global
class ChunkData:
	var id: String                    # Identificador único (formato: "chunk_<x>_<y>")
	var map_ids: Array[String] = []   # IDs de mapas que cubre este chunk
	var world_bounds: Rect2 = Rect2() # Bounds del chunk en coordenadas mundiales
	var is_active: bool = false       # Estado de activación actual

	# Evaluación lazy: solo se calculan cuando el chunk se activa por primera vez
	var events_initialized: bool = false  # ¿Ya se calcularon los eventos?
	var event_refs: Array[WeakRef] = []   # Referencias a eventos en este chunk

	func _init(p_id: String) -> void:
		id = p_id

## Registro de chunks globales: {chunk_id: ChunkData}
## chunk_id = "chunk_<x>_<y>" donde x,y son coordenadas globales de chunk
var chunk_registry: Dictionary = {} # {String: ChunkData}

## Relación mapa -> chunks que cubre: {map_id: Array[String]}
var map_to_chunks: Dictionary = {} # {String: Array[String]}

## Referencia al WorldSystem padre (inyectada desde WorldSystem)
var world_system: WorldSystem = null

## Referencia al OverworldContext (para acceder al jugador)
var context: OverworldContext = null

## Tamaño de chunk (en tiles) - Configurado desde WorldSystem
## Basado en tamaño de pantalla visible: ~14 tiles + 2 de margen = 16x16
var default_chunk_size: Vector2i = Vector2i(16, 16)

## Distancia de activación (en chunks) desde la posición del jugador
## Los chunks dentro de este radio se consideran activos
var activation_radius: int = 1

## Señal que se emite cuando cambian los chunks activos
signal chunk_changed(new_active_chunks: Array[String])

## Chunk central actual donde está el jugador
var _current_player_chunk: ChunkData = null

## Cache de chunks activos actuales
var _cached_active_chunks: Array[String] = []

## Tamaño del jugador en píxeles (32x32)
const PLAYER_SIZE = Vector2(32, 32)


func _ready() -> void:
	pass  # Sistema inicializado


## Inicializa el WorldChunkController con referencia al WorldSystem y configuración
## @param world_system_ref: Referencia al WorldSystem padre
## @param chunk_size: Tamaño de chunk en tiles (Vector2i)
## @param activation_radius_value: Radio de activación en chunks (int)
func initialize(world_system_ref: WorldSystem, chunk_size: Vector2i, activation_radius_value: int) -> void:
	world_system = world_system_ref
	default_chunk_size = chunk_size
	activation_radius = activation_radius_value


## Configura el contexto para acceder al jugador
## @param overworld_context: Referencia al OverworldContext
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	# Conectar a las señales del jugador
	call_deferred("_connect_to_player")


## Calcula las coordenadas de chunks globales que cubre un área
## IMPORTANTE: Incluye TODOS los chunks que el área toca, incluso si solo toca una esquina.
## Esto asegura que si hay un tile suelto en un chunk, ese chunk se crea.
## @param world_bounds: Rectángulo en coordenadas mundiales
## @param tile_size: Tamaño de un tile en píxeles
## @return: Array de coordenadas de chunks (Vector2i)
func _calculate_chunk_coords(world_bounds: Rect2, tile_size: Vector2) -> Array[Vector2i]:
	var chunk_size_pixels = Vector2(
		default_chunk_size.x * tile_size.x,
		default_chunk_size.y * tile_size.y
	)

	# Calcular qué chunks toca el área (incluso si solo toca una esquina)
	# Usar floor para el inicio y ceil para el final para asegurar que capturamos todos los chunks
	var start_x = floor(world_bounds.position.x / chunk_size_pixels.x)
	var start_y = floor(world_bounds.position.y / chunk_size_pixels.y)
	# Para el final, usar ceil para incluir el chunk que contiene el punto final
	var end_x = ceil((world_bounds.position.x + world_bounds.size.x) / chunk_size_pixels.x)
	var end_y = ceil((world_bounds.position.y + world_bounds.size.y) / chunk_size_pixels.y)

	var coords: Array[Vector2i] = []
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			coords.append(Vector2i(x, y))

	return coords


## Crea o obtiene un chunk global
## @param chunk_coord: Coordenadas globales del chunk (Vector2i)
## @param tile_size: Tamaño de un tile en píxeles
## @return: ChunkData del chunk
func _get_or_create_chunk(chunk_coord: Vector2i, tile_size: Vector2) -> ChunkData:
	var chunk_id = "chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]

	if chunk_registry.has(chunk_id):
		return chunk_registry[chunk_id]

	# Crear nuevo chunk
	var chunk_size_pixels = Vector2(
		default_chunk_size.x * tile_size.x,
		default_chunk_size.y * tile_size.y
	)
	var chunk_world_pos = Vector2(
		chunk_coord.x * chunk_size_pixels.x,
		chunk_coord.y * chunk_size_pixels.y
	)

	var chunk_data = ChunkData.new(chunk_id)
	chunk_data.world_bounds = Rect2(chunk_world_pos, chunk_size_pixels)
	chunk_registry[chunk_id] = chunk_data

	return chunk_data


## Obtiene el tamaño de un tile (en píxeles)
## @param map_id: ID del mapa
## @return: Vector2 con el tamaño del tile, por defecto (32, 32)
func _get_tile_size(map_id: String) -> Vector2:
	if not world_system:
		return Vector2(32, 32)

	var map_instance = world_system.get_map(map_id)
	if not map_instance:
		return Vector2(32, 32)

	var grid = map_instance.get_node_or_null("OverworldGrid")
	if not grid or not grid is OverworldGrid:
		return Vector2(32, 32)

	var ref_layer = grid.reference_layer()
	if not ref_layer or not ref_layer.tile_set:
		return Vector2(32, 32)

	var tile_size = ref_layer.tile_set.tile_size
	return Vector2(tile_size.x, tile_size.y)


## Obtiene el rectángulo usado del mapa en coordenadas de tiles
## @param map_id: ID del mapa
## @return: Rect2i con la posición y tamaño en tiles, o Rect2i() si no se puede obtener
func _get_map_used_rect(map_id: String) -> Rect2i:
	if not world_system:
		return Rect2i()

	var map_instance = world_system.get_map(map_id)
	if not map_instance:
		return Rect2i()

	var grid = map_instance.get_node_or_null("OverworldGrid")
	if not grid or not grid is OverworldGrid:
		return Rect2i()

	var ref_layer = grid.reference_layer()
	if not ref_layer:
		return Rect2i()

	var used_rect = ref_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return Rect2i()

	return used_rect


## Registra un mapa en los chunks globales que cubre
## Se llama cuando un mapa se carga en el mundo
## IMPORTANTE:
## - Los chunks se crean SOLO donde hay mapa (aunque sea solo un tile).
## - Si hay una parte del chunk sin mapa, no importa, el chunk se crea igual.
## - Si NO hay mapa en un área, NO se genera ningún chunk ahí.
## @param map_id: ID del mapa a registrar
func register_map_to_global_chunks(map_id: String) -> void:
	if not world_system:
		push_warning("WorldChunkController: WorldSystem no disponible")
		return

	var map_info = world_system.get_map_info(map_id)
	if not map_info:
		push_warning("WorldChunkController: No se encontró información del mapa: %s" % map_id)
		return

	# Obtener el rectángulo usado del mapa (posición + tamaño en tiles)
	var used_rect = _get_map_used_rect(map_id)
	if used_rect.size == Vector2i.ZERO:
		push_warning("WorldChunkController: No se pudo obtener rectángulo usado de '%s'" % map_id)
		return

	var tile_size = _get_tile_size(map_id)

	# Calcular los bounds del mapa en coordenadas mundiales
	# La posición mundial del mapa + la posición de los tiles usados (puede ser negativa)
	var map_tiles_world_pos = Vector2(
		map_info.world_position.x + (used_rect.position.x * tile_size.x),
		map_info.world_position.y + (used_rect.position.y * tile_size.y)
	)
	var map_world_size = Vector2(used_rect.size.x * tile_size.x, used_rect.size.y * tile_size.y)
	var map_bounds = Rect2(map_tiles_world_pos, map_world_size)

	# Calcular qué chunks globales cubre este mapa
	# Esto incluirá TODOS los chunks que el mapa toca, incluso si solo toca una esquina
	var chunk_coords = _calculate_chunk_coords(map_bounds, tile_size)

	var chunks_for_map: Array[String] = []

	for chunk_coord in chunk_coords:
		# Crear el chunk (solo se crea si hay mapa que lo toca)
		var chunk_data = _get_or_create_chunk(chunk_coord, tile_size)

		# Registrar mapa en el chunk
		if not chunk_data.map_ids.has(map_id):
			chunk_data.map_ids.append(map_id)

		chunks_for_map.append(chunk_data.id)

	# Guardar relación mapa -> chunks
	map_to_chunks[map_id] = chunks_for_map

	# Si alguno de los chunks ya está activo, inicializar y activar eventos del nuevo mapa
	# Esto es necesario cuando un mapa se recrea después de haber sido eliminado
	for chunk_id in chunks_for_map:
		var chunk_data = chunk_registry.get(chunk_id)
		if chunk_data and chunk_data.is_active:
			# Inicializar eventos del nuevo mapa en este chunk activo
			_initialize_map_events_in_chunk(map_id, chunk_id)
			# Activar eventos del nuevo mapa
			_activate_map_events_in_chunk(map_id, chunk_id)


## Obtiene los chunks activos según la posición del jugador
## Calcula el chunk donde está el jugador y activa ese chunk + los adyacentes según el radio
## @param player_position: Posición mundial del jugador (Vector2)
## @return: Array de IDs de chunks activos
func get_active_chunks(player_position: Vector2) -> Array[String]:
	var active_chunks: Array[String] = []

	if chunk_registry.is_empty():
		return active_chunks

	# Calcular tamaño de chunk en píxeles (asumimos 32x32 tiles por defecto)
	var chunk_size_pixels = Vector2(
		default_chunk_size.x * 32,
		default_chunk_size.y * 32
	)

	# Calcular en qué chunk está el jugador (coordenadas de chunk)
	var player_chunk_x = floor(player_position.x / chunk_size_pixels.x)
	var player_chunk_y = floor(player_position.y / chunk_size_pixels.y)

	# Activar el chunk del jugador + los chunks adyacentes según el radio
	for dy in range(-activation_radius, activation_radius + 1):
		for dx in range(-activation_radius, activation_radius + 1):
			var chunk_coord = Vector2i(player_chunk_x + dx, player_chunk_y + dy)
			var chunk_id = "chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]

			# Solo añadir si el chunk existe en el registro
			if chunk_registry.has(chunk_id):
				active_chunks.append(chunk_id)
			else:
				# Si el chunk no existe, es un error de generación de chunks
				# Mostrar aviso pero no crear el chunk automáticamente
				push_warning("WorldChunkController: Chunk '%s' no existe en el registro. Posición jugador: %s. Esto indica un error en la generación de chunks." % [chunk_id, str(player_position)])

	return active_chunks


## Activa un chunk (LAZY: calcula eventos/tiles solo si es primera vez)
## @param chunk_id: ID del chunk a activar
func activate_chunk(chunk_id: String) -> void:
	if not chunk_registry.has(chunk_id):
		push_warning("WorldChunkController: Intento de activar chunk no registrado: %s" % chunk_id)
		return

	var chunk_data: ChunkData = chunk_registry[chunk_id]
	if chunk_data.is_active:
		return  # Ya está activo

	chunk_data.is_active = true

	# LAZY: Calcular eventos solo si es la primera vez que se activa
	if not chunk_data.events_initialized:
		_initialize_chunk_events(chunk_id)
		chunk_data.events_initialized = true

	# Activar eventos (ya calculados)
	_activate_chunk_events(chunk_id)


## Desactiva un chunk
## @param chunk_id: ID del chunk a desactivar
func deactivate_chunk(chunk_id: String) -> void:
	if not chunk_registry.has(chunk_id):
		push_warning("WorldChunkController: Intento de desactivar chunk no registrado: %s" % chunk_id)
		return

	var chunk_data: ChunkData = chunk_registry[chunk_id]
	if not chunk_data.is_active:
		return  # Ya está desactivado

	chunk_data.is_active = false

	# Desactivar eventos/tiles
	_deactivate_chunk_events(chunk_id)
	_deactivate_chunk_tiles(chunk_id)


## Inicializa eventos de un chunk (LAZY: solo cuando se activa por primera vez)
## @param chunk_id: ID del chunk
func _initialize_chunk_events(chunk_id: String) -> void:
	var chunk_data = chunk_registry.get(chunk_id)
	if not chunk_data:
		return

	# Iterar solo sobre mapas de este chunk
	for map_id in chunk_data.map_ids:
		_initialize_map_events_in_chunk(map_id, chunk_id)


## Inicializa eventos de un mapa específico en un chunk
## @param map_id: ID del mapa
## @param chunk_id: ID del chunk
func _initialize_map_events_in_chunk(map_id: String, chunk_id: String) -> void:
	var chunk_data = chunk_registry.get(chunk_id)
	if not chunk_data:
		return

	var map_instance = world_system.get_map(map_id)
	if not map_instance:
		return

	var events_node = map_instance.find_child("Events")
	if not events_node:
		return

	# Crear un set de eventos ya registrados para evitar duplicados
	var registered_events = {}
	for existing_ref in chunk_data.event_refs:
		var existing_event = existing_ref.get_ref()
		if existing_event:
			registered_events[existing_event] = true

	# Verificar si cada evento está dentro de este chunk específico
	for event in events_node.get_children():
		if not event is Event or not chunk_data.world_bounds.has_point(event.global_position):
			continue

		# Evitar duplicados
		if not registered_events.has(event):
			chunk_data.event_refs.append(weakref(event))
			registered_events[event] = true


## Activa eventos de un chunk
## @param chunk_id: ID del chunk
func _activate_chunk_events(chunk_id: String) -> void:
	var chunk_data = chunk_registry.get(chunk_id)
	if not chunk_data:
		return

	# Asegurar que los grids de los mapas de este chunk estén activos
	for map_id in chunk_data.map_ids:
		var map_instance = world_system.get_map(map_id)
		if map_instance:
			var grid = map_instance.get_node_or_null("OverworldGrid")
			if grid:
				grid.process_mode = Node.PROCESS_MODE_INHERIT

	# Activar todos los eventos del chunk
	for event_ref in chunk_data.event_refs:
		var event = event_ref.get_ref()
		if not event or not is_instance_valid(event):
			continue

		var events_node = event.get_parent()
		if events_node:
			events_node.process_mode = Node.PROCESS_MODE_INHERIT

		event.process_mode = Node.PROCESS_MODE_INHERIT
		if event.has_method("set_active"):
			event.set_active(true)
		if event.has_method("connect_external_signals"):
			event.connect_external_signals()

		# Activar eventos AUTORUN cuando el chunk se activa
		if event is Event and event.current_page:
			if event.current_page.trigger_type == EventTriggers.TriggerType.AUTORUN:
				# Usar call_deferred para asegurar que todo esté listo (context, EventSystem, etc.)
				event.call_deferred("trigger")


## Activa eventos de un mapa específico en un chunk
## @param map_id: ID del mapa
## @param chunk_id: ID del chunk
func _activate_map_events_in_chunk(map_id: String, chunk_id: String) -> void:
	var chunk_data = chunk_registry.get(chunk_id)
	if not chunk_data:
		return

	var map_instance = world_system.get_map(map_id)
	if not map_instance:
		return

	var grid = map_instance.get_node_or_null("OverworldGrid")
	if grid:
		grid.process_mode = Node.PROCESS_MODE_INHERIT

	var events_node = map_instance.find_child("Events")
	if not events_node:
		return

	events_node.process_mode = Node.PROCESS_MODE_INHERIT

	# Activar solo los eventos de este mapa que están en este chunk
	for event_ref in chunk_data.event_refs:
		var event = event_ref.get_ref()
		if not event or not is_instance_valid(event) or event.get_parent() != events_node:
			continue

		event.process_mode = Node.PROCESS_MODE_INHERIT
		if event.has_method("set_active"):
			event.set_active(true)
		if event.has_method("connect_external_signals"):
			event.connect_external_signals()

		# Activar eventos AUTORUN cuando el chunk se activa
		if event is Event and event.current_page:
			if event.current_page.trigger_type == EventTriggers.TriggerType.AUTORUN:
				# Usar call_deferred para asegurar que todo esté listo (context, EventSystem, etc.)
				event.call_deferred("trigger")


## Desactiva eventos de un chunk
## @param chunk_id: ID del chunk
func _deactivate_chunk_events(chunk_id: String) -> void:
	var chunk_data = chunk_registry.get(chunk_id)
	if not chunk_data:
		return

	for event_ref in chunk_data.event_refs:
		var event = event_ref.get_ref()
		if not event or not is_instance_valid(event):
			continue

		if event.has_method("disconnect_external_signals"):
			event.disconnect_external_signals()
		event.process_mode = Node.PROCESS_MODE_DISABLED
		if event.has_method("set_active"):
			event.set_active(false)


## Activa tiles especiales de un chunk
## @param chunk_id: ID del chunk
func _activate_chunk_tiles(chunk_id: String) -> void:
	var chunk_data = chunk_registry.get(chunk_id)
	if not chunk_data:
		return

	# FUTURO: Activar procesamiento de tiles especiales
	# Por ahora solo se registran, la activación se implementará en PBIs futuros
	pass


## Desactiva tiles especiales de un chunk
## @param chunk_id: ID del chunk
func _deactivate_chunk_tiles(chunk_id: String) -> void:
	var chunk_data = chunk_registry.get(chunk_id)
	if not chunk_data:
		return

	# FUTURO: Desactivar procesamiento de tiles especiales
	# Por ahora solo se registran, la desactivación se implementará en PBIs futuros
	pass


## Inicializa los chunks activos (usado al cargar un mapa)
## @param player_position: Posición mundial del jugador (Vector2)
func initialize_active_chunks(player_position: Vector2) -> void:
	var active_chunks = get_active_chunks(player_position)
	for chunk_id in active_chunks:
		activate_chunk(chunk_id)
	_cached_active_chunks = active_chunks.duplicate()

	# Calcular y guardar el chunk central del jugador
	var chunk_size_pixels = Vector2(default_chunk_size.x * 32, default_chunk_size.y * 32)
	var player_chunk_x = floor(player_position.x / chunk_size_pixels.x)
	var player_chunk_y = floor(player_position.y / chunk_size_pixels.y)
	var player_chunk_id = "chunk_%d_%d" % [player_chunk_x, player_chunk_y]
	_current_player_chunk = chunk_registry.get(player_chunk_id)

	if not _current_player_chunk:
		push_warning("WorldChunkController: Chunk central '%s' no existe en el registro. Posición jugador: %s" % [player_chunk_id, str(player_position)])


## Actualiza el estado de activación de chunks según la posición del jugador
## NOTA: Este método ahora se usa solo para inicialización. Para actualizaciones
## en tiempo de ejecución, usar check_chunk_bounds() que es más eficiente.
## @param player_position: Posición mundial del jugador (Vector2)
func update_active_chunks(player_position: Vector2) -> void:
	var new_active_chunks = get_active_chunks(player_position)
	var current_active_chunks: Array[String] = []

	# Obtener chunks actualmente activos
	for chunk_id in chunk_registry.keys():
		var chunk_data: ChunkData = chunk_registry[chunk_id]
		if chunk_data.is_active:
			current_active_chunks.append(chunk_id)

	# Desactivar chunks que ya no están activos
	for chunk_id in current_active_chunks:
		if not new_active_chunks.has(chunk_id):
			deactivate_chunk(chunk_id)

	# Activar chunks nuevos
	for chunk_id in new_active_chunks:
		if not current_active_chunks.has(chunk_id):
			activate_chunk(chunk_id)

	# Actualizar cache y chunk central
	_cached_active_chunks = new_active_chunks.duplicate()

	var chunk_size_pixels = Vector2(default_chunk_size.x * 32, default_chunk_size.y * 32)
	var player_chunk_x = floor(player_position.x / chunk_size_pixels.x)
	var player_chunk_y = floor(player_position.y / chunk_size_pixels.y)
	var player_chunk_id = "chunk_%d_%d" % [player_chunk_x, player_chunk_y]
	_current_player_chunk = chunk_registry.get(player_chunk_id)

	if not _current_player_chunk:
		push_warning("WorldChunkController: Chunk central '%s' no existe en el registro. Posición jugador: %s" % [player_chunk_id, str(player_position)])


## Verifica si el jugador está dentro del chunk central actual
## Solo actualiza chunks si el jugador sale del chunk central
## @param player_position: Posición mundial del jugador (Vector2)
func check_chunk_bounds(player_position: Vector2) -> void:
	# Si no hay chunk central, inicializar
	if not _current_player_chunk:
		_update_chunks_on_exit(player_position)
		return

	# Crear un rectángulo que representa el espacio ocupado por el jugador (32x32)
	var player_bounds = Rect2(
		player_position - PLAYER_SIZE / 2.0,  # Centro - mitad del tamaño
		PLAYER_SIZE
	)

	# Verificar si el jugador está dentro del chunk central
	if _current_player_chunk.world_bounds.intersects(player_bounds):
		return  # Jugador sigue dentro del chunk central, no hacer nada

	# Jugador salió del chunk central, recalcular chunks activos
	_update_chunks_on_exit(player_position)


## Actualiza los chunks activos cuando el jugador sale del chunk central
## @param player_position: Posición mundial del jugador
func _update_chunks_on_exit(player_position: Vector2) -> void:
	var new_active_chunks = get_active_chunks(player_position)

	# Calcular el chunk central del jugador
	var chunk_size_pixels = Vector2(
		default_chunk_size.x * 32,
		default_chunk_size.y * 32
	)
	var player_chunk_x = floor(player_position.x / chunk_size_pixels.x)
	var player_chunk_y = floor(player_position.y / chunk_size_pixels.y)
	var player_chunk_id = "chunk_%d_%d" % [player_chunk_x, player_chunk_y]

	# Obtener el ChunkData del chunk central
	var new_central_chunk = chunk_registry.get(player_chunk_id)

	if not new_central_chunk:
		push_warning("WorldChunkController: Chunk central '%s' no existe en el registro. Posición jugador: %s. Esto indica un error en la generación de chunks." % [player_chunk_id, str(player_position)])
		return

	# Desactivar chunks que ya no están activos
	for chunk_id in _cached_active_chunks:
		if not new_active_chunks.has(chunk_id):
			deactivate_chunk(chunk_id)

	# Activar chunks nuevos
	for chunk_id in new_active_chunks:
		if not _cached_active_chunks.has(chunk_id):
			activate_chunk(chunk_id)

	# Actualizar cache y chunk central
	_cached_active_chunks = new_active_chunks.duplicate()
	_current_player_chunk = new_central_chunk

	# Emitir señal de cambio de chunk
	chunk_changed.emit(new_active_chunks)
	print("WorldChunkController: Cambio de chunk - Chunk central: %s, Chunks activos: %d" % [player_chunk_id, new_active_chunks.size()])


## Obtiene los chunks a los que pertenece un mapa
## @param map_id: ID del mapa
## @return: Array de IDs de chunks
func get_chunks_for_map(map_id: String) -> Array[String]:
	return map_to_chunks.get(map_id, [])


## Obtiene todos los mapas que pertenecen a un chunk
## @param chunk_id: ID del chunk
## @return: Array de IDs de mapas
func get_chunk_maps(chunk_id: String) -> Array[String]:
	if not chunk_registry.has(chunk_id):
		return []

	var chunk_data: ChunkData = chunk_registry[chunk_id]
	return chunk_data.map_ids.duplicate()


## Obtiene información de un chunk
## @param chunk_id: ID del chunk
## @return: ChunkData o null si no existe
func get_chunk_info(chunk_id: String) -> ChunkData:
	return chunk_registry.get(chunk_id)


## Verifica si un chunk está activo
## @param chunk_id: ID del chunk
## @return: true si está activo, false en caso contrario
func is_chunk_active(chunk_id: String) -> bool:
	if not chunk_registry.has(chunk_id):
		return false
	var chunk_data: ChunkData = chunk_registry[chunk_id]
	return chunk_data.is_active


## Cuenta el total de tiles de encuentro en un chunk
## Conecta a las señales del jugador para actualizar chunks activos
func _connect_to_player() -> void:
	if not context:
		# Reintentar después de un frame si el contexto aún no está disponible
		await get_tree().process_frame
		_connect_to_player()
		return

	var player = context.get_player()
	if not player:
		# Reintentar después de un frame si el jugador aún no está disponible
		await get_tree().process_frame
		_connect_to_player()
		return

	var grid_motion = player.get_node_or_null("GridMotion")
	if not grid_motion:
		push_warning("WorldChunkController: GridMotion del Player no encontrado")
		return

	# Verificar si ya está conectado para evitar duplicados
	if grid_motion.step_finished.is_connected(_on_player_step_finished):
		return

	grid_motion.step_finished.connect(_on_player_step_finished)


## Se ejecuta cuando el jugador termina un paso
## OPTIMIZADO: Solo verifica si el jugador está dentro del chunk central
func _on_player_step_finished(_tile: Vector2i) -> void:
	if not context:
		return

	var player = context.get_player()
	if not player:
		return

	# Solo verificar si el jugador está dentro del chunk central
	check_chunk_bounds(player.global_position)


## Limpia todos los registros de chunks (útil para resetear)
func clear_all_chunks() -> void:
	chunk_registry.clear()
	map_to_chunks.clear()
	print("WorldChunkController: Todos los chunks han sido limpiados")


## Método de utilidad para debugging
func print_chunk_status() -> void:
	print("=== WorldChunkController Status ===")
	print("Tamaño de chunk: %dx%d tiles" % [default_chunk_size.x, default_chunk_size.y])
	print("Radio de activación: %d chunks" % activation_radius)
	print("Total chunks registrados: %d" % chunk_registry.size())

	var active_count = 0
	for chunk_id in chunk_registry.keys():
		if chunk_registry[chunk_id].is_active:
			active_count += 1

	print("Chunks activos: %d" % active_count)

	print("\nMapas y sus chunks:")
	for map_id in map_to_chunks.keys():
		var chunks = map_to_chunks[map_id]
		print("  - %s: %d chunk(s)" % [map_id, chunks.size()])

	print("\nChunks individuales:")
	for chunk_id in chunk_registry.keys():
		var chunk_data: ChunkData = chunk_registry[chunk_id]
		var status = "ACTIVO" if chunk_data.is_active else "inactivo"
		var events_info = ""
		var tiles_info = ""
		if chunk_data.events_initialized:
			events_info = " (%d eventos)" % chunk_data.event_refs.size()
		if chunk_data.tiles_initialized:
			tiles_info = " (%d tiles)" % chunk_data.special_tiles.size()
		print("  - %s: %s%s%s" % [chunk_id, status, events_info, tiles_info])
