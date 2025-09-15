extends Node
class_name OverworldGrid

## Asigna aquí la capa que usarás para consultas (colisión/terreno)
@export var layer_paths: Array[NodePath] = []
@onready var layers: Array[TileMapLayer] = []

# Ocupación física (solo actores que bloquean paso: Player, NPC, etc.)
var occ: Dictionary = {}   # {Vector2i: weakref(actor)}

# Eventos (bloqueantes o no)
var events: Dictionary = {}   # {Vector2i: weakref(Event)}

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
	if datas.is_empty():
		return true # fuera del mapa
	
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
	if is_blocked(actor, to): return false
	if has_actor(to): return false
	if res.has(to) and res[to].get_ref() != actor: return false
	return true

# --- Reservas / commit ---
func reserve(from: Vector2i, to: Vector2i, actor: Node) -> void:
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
