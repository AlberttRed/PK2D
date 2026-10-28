extends Node3D
class_name World3DSystem
## Equivalente 3D de `WorldSystem` (2D). PBI #970.
##
## Gestiona UN mapa 3D activo a la vez (sin chunks/vecinos/seamless todavía):
##  - Resuelve el id de mapa (nombre de la escena, igual que en 2D) a una PackedScene.
##  - Carga/descarga el mapa y enlaza al Player3D con el OverworldGrid3D del mapa.
##  - Instancia el Player3D, lo registra como "Player" en el OverworldContext y le inyecta el contexto.
##  - Inyecta el contexto a cada Event3D del mapa (para que `trigger()` pueda llamar a `request_event`).
##  - Mantiene `GameStateService` sincronizado (mapa / celda / orientación).
##
## CONTRATO "mundo" (duck typing) que usa OverworldCoordinator (#971) para tratar 2D y 3D igual:
##   set_context(ctx) · has_map(id) · change_to_map(id) -> bool · load_player() -> bool
##   get_player() · get_active_map() · get_active_map_id()
##   place_player(cell, facing) -> bool   (equivale a grid.position_player_at_tile + set_player_facing_direction)
##
## LIMITACIÓN CONOCIDA: `OverworldContext.register_system("World", ...)` solo rellena `world_system`
## (tipado `WorldSystem`) para el mundo 2D; con World3DSystem queda en null y el sistema es accesible
## vía `context.get_system("World")`. Los comandos que usan `get_world_system()` (Warp, StartBattle,
## StopBGM) se adaptan en #964/#965.

signal map_changed(map_id: String)

## Escenas de mapa 3D (id de mapa = nombre del archivo, como en WorldSystem 2D).
@export var world_map_scenes: Array[PackedScene] = []
@export var player_scene: PackedScene = preload("res://Scenes/Overworld3D/Player3D.tscn")
## Altura (Y) a la que se coloca el player al hacer spawn por celda.
@export var spawn_ground_y: float = 0.0

var context: OverworldContext = null
var active_map: Node = null
var player: Player3D = null

var _scene_index: Dictionary = {} ## map_id -> PackedScene
var _index_built: bool = false


func _ready() -> void:
	_ensure_index()


func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	if player != null:
		player.set_context(context)
	if active_map != null:
		_inject_context_to_events(active_map)


# --- Registro de mapas ---

func _ensure_index() -> void:
	if _index_built:
		return
	_index_built = true
	_scene_index.clear()
	for scene: PackedScene in world_map_scenes:
		if scene == null or scene.resource_path.is_empty():
			continue
		_scene_index[scene.resource_path.get_file().get_basename()] = scene


func has_map(map_id: String) -> bool:
	_ensure_index()
	return _scene_index.has(map_id)


func get_registered_maps() -> Array:
	_ensure_index()
	return _scene_index.keys()


# --- Mapa activo ---

func change_to_map(map_id: String) -> bool:
	_ensure_index()
	var scene: PackedScene = _scene_index.get(map_id)
	if scene == null:
		push_error("World3DSystem: mapa 3D no registrado: %s" % map_id)
		return false
	if active_map != null and active_map.name == map_id:
		return true

	var instance := scene.instantiate()
	instance.name = map_id
	# Los mapas de prueba pueden traer su propio Player3D; aquí lo gestiona el sistema.
	_strip_embedded_players(instance)

	# El map_id debe estar en GameState antes de que los eventos calculen su event_id.
	GameStateService.set_current_map_id(map_id)

	if active_map != null:
		var old := active_map
		# Igual que WorldSystem 2D: aplica los cambios diferidos (defer_until_warp) del mapa que se deja.
		GameStateService.apply_deferred_changes(String(old.name))
		active_map = null
		remove_child(old) # sale del árbol ya: su OverworldGrid3D deja el grupo al instante
		old.queue_free()

	add_child(instance)
	active_map = instance
	_inject_context_to_events(instance)

	if player != null:
		player.bind_grid(get_active_grid())

	map_changed.emit(map_id)
	return true


func get_active_map() -> Node:
	return active_map


func get_active_map_id() -> String:
	return "" if active_map == null else String(active_map.name)


## Grid 3D del mapa activo (null si no hay mapa o no tiene OverworldGrid3D).
func get_active_grid() -> OverworldGrid3D:
	if active_map == null:
		return null
	for child in active_map.get_children():
		if child is OverworldGrid3D:
			return child as OverworldGrid3D
	return null


func try_get_active_grid() -> OverworldGrid3D:
	return get_active_grid()


# --- Player ---

func get_player() -> Node:
	return player


## Instancia el Player3D (requiere mapa activo, para que encuentre su OverworldGrid3D en _ready).
func load_player() -> bool:
	if player_scene == null:
		push_error("World3DSystem: player_scene no asignada")
		return false
	if get_active_grid() == null:
		push_error("World3DSystem: load_player() sin mapa activo con OverworldGrid3D")
		return false
	var instance := player_scene.instantiate() as Player3D
	if instance == null:
		push_error("World3DSystem: player_scene no es un Player3D")
		return false

	add_child(instance)
	player = instance
	if context != null:
		context.register_system("Player", instance)
	instance.set_context(context)
	return true


## Coloca al player en una celda del mapa activo con una orientación (Vector2 de GameState: x→X, y→Z).
func place_player(cell: Vector2i, facing: Vector2 = Vector2.ZERO) -> bool:
	if player == null:
		push_error("World3DSystem: place_player() sin player")
		return false
	var dir := Vector2i(signi(int(facing.x)), signi(int(facing.y)))
	# Solo cardinales (como el 2D): si es diagonal, prioriza el eje X.
	if dir.x != 0 and dir.y != 0:
		dir.y = 0
	player.place_at_cell(cell, dir, spawn_ground_y)
	force_sync_to_gamestate()
	return true


# --- Sincronización con GameState (misma API que WorldSystem 2D) ---

func force_sync_to_gamestate() -> void:
	if active_map != null:
		GameStateService.set_current_map_id(String(active_map.name))
	sync_position_for_save()


func sync_position_for_save() -> void:
	if player == null:
		return
	GameStateService.set_current_position(player.current_cell())
	GameStateService.set_facing_direction(Vector2(player.facing_dir()))


func verify_gamestate_sync() -> bool:
	return GameStateService.get_current_map_id() == get_active_map_id()


# --- Internos ---

func _strip_embedded_players(root: Node) -> void:
	for child in root.get_children():
		if child is Player3D:
			root.remove_child(child)
			child.free()
		else:
			_strip_embedded_players(child)


func _inject_context_to_events(root: Node) -> void:
	for child in root.get_children():
		if child is Event3D:
			(child as Event3D).set_overworld_context(context)
		_inject_context_to_events(child)
