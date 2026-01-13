extends Node2D
class_name OverworldGrid

## Asigna aquí la capa que usarás para consultas (colisión/terreno)
@export var layer_paths: Array[NodePath] = []
var layers: Array[TileMapLayer] = []

# Ocupación física (solo actores que bloquean paso: Player, NPC, etc.)
var occ: Dictionary = {}   # {Vector2i: weakref(actor)}

# Eventos (bloqueantes o no)
var events: Dictionary = {}   # {Vector2i: weakref(Event)}

# Reservas de movimiento
var res: Dictionary = {}   # {Vector2i: weakref(actor)}

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
	pass
	# El contexto se inyectará desde WorldSystem cuando se active este mapa
	# Los eventos recibirán el contexto después de que el grid lo reciba

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

## Obtiene toda la información relevante de un tile en un solo paso
## Evita múltiples llamadas a get_tile_data()
## @param t: Posición del tile
## @return: Dictionary con terrain, encounter_type, y otros datos del tile
func get_tile_info(t: Vector2i) -> Dictionary:
	var info = {
		"terrain": "ground",  # Por defecto
		"encounter_type": "",
		"water_reflection": false, # Indica si el tile muestra el efecto de reflejo del Sprite
		"water_ripple": false, # Indica si el tile muestra el efecto de ripple
		"exit_dir": "",  # Dirección de salida (para flecha de salida)
		"ledge_direction": "",  # Dirección del salto de ledge (para TileMotionSystem)
		"stair_dir": ""  # Dirección de la escalera (para TileMotionSystem)
	}

	# Un solo loop sobre todas las capas
	for layer in layers:
		var tile_data = layer.get_cell_tile_data(t)
		if not tile_data:
			continue

		# Recoger terrain (el primero que encuentre)
		if info.terrain == "ground" and tile_data.has_custom_data("terrain"):
			var terrain_val = tile_data.get_custom_data("terrain")
			if terrain_val is String and not terrain_val.is_empty():
				info.terrain = terrain_val

		# Recoger encounter_type (el primero que encuentre)
		if info.encounter_type.is_empty() and tile_data.has_custom_data("encounter_type"):
			var encounter_val = tile_data.get_custom_data("encounter_type")
			if encounter_val is String and not encounter_val.is_empty():
				info.encounter_type = encounter_val

		# Recoger water_reflection (el primero que encuentre)
		if !info.water_reflection and tile_data.has_custom_data("water_reflection"):
			var water_reflection_val = tile_data.get_custom_data("water_reflection")
			if water_reflection_val is bool:
				info.water_reflection = water_reflection_val

		# Recoger water_ripple (el primero que encuentre)
		if !info.water_ripple and tile_data.has_custom_data("water_ripple"):
			var water_ripple_val = tile_data.get_custom_data("water_ripple")
			if water_ripple_val is bool:
				info.water_ripple = water_ripple_val

		# Recoger exit_dir (el primero que encuentre)
		if info.exit_dir.is_empty() and tile_data.has_custom_data("exit_dir"):
			var exit_dir_val = tile_data.get_custom_data("exit_dir")
			if exit_dir_val is String and not exit_dir_val.is_empty():
				info.exit_dir = exit_dir_val

		# Recoger ledge_direction (el primero que encuentre)
		if info.ledge_direction.is_empty() and tile_data.has_custom_data("ledge_direction"):
			var ledge_dir_val = tile_data.get_custom_data("ledge_direction")
			if ledge_dir_val is String and not ledge_dir_val.is_empty():
				info.ledge_direction = ledge_dir_val

		# Recoger stair_dir (el primero que encuentre)
		if info.stair_dir.is_empty() and tile_data.has_custom_data("stair_dir"):
			var stair_dir_val = tile_data.get_custom_data("stair_dir")
			if stair_dir_val is String and not stair_dir_val.is_empty():
				info.stair_dir = stair_dir_val

	return info

