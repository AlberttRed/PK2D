extends Node
class_name OverworldGrid

## Añade este nodo al grupo para localizarlo fácil
func _ready() -> void:
	add_to_group("OverworldGrid")

## Asigna aquí la capa que usarás para consultas (colisión/terreno)
@export var layer_path: NodePath
@onready var layer := get_node(layer_path) # TileMapLayer

# Ocupación y reservas
var occ: Dictionary = {}   # {Vector2i: weakref(actor)}
var res: Dictionary = {}   # {Vector2i: weakref(actor)}

# --- Helpers coord ---
func world_to_tile(p_world: Vector2) -> Vector2i:
	# Para TileMapLayer, conviertes a local del layer y luego a celda
	var local = layer.to_local(p_world)
	return layer.local_to_map(local)

func tile_to_world_center(t: Vector2i) -> Vector2:
	# Para TileMapLayer, map_to_local te da el centro del tile en coords locales del layer
	var local_center = layer.map_to_local(t)
	return layer.to_global(local_center)

# --- Terreno / Pasabilidad ---
func terrain_at(t: Vector2i) -> String:
	var d: TileData = layer.get_cell_tile_data(t)
	if d:
		var val = d.get_custom_data("terrain")
		if val is String:
			return val
	return "ground"


func is_blocked(actor: Node, t: Vector2i) -> bool:
	var d: TileData = layer.get_cell_tile_data(t)
	if d == null:
		return true # fuera del mapa
	if d.get_custom_data("blocked") == true:
		return true
	# ejemplo de regla por terreno
	var ter := terrain_at(t)
	if ter == "water" and not actor.has_meta("can_surf"):
		return true
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
	# Hook para encuentros/trigger/terreno especial (lo añadiremos más adelante)
	pass

func interactable_at(t: Vector2i) -> Node:
	# Si registras interactuables por grid, devuélvelos aquí
	return null
