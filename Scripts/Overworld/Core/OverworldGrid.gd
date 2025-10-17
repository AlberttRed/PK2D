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
	
	# El player se configura desde MapSystem, no desde aquí
	# para evitar conflictos con la nueva lógica de GameStart

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
		if val is String:
			return val
	return "ground"
	
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

func can_step_to(actor: Node, _from: Vector2i, to: Vector2i) -> bool:
	if is_blocked(actor, to): return false
	if has_actor(to): return false
	if res.has(to) and res[to].get_ref() != actor: return false
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
func position_player_at_tile(tile_position: Vector2i) -> bool:
	# Buscar MapSystem (solo cuando se necesita, poco frecuente)
	var map_system = get_tree().get_first_node_in_group("MapSystem") as MapSystem
	if not map_system:
		push_error("OverworldGrid: No se encontró el MapSystem")
		return false
	
	var player: Node = map_system.get_player()
	if not player:
		push_error("OverworldGrid: No se encontró el jugador")
		return false
	
	# Teletransportar al jugador a la posición especificada
	player.teleport_to_tile(tile_position)
	
	print("OverworldGrid: Jugador posicionado en tile: ", tile_position)
	return true

## Posiciona al jugador en un SpawnPoint específico
func position_player_at_spawn(spawn_id: String) -> bool:
	var spawn_point = get_spawn_point(spawn_id)
	if not spawn_point:
		push_warning("OverworldGrid: No se encontró el spawn point: " + spawn_id)
		return false
	
	# Obtener la posición del spawn point
	var spawn_position = spawn_point.get_tile_position()
	
	# Usar el método de posicionamiento por tile
	var success = position_player_at_tile(spawn_position)
	
	if success:
		# Actualizar la dirección si el spawn point la especifica
		var direction = spawn_point.get_facing_direction()
		print("OverworldGrid: Dirección del SpawnPoint: ", direction)
		set_player_facing_direction(direction)
		
		print("OverworldGrid: Jugador posicionado en spawn: ", spawn_id, " en posición: ", spawn_position, " mirando: ", direction)
	
	return success

## Establece la dirección del jugador
func set_player_facing_direction(direction: Vector2) -> void:
	# Buscar MapSystem (solo cuando se necesita, poco frecuente)
	var map_system = get_tree().get_first_node_in_group("MapSystem") as MapSystem
	if not map_system:
		push_error("OverworldGrid: No se encontró el MapSystem")
		return
	
	var player: Node = map_system.get_player()
	if not player:
		push_error("OverworldGrid: No se encontró el jugador")
		return
	
	# Establecer la dirección del jugador
	player.set_facing_direction(direction)
	
	print("OverworldGrid: Dirección del jugador establecida a: ", direction)