# --- Terreno / Pasabilidad ---
func terrain_at(t: Vector2i) -> String:
	return get_tile_info(t).terrain

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
					return false

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
	# No sobrescribir eventos existentes a menos que sea el mismo evento
	# Esto previene que eventos estáticos se pierdan cuando otros actores pasan por encima
	if events.has(tile):
		var existing_ref = events[tile].get_ref()
		if existing_ref and existing_ref != event:
			# Ya hay otro evento en este tile, no sobrescribir
			# Solo sobrescribir si el evento existente ya no es válido
			if is_instance_valid(existing_ref):
				return  # Mantener el evento existente
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

## Verifica si dos actores están en una relación leader-follower
func _are_actors_following(actor1: Node, actor2: Node) -> bool:
	if not actor1 or not actor2:
		return false

	# Verificar si actor1 tiene FollowerComponent que sigue a actor2
	var follower_comp1 = actor1.get_node_or_null("FollowerComponent")
	if follower_comp1 and follower_comp1.is_active() and follower_comp1.leader == actor2:
		return true

	# Verificar si actor2 tiene FollowerComponent que sigue a actor1
	var follower_comp2 = actor2.get_node_or_null("FollowerComponent")
	if follower_comp2 and follower_comp2.is_active() and follower_comp2.leader == actor1:
		return true

	return false

func can_step_to(actor: Node, from: Vector2i, to: Vector2i) -> bool:
	# Verificaciones clásicas de bloqueo
	if is_blocked(actor, to):
		return false
	if has_actor(to):
		var occupying_actor = occ[to].get_ref()
		# Si el actor ocupante está en relación leader-follower con el actor que intenta moverse,
		# ignorar la ocupación para permitir el movimiento simultáneo
		if occupying_actor and _are_actors_following(actor, occupying_actor):
			# Permitir el movimiento, ignorando la ocupación
			pass
		else:
			print("IS ACTOR " + str(occupying_actor))
			return false
	if res.has(to) and res[to].get_ref() != actor:
		var reserving_actor = res[to].get_ref()
		# También ignorar reservas si están en relación leader-follower
		if not reserving_actor or not _are_actors_following(actor, reserving_actor):
			return false
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

	# Solo ocupar el tile destino si el actor NO tiene through activado
	var is_through = false
	if actor is Event and actor.current_page:
		is_through = actor.current_page.through

	if not is_through:
		# Verificar si hay un evento en el tile destino que no sea through
		# Si hay un evento through, podemos ocupar el tile
		# Si hay un evento no-through, el evento mantiene la ocupación
		var existing_event = event_at(to)
		if existing_event and existing_event != actor:
			# Hay un evento en el tile destino
			if existing_event.current_page and not existing_event.current_page.through:
				# El evento no es through, mantener su ocupación
				# No ocupar el tile con el actor
				pass
			else:
				# El evento es through, podemos ocupar el tile
				occ[to] = weakref(actor)
		else:
			# No hay evento en el tile destino, ocupar normalmente
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
	# Ignorar eventos TOUCH cuando el movimiento es controlado por comando (solo para Player)
	# Esto evita que los eventos se activen durante movimientos automáticos (MoveNPCCommand, etc.)
	if actor.is_in_group("Player"):
		var player_motion = actor.get_node_or_null("GridMotion")
		if player_motion and player_motion.is_command_controlled:
			return  # No activar eventos TOUCH durante movimiento controlado

	# Buscar evento en el tile destino
	var e = event_at(t)
	if not e:
		return

	# Usar el nuevo sistema de triggers
	e.try_fire(EventTriggerSignal.SignalType.TOUCH, actor)


func interactable_at(t: Vector2i) -> Node:
	for d in get_tile_data(t):
		var val = d.get_custom_data("interactable")
		if val is Node:
			return val
	return null

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

	return true

## Establece la dirección del jugador
## @param direction: Dirección a establecer
## @param player: Nodo del jugador (REQUERIDO - debe pasarse explícitamente)
func set_player_facing_direction(direction: Vector2, player: Node) -> void:
	if not player:
		push_error("OverworldGrid.set_player_facing_direction(): Player es requerido como parámetro")
		return

	# Establecer la dirección del jugador
	player.set_facing_direction(direction)

## ============================================================================
## CONTEXT MANAGEMENT
## ============================================================================

## Establece el contexto del Overworld (llamado desde WorldSystem al activar el mapa)
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context

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
