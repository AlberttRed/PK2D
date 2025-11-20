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
var chunk_controller: WorldChunkController = null

# Registro de handlers por tipo de terreno
var effect_handlers: Dictionary = {}  # {String: TileEffectHandler}

# Configuración de escenas (se pasan a los handlers)
@export var grass_effect_scene: PackedScene
@export var tall_grass_overlay_scene: PackedScene
@export var grass_stepped_effect_scene: PackedScene
# Futuro: @export var water_ripple_scene: PackedScene
# Futuro: @export var sand_footprint_scene: PackedScene

# Estado temporal para step_started
var _tile_before_step: Vector2i = Vector2i(-9999, -9999)


func _ready() -> void:
	# Intentar conectar al jugador si ya existe
	call_deferred("_connect_to_player")


## Inicializa el sistema con el contexto
func initialize(overworld_context: OverworldContext) -> void:
	context = overworld_context
	world_system = context.get_world_system()
	chunk_controller = world_system.get_chunk_controller()

	# Registrar handlers
	_register_effect_handlers()

	# Conectar a señales del jugador
	_connect_to_player()

	# TODO: Conectar también a NPCs activos


## Registra todos los handlers de efectos
func _register_effect_handlers() -> void:
	# Handler de hierba
	var grass_handler = GrassEffectHandler.new(self)
	grass_handler.setup_effects(
		grass_effect_scene,
		tall_grass_overlay_scene,
		grass_stepped_effect_scene
	)
	effect_handlers["Land"] = grass_handler  # "Land" es el encounter_type

	# Futuro: Handler de agua
	# var water_handler = WaterEffectHandler.new(self)
	# water_handler.setup_effects(water_ripple_scene, surf_trail_scene)
	# effect_handlers["Water"] = water_handler

	# Futuro: Handler de arena (usa terrain, no encounter_type)
	# var sand_handler = SandEffectHandler.new(self)
	# sand_handler.setup_effects(sand_footprint_scene)
	# effect_handlers["sand"] = sand_handler


## Obtiene el handler para un tipo de terreno
func get_handler_for_terrain(terrain_type: String) -> TileEffectHandler:
	return effect_handlers.get(terrain_type)


## Registra un nuevo handler (para extensibilidad)
func register_handler(terrain_type: String, handler: TileEffectHandler) -> void:
	effect_handlers[terrain_type] = handler


## Se ejecuta cuando un actor EMPIEZA un paso
func _on_actor_step_started(actor: Node2D) -> void:
	var active_grid = world_system.get_active_grid()
	if not active_grid:
		return

	_tile_before_step = active_grid.world_to_tile(actor.global_position)
	var grid_motion = actor.get_node_or_null("GridMotion")
	if not grid_motion:
		return

	if not grid_motion.initial_step:
		var destination_tile = _tile_before_step + Vector2i(grid_motion.dir)
		var can_move = active_grid.can_step_to(actor, _tile_before_step, destination_tile)

		if can_move:
			_handle_movement_to_destination(active_grid, destination_tile, actor)


## Se ejecuta cuando un actor TERMINA un paso
func _on_actor_step_finished(tile: Vector2i, actor: Node2D) -> void:
	var active_grid = world_system.get_active_grid()
	if not active_grid:
		return

	# OPTIMIZACIÓN: Solo verificar si el tile está en chunks activos
	var active_map = world_system.get_active_map()
	if not active_map:
		return
	var map_id = active_map.name

	var encounter_type = chunk_controller.get_encounter_type_for_tile(tile, map_id)

	if not encounter_type:
		# No hay encuentro en este tile o chunk no activo
		_clear_all_handlers(actor)
		return

	# Obtener handler para este tipo de terreno
	var handler = get_handler_for_terrain(encounter_type)
	if handler:
		var grid_motion = actor.get_node("GridMotion")
		var had_collision = (tile == _tile_before_step) and not grid_motion.initial_step
		handler.on_step_finished_on_tile(active_grid, tile, actor, had_collision)

	# Emitir señal para WildEncounterSystem (solo si es jugador)
	if actor.is_in_group("Player"):
		tile_effect_triggered.emit(tile, encounter_type, actor)


## Maneja el movimiento hacia un tile de destino
func _handle_movement_to_destination(grid: OverworldGrid, destination_tile: Vector2i, actor: Node2D) -> void:
	var active_map = world_system.get_active_map()
	if not active_map:
		return
	var map_id = active_map.name
	var encounter_type = chunk_controller.get_encounter_type_for_tile(destination_tile, map_id)

	if encounter_type:
		var handler = get_handler_for_terrain(encounter_type)
		if handler:
			handler.on_step_started_to_tile(grid, destination_tile, actor)


## Limpia el estado de todos los handlers
func _clear_all_handlers(actor: Node2D) -> void:
	for handler in effect_handlers.values():
		if handler:
			# Obtener el tile actual del actor
			var active_grid = world_system.get_active_grid()
			if active_grid:
				var current_tile = active_grid.world_to_tile(actor.global_position)
				handler.on_step_exited_tile(active_grid, current_tile, actor)


## Conecta a las señales del jugador
func _connect_to_player() -> void:
	if not context:
		await get_tree().process_frame
		_connect_to_player()
		return

	var player = context.get_player()
	if not player:
		# Reintentar después de un frame
		await get_tree().process_frame
		_connect_to_player()
		return

	var grid_motion = player.get_node_or_null("GridMotion")
	if not grid_motion:
		return

	# Verificar si ya está conectado para evitar duplicados
	if grid_motion.step_finished.is_connected(_on_actor_step_finished):
		return

	grid_motion.step_finished.connect(_on_actor_step_finished.bind(player))
	grid_motion.step_started.connect(_on_actor_step_started.bind(player))


## Agrega un efecto a la escena (método helper compartido)
func _add_effect_to_scene(effect: Node2D) -> void:
	# Añadir el efecto como hijo del Overworld (padre del sistema)
	var overworld = get_parent()
	if overworld:
		overworld.add_child(effect)
	else:
		get_tree().root.add_child(effect)
