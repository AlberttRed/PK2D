extends Node
class_name TileEffectSystem

const ReflectionEffectHandler = preload("res://Scripts/Overworld/Systems/TileEffects/ReflectionEffectHandler.gd")

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
# Futuro: @export var sand_footprint_scene: PackedScene

# Estado temporal para detectar colisiones
var _tile_before_step: Vector2i = Vector2i(-9999, -9999)


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

	# TODO: Conectar también a NPCs activos


## Registra todos los handlers de efectos
func _register_effect_handlers() -> void:
	var grass_handler = GrassEffectHandler.new(self)
	grass_handler.setup_effects(grass_effect_scene, tall_grass_overlay_scene, grass_stepped_effect_scene)
	effect_handlers["grass"] = grass_handler

	var ripple_handler = RippleEffectHandler.new(self)
	ripple_handler.setup_effects(ripple_effect_scene)
	effect_handlers["water"] = ripple_handler

	# ReflectionEffectHandler maneja reflejos en agua (comparte "water" con ripple)
	# Se registra después para que tenga prioridad en on_step_started_to_tile
	var reflection_handler = ReflectionEffectHandler.new(self)
	effect_handlers["water_reflection"] = reflection_handler


## Obtiene el handler para un tipo de terreno
func get_handler_for_terrain(terrain_type: String) -> TileEffectHandler:
	return effect_handlers.get(terrain_type, null)


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

	# Si salimos de un tile con efectos
	if from_data.grid and from_data.info.terrain != "ground":
		var handler = get_handler_for_terrain(from_data.info.terrain)
		if handler:
			handler.on_step_exited_tile(from_data.grid, from_data.tile, actor)

		# También llamar al reflection handler si es agua
		if from_data.info.terrain == "water":
			var reflection_handler = effect_handlers.get("water_reflection")
			if reflection_handler:
				reflection_handler.on_step_exited_tile(from_data.grid, from_data.tile, actor)

	# Manejar entrada al tile destino
	if to_data.grid:
		_handle_movement_to_destination(to_data.grid, to_data.tile, actor)


## Se ejecuta cuando un actor TERMINA un paso
func _on_actor_step_finished(tile: Vector2i, actor: Node2D) -> void:
	var active_grid = world_system.get_active_grid()
	if not active_grid:
		return

	var tile_info = active_grid.get_tile_info(tile)
	var terrain_type = tile_info.terrain

	if terrain_type == "ground" or terrain_type.is_empty():
		_clear_all_handlers(actor)
		return

	var handler = get_handler_for_terrain(terrain_type)
	if handler:
		var grid_motion = actor.get_node("GridMotion")
		var had_collision = (tile == _tile_before_step) and not grid_motion.initial_step
		handler.on_step_finished_on_tile(active_grid, tile, actor, had_collision)

	# También llamar al reflection handler si es agua
	if terrain_type == "water":
		var reflection_handler = effect_handlers.get("water_reflection")
		if reflection_handler:
			var grid_motion = actor.get_node("GridMotion")
			var had_collision = (tile == _tile_before_step) and not grid_motion.initial_step
			reflection_handler.on_step_finished_on_tile(active_grid, tile, actor, had_collision)

	if actor.is_in_group("Player") and not tile_info.encounter_type.is_empty():
		tile_effect_triggered.emit(tile, tile_info.encounter_type, actor)


## Maneja el movimiento hacia un tile de destino
func _handle_movement_to_destination(grid: OverworldGrid, destination_tile: Vector2i, actor: Node2D) -> void:
	var terrain_type = grid.get_tile_info(destination_tile).terrain
	var handler = get_handler_for_terrain(terrain_type)
	if handler and terrain_type != "ground":
		handler.on_step_started_to_tile(grid, destination_tile, actor)

	# También llamar al reflection handler si es agua
	if terrain_type == "water":
		var reflection_handler = effect_handlers.get("water_reflection")
		if reflection_handler:
			reflection_handler.on_step_started_to_tile(grid, destination_tile, actor)

	# También llamar al reflection handler si es agua
	if terrain_type == "water":
		var reflection_handler = effect_handlers.get("water_reflection")
		if reflection_handler:
			reflection_handler.on_step_started_to_tile(grid, destination_tile, actor)


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

	var grid_motion = player.get_node_or_null("GridMotion")
	if not grid_motion or grid_motion.step_finished.is_connected(_on_actor_step_finished):
		return

	grid_motion.step_finished.connect(_on_actor_step_finished.bind(player))
	grid_motion.step_started.connect(_on_actor_step_started.bind(player))


## Agrega un efecto a la escena (método helper compartido)
func _add_effect_to_scene(effect: Node2D) -> void:
	var parent = get_parent()
	(parent if parent else get_tree().root).add_child(effect)
