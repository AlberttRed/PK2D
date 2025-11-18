extends Node2D
class_name OverworldGrid

## Asigna aquí la capa que usarás para consultas (colisión/terreno)
@export var layer_paths: Array[NodePath] = []
var layers: Array[TileMapLayer] = []

# Ocupación física (solo actores que bloquean paso: Player, NPC, etc.)
var occ: Dictionary = {}   # {Vector2i: weakref(actor)}

# Eventos (bloqueantes o no)
var events: Dictionary = {}   # {Vector2i: weakref(Event)}

# SpawnPoints del mapa
var spawn_points: Dictionary = {}   # {spawn_id: SpawnPoint}

# Reservas de movimiento
var res: Dictionary = {}   # {Vector2i: weakref(actor)}

# Debug mode para restricciones direccionales (PBI 454)
@export var debug_show_directional_restrictions: bool = false

# Referencia al OverworldContext (obtenida del EventSystem)
var context: OverworldContext = null



func _enter_tree() -> void:
	# Añade este nodo al grupo para localizarlo fácil
	if !is_in_group("OverworldGrid"):
		push_error("El grid del mapa %s no está asignado al grupo OverworldGrid" % [name])
	for path in layer_paths:
		var node = get_node(path)
		if node is TileMapLayer:
			layers.append(node)
		else:
			push_warning("El nodo en '%s' no es un TileMapLayer" % [path])

func _ready() -> void:
	# Registrar todos los SpawnPoints del mapa
	_register_all_spawns()

	# El contexto se inyectará desde WorldSystem cuando se active este mapa
	# Los eventos recibirán el contexto después de que el grid lo reciba

	# Activar redibujado continuo si el modo debug está activado
	if debug_show_directional_restrictions:
		set_process(true)

func _process(_delta: float) -> void:
	if debug_show_directional_restrictions:
		queue_redraw()

## --- Helpers coord ---
func reference_layer() -> TileMapLayer:
	if layers.is_empty():
		return null
	return layers[0] # la primera del array

func world_to_tile(p_world: Vector2) -> Vector2i:
	var ref = reference_layer()
	if not ref: return Vector2i.ZERO
	var local = ref.to_local(p_world)
	return ref.local_to_map(local)

func tile_to_world_center(t: Vector2i) -> Vector2:
	var ref = reference_layer()
	if not ref: return Vector2.ZERO
	var local_center = ref.map_to_local(t)
	return ref.to_global(local_center)

func get_tile_data(t: Vector2i) -> Array[TileData]:
	var result: Array[TileData] = []
	for l in layers:
		var d = l.get_cell_tile_data(t)
		if d:
			result.append(d)
	return result

# --- Terreno / Pasabilidad ---
func terrain_at(t: Vector2i) -> String:
	for d in get_tile_data(t):
		var val = d.get_custom_data("terrain")
		if val is String and not val.is_empty():
			return val
	return "ground"

# --- Restricciones Direccionales (PBI 454) ---
## Convierte un vector de dirección a una bandera de dirección (DirectionFlagsEnum)
func _direction_to_flag(direction: Vector2) -> int:
	if direction.x < 0:
		return DirectionFlagsEnum.Values.LEFT
	elif direction.x > 0:
		return DirectionFlagsEnum.Values.RIGHT
	elif direction.y < 0:
		return DirectionFlagsEnum.Values.UP
	elif direction.y > 0:
		return DirectionFlagsEnum.Values.DOWN
	return DirectionFlagsEnum.Values.NONE

## Verifica si se puede SALIR del tile origen en la dirección especificada
## @param from_tile: Tile de origen
## @param direction: Dirección del movimiento (Vector2)
## @return true si se permite salir en esa dirección, false si está bloqueado
func can_exit_tile(from_tile: Vector2i, direction: Vector2) -> bool:
	var datas = get_tile_data(from_tile)
	if datas.is_empty():
		return true  # Si no hay tile data, permitir movimiento (comportamiento por defecto)

	var dir_flag = _direction_to_flag(direction)
	if dir_flag == DirectionFlagsEnum.Values.NONE:
		return true  # Sin dirección válida, permitir

	# Verificar exit_mask en todas las capas del tile
	for d in datas:
		if d.has_custom_data("exit_mask"):
			var exit_mask = d.get_custom_data("exit_mask")
			if exit_mask is int:
				# Si exit_mask es 0, significa sin restricciones (permitir todas)
				if exit_mask == 0:
					continue
				# Verificar si la dirección está permitida en la máscara
				# La máscara indica direcciones PERMITIDAS, si el bit está activo, se permite
				if (exit_mask & dir_flag) == 0:
					return false  # Dirección NO está en la máscara, bloquear salida

	return true  # Por defecto, permitir salida

## Verifica si se puede ENTRAR al tile destino desde la dirección especificada
## @param to_tile: Tile de destino
## @param direction: Dirección del movimiento (Vector2)
## @return true si se permite entrar desde esa dirección, false si está bloqueado
func can_enter_tile(to_tile: Vector2i, direction: Vector2) -> bool:
	var datas = get_tile_data(to_tile)
	if datas.is_empty():
		return true  # Si no hay tile data, permitir movimiento

	var dir_flag = _direction_to_flag(direction)
	if dir_flag == DirectionFlagsEnum.Values.NONE:
		return true  # Sin dirección válida, permitir

	# Para la entrada, debemos verificar desde la dirección OPUESTA
	# Si nos movemos hacia la DERECHA, entramos desde la IZQUIERDA
	var entry_dir_flag = _get_opposite_direction_flag(dir_flag)

	# Verificar entry_mask en todas las capas del tile
	for d in datas:
		if d.has_custom_data("entry_mask"):
			var entry_mask = d.get_custom_data("entry_mask")
			if entry_mask is int:
				# Si entry_mask es 0, significa sin restricciones (permitir todas)
				if entry_mask == 0:
					continue
				# Verificar si se puede entrar desde esa dirección
				if (entry_mask & entry_dir_flag) == 0:
					return false  # Dirección NO está en la máscara, bloquear entrada

	return true  # Por defecto, permitir entrada

## Obtiene la dirección opuesta de una bandera de dirección
func _get_opposite_direction_flag(dir_flag: int) -> int:
	match dir_flag:
		DirectionFlagsEnum.Values.UP:
			return DirectionFlagsEnum.Values.DOWN
		DirectionFlagsEnum.Values.DOWN:
			return DirectionFlagsEnum.Values.UP
		DirectionFlagsEnum.Values.LEFT:
			return DirectionFlagsEnum.Values.RIGHT
		DirectionFlagsEnum.Values.RIGHT:
			return DirectionFlagsEnum.Values.LEFT
	return DirectionFlagsEnum.Values.NONE

# --- Sistema de Saltos (Ledges) - PBI 455 ---
## Verifica si un tile es un ledge (acantilado) y devuelve su dirección
## @param tile: Posición del tile a verificar
## @return Dictionary con {"is_ledge": bool, "direction": Vector2}
func get_ledge_info(tile: Vector2i) -> Dictionary:
	var datas = get_tile_data(tile)
	if datas.is_empty():
		return {"is_ledge": false, "direction": Vector2.ZERO}

	for d in datas:
		if d.has_custom_data("ledge_direction"):
			var ledge_dir = d.get_custom_data("ledge_direction")
			if ledge_dir is String and not ledge_dir.is_empty():
				var direction = _string_to_direction(ledge_dir)
				return {"is_ledge": true, "direction": direction}

	return {"is_ledge": false, "direction": Vector2.ZERO}

## Convierte un string de dirección a Vector2
## @param dir_string: String con la dirección ("up", "down", "left", "right")
## @return Vector2 con la dirección
func _string_to_direction(dir_string: String) -> Vector2:
	match dir_string.to_lower():
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			push_warning("OverworldGrid: Dirección de ledge no válida: " + dir_string)
			return Vector2.ZERO

## Verifica si un actor puede saltar un ledge en la dirección especificada
## @param actor: Actor que intenta saltar
## @param ledge_tile: El tile del ledge (donde el jugador está entrando)
## @param direction: Dirección del salto
## @return bool: true si puede saltar, false si no
func can_jump_ledge(actor: Node, ledge_tile: Vector2i, direction: Vector2) -> bool:
	# Solo el jugador puede saltar ledges
	if not actor.is_in_group("Player"):
		return false

	# Verificar que el tile es un ledge
	var ledge_info = get_ledge_info(ledge_tile)
	if not ledge_info["is_ledge"]:
		return false

	# Verificar que la dirección del salto coincida con la dirección del ledge
	if ledge_info["direction"] != direction:
		return false

	# El salto es de 1 tile después del ledge: verificar que el tile de aterrizaje está libre
	var landing_tile = ledge_tile + Vector2i(direction)  # Tile de aterrizaje (inmediatamente después del ledge)

	# Verificar que el tile de aterrizaje existe y no está bloqueado ni ocupado
	if is_blocked(actor, landing_tile) or has_actor(landing_tile):
		return false

	return true

func register_event(tile: Vector2i, event: Event) -> void:
	events[tile] = weakref(event)

func unregister_event(tile: Vector2i, event: Event) -> void:
	if events.has(tile) and events[tile].get_ref() == event:
		events.erase(tile)

func event_at(tile: Vector2i) -> Event:
	if events.has(tile):
		return events[tile].get_ref()
	return null


func is_blocked(actor: Node, t: Vector2i) -> bool:
	var datas = get_tile_data(t)

	# Si el tile no está en este mapa, está "bloqueado" para este grid
	# (No es responsabilidad de este grid verificar otros mapas)
	if datas.is_empty():
		return true

	# Verificar propiedades de bloqueo del tile
	for d in datas:
		if d.get_custom_data("blocked") == true:
			return true
		var ter = d.get_custom_data("terrain")
		if ter == "water" and not actor.has_meta("can_surf"):
			return true
		# puedes añadir aquí más reglas especiales
	return false


func has_actor(t: Vector2i) -> bool:
	return occ.has(t) and occ[t].get_ref() != null

func can_step_to(actor: Node, from: Vector2i, to: Vector2i) -> bool:
	# Verificaciones clásicas de bloqueo
	if is_blocked(actor, to): return false
	if has_actor(to): return false
	if res.has(to) and res[to].get_ref() != actor: return false

	# Verificar restricciones direccionales (PBI 454)
	var direction = Vector2(to - from)

	# Verificar si se puede SALIR del tile origen en la dirección del movimiento
	if not can_exit_tile(from, direction):
		return false

	# Verificar si se puede ENTRAR al tile destino desde la dirección del movimiento
	if not can_enter_tile(to, direction):
		return false

	return true

# --- Reservas / commit ---
func reserve(_from: Vector2i, to: Vector2i, actor: Node) -> void:
	for k in res.keys():
		if res[k].get_ref() == actor:
			res.erase(k)
	res[to] = weakref(actor)

func commit(from: Vector2i, to: Vector2i, actor: Node) -> void:
	if occ.get(from) and occ[from].get_ref() == actor:
		occ.erase(from)
	occ[to] = weakref(actor)
	if res.get(to) and res[to].get_ref() == actor:
		res.erase(to)

# --- Spawn / teleport ---
func occupy(tile: Vector2i, actor: Node) -> void:
	occ[tile] = weakref(actor)

func vacate(tile: Vector2i, actor: Node) -> void:
	if occ.get(tile) and occ[tile].get_ref() == actor:
		occ.erase(tile)

# --- Triggers / Interact ---
func on_enter_tile(actor: Node, t: Vector2i) -> void:
	if actor.is_in_group("Player"):  # o instanceof Player
		var e = event_at(t)
		if e:
			e.on_player_touch()


func interactable_at(t: Vector2i) -> Node:
	for d in get_tile_data(t):
		var val = d.get_custom_data("interactable")
		if val is Node:
			return val
	return null

# --- SpawnPoints Management ---
## Registra todos los SpawnPoints del mapa
func _register_all_spawns() -> void:
	# Buscar el nodo SpawnPoints
	var spawn_container = get_node_or_null("SpawnPoints")
	if spawn_container:
		_register_spawns_recursive(spawn_container)
	else:
		# Si no hay nodo SpawnPoints, buscar en toda la escena
		_register_spawns_recursive(self)

## Registra SpawnPoints recursivamente
func _register_spawns_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is SpawnPoint:
			register_spawn_point(child)
		# Buscar recursivamente en los hijos
		_register_spawns_recursive(child)

## Registra un SpawnPoint individual
func register_spawn_point(spawn: SpawnPoint) -> void:
	if not spawn:
		return

	var spawn_id = spawn.get_spawn_id()
	if spawn_id.is_empty():
		push_warning("OverworldGrid: SpawnPoint sin ID válido: " + str(spawn))
		return

	spawn_points[spawn_id] = spawn
	print("OverworldGrid: SpawnPoint registrado - ID: ", spawn_id)

## Obtiene un SpawnPoint por su ID
func get_spawn_point(spawn_id: String) -> SpawnPoint:
	return spawn_points.get(spawn_id, null)

## Obtiene todos los SpawnPoints del mapa
func get_all_spawn_points() -> Dictionary:
	return spawn_points.duplicate()

## Verifica si existe un SpawnPoint con el ID especificado
func has_spawn_point(spawn_id: String) -> bool:
	return spawn_points.has(spawn_id)

# --- Player Positioning ---
## Posiciona al jugador en una posición específica (Vector2i)
## @param tile_position: Tile donde posicionar al jugador
## @param player: Nodo del jugador (REQUERIDO - debe pasarse explícitamente)
func position_player_at_tile(tile_position: Vector2i, player: Node) -> bool:
	if not player:
		push_error("OverworldGrid.position_player_at_tile(): Player es requerido como parámetro")
		return false

	# Teletransportar al jugador a la posición especificada
	player.teleport_to_tile(tile_position)

	print("OverworldGrid: Jugador posicionado en tile: ", tile_position)
	return true

## Posiciona al jugador en un SpawnPoint específico
## @param spawn_id: ID del spawn point
## @param player: Nodo del jugador (REQUERIDO - debe pasarse explícitamente)
func position_player_at_spawn(spawn_id: String, player: Node) -> bool:
	if not player:
		push_error("OverworldGrid.position_player_at_spawn(): Player es requerido como parámetro")
		return false

	var spawn_point = get_spawn_point(spawn_id)
	if not spawn_point:
		push_warning("OverworldGrid: No se encontró el spawn point: " + spawn_id)
		return false

	# Obtener la posición del spawn point
	var spawn_position = spawn_point.get_tile_position()

	# Usar el método de posicionamiento por tile
	var success = position_player_at_tile(spawn_position, player)

	if success:
		# Actualizar la dirección si el spawn point la especifica
		var direction = spawn_point.get_facing_direction()
		print("OverworldGrid: Dirección del SpawnPoint: ", direction)
		set_player_facing_direction(direction, player)

		print("OverworldGrid: Jugador posicionado en spawn: ", spawn_id, " en posición: ", spawn_position, " mirando: ", direction)

	return success

## Establece la dirección del jugador
## @param direction: Dirección a establecer
## @param player: Nodo del jugador (REQUERIDO - debe pasarse explícitamente)
func set_player_facing_direction(direction: Vector2, player: Node) -> void:
	if not player:
		push_error("OverworldGrid.set_player_facing_direction(): Player es requerido como parámetro")
		return

	# Establecer la dirección del jugador
	player.set_facing_direction(direction)

	print("OverworldGrid: Dirección del jugador establecida a: ", direction)

## ============================================================================
## CONTEXT MANAGEMENT
## ============================================================================

## Establece el contexto del Overworld (llamado desde WorldSystem al activar el mapa)
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	print("OverworldGrid: Contexto establecido")

	# Propagar el contexto a todos los eventos hijos
	_inject_context_to_events()

## Propaga el contexto a todos los eventos hijos del grid
func _inject_context_to_events() -> void:
	if not context:
		return

	var events_container = get_node_or_null("Events")
	if not events_container:
		return

	for event in events_container.get_children():
		if event.has_method("set_overworld_context"):
			event.set_overworld_context(context)

# --- Debug Visualization (PBI 454) ---
func _draw() -> void:
	if not debug_show_directional_restrictions:
		return

	var ref_layer = reference_layer()
	if not ref_layer:
		return

	# Obtener el viewport visible actual para saber qué tiles dibujar
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	# Calcular el área visible (con un margen)
	var viewport_size = get_viewport_rect().size
	var cam_pos = camera.global_position
	var zoom = camera.zoom

	var visible_rect = Rect2(
		cam_pos - (viewport_size / zoom / 2.0) - Vector2(CONST.GRID_SIZE * 2, CONST.GRID_SIZE * 2),
		viewport_size / zoom + Vector2(CONST.GRID_SIZE * 4, CONST.GRID_SIZE * 4)
	)

	# Convertir rect visible a coordenadas de tile
	var top_left_tile = world_to_tile(visible_rect.position)
	var bottom_right_tile = world_to_tile(visible_rect.position + visible_rect.size)

	# Iterar sobre los tiles visibles
	for y in range(top_left_tile.y, bottom_right_tile.y + 1):
		for x in range(top_left_tile.x, bottom_right_tile.x + 1):
			var tile_pos = Vector2i(x, y)
			var datas = get_tile_data(tile_pos)

			if datas.is_empty():
				continue

			# Dibujar restricciones de este tile
			_draw_tile_restrictions(tile_pos, datas)

## Dibuja las restricciones de un tile específico
func _draw_tile_restrictions(tile_pos: Vector2i, datas: Array[TileData]) -> void:
	var world_center = tile_to_world_center(tile_pos)
	var half_size = CONST.GRID_SIZE / 2.0

	for d in datas:
		# Dibujar exit_mask
		if d.has_custom_data("exit_mask"):
			var exit_mask = d.get_custom_data("exit_mask")
			if exit_mask is int and exit_mask != 0:
				_draw_directional_arrows(world_center, exit_mask, Color.RED, half_size * 0.8, "EXIT")

		# Dibujar entry_mask
		if d.has_custom_data("entry_mask"):
			var entry_mask = d.get_custom_data("entry_mask")
			if entry_mask is int and entry_mask != 0:
				_draw_directional_arrows(world_center, entry_mask, Color.GREEN, half_size * 0.6, "ENTRY")

## Dibuja flechas direccionales según la máscara
func _draw_directional_arrows(center: Vector2, mask: int, color: Color, length: float, _label: String) -> void:
	var arrow_thickness = 2.0
	var arrow_head_size = 4.0

	# Dibujar flechas para cada dirección en la máscara
	if mask & DirectionFlagsEnum.Values.UP:
		_draw_arrow(center, Vector2.UP, length, color, arrow_thickness, arrow_head_size)

	if mask & DirectionFlagsEnum.Values.RIGHT:
		_draw_arrow(center, Vector2.RIGHT, length, color, arrow_thickness, arrow_head_size)

	if mask & DirectionFlagsEnum.Values.DOWN:
		_draw_arrow(center, Vector2.DOWN, length, color, arrow_thickness, arrow_head_size)

	if mask & DirectionFlagsEnum.Values.LEFT:
		_draw_arrow(center, Vector2.LEFT, length, color, arrow_thickness, arrow_head_size)

## Dibuja una flecha individual
func _draw_arrow(start: Vector2, direction: Vector2, length: float, color: Color, thickness: float, head_size: float) -> void:
	var end = start + direction * length

	# Línea principal
	draw_line(start, end, color, thickness)

	# Cabeza de la flecha
	var perpendicular = Vector2(-direction.y, direction.x)
	var head_base = end - direction * head_size
	var head_left = head_base + perpendicular * head_size * 0.5
	var head_right = head_base - perpendicular * head_size * 0.5

	# Triángulo de la cabeza
	var points = PackedVector2Array([end, head_left, head_right])
	draw_colored_polygon(points, color)
