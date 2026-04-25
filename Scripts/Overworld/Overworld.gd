extends Node
class_name OverworldCoordinator

## OverworldCoordinator - Gestor principal del overworld
## Coordina las dependencias entre WorldSystem, EventSystem, etc.
## Utiliza OverworldContext para reducir acoplamiento y eliminar búsquedas globales
##
## Responsabilidades:
## - Crear y configurar el OverworldContext
## - Registrar todos los sistemas en el contexto
## - Inyectar el contexto a los sistemas que lo necesiten
## - Coordinar la inicialización de todos los sistemas
## - Proveer acceso centralizado a los sistemas del overworld

@onready var world_system: WorldSystem = $WorldSystem
@onready var event_system: EventSystem = $EventSystem
@onready var warp_system: WarpSystem = $WarpSystem
@onready var mo_system: MOSystem = $MOSystem
@onready var tile_effect_system: TileEffectSystem = $TileEffectSystem
@onready var tile_motion_system: TileMotionSystem = $TileMotionSystem
@onready var wild_encounter_system: WildEncounterSystem = $WildEncounterSystem

# Contexto compartido entre sistemas del Overworld
var context: OverworldContext = null

func _ready() -> void:
	# Crear el contexto antes de la inicialización
	context = OverworldContext.new()
	context.name = "OverworldContext"
	add_child(context)

	# Esperar a que todos los nodos hijos completen su _ready()
	await get_tree().process_frame

	# Registrar sistemas en el contexto
	_register_systems_in_context()

	# Inyectar dependencias (el padre conoce a todos sus hijos)
	_inject_dependencies()

	# Validar el contexto
	context.validate()
	context.print_summary()


## Registra todos los sistemas en el OverworldContext
func _register_systems_in_context() -> void:
	# Registrar sistemas principales
	if world_system:
		context.register_system("World", world_system)

	if event_system:
		context.register_system("Event", event_system)

	if warp_system:
		context.register_system("Warp", warp_system)

	if mo_system:
		context.register_system("MO", mo_system)

	if tile_effect_system:
		context.register_system("TileEffect", tile_effect_system)

	if tile_motion_system:
		context.register_system("TileMotion", tile_motion_system)

	if wild_encounter_system:
		context.register_system("WildEncounter", wild_encounter_system)

	var overlay_layer := DisplayManager.get_overlay_layer()
	if overlay_layer:
		context.register_system("Overlay", overlay_layer)

	# Obtener la capa de efectos desde WorldSystem
	var effects_layer = world_system.get_effects_layer() if world_system else null
	if effects_layer:
		context.register_system("EffectsLayer", effects_layer)

	# El Player se registrará dinámicamente cuando WorldSystem lo cargue

## Inyecta las referencias necesarias entre sistemas
## Este es el único lugar donde se establecen las conexiones entre sistemas
func _inject_dependencies() -> void:
	# Inyectar el contexto a todos los sistemas
	if world_system:
		if world_system.has_method("set_context"):
			world_system.set_context(context)
		else:
			world_system.context = context

	if warp_system:
		if warp_system.has_method("set_context"):
			warp_system.set_context(context)
		else:
			warp_system.context = context
		# Mantener compatibilidad temporal
		warp_system.world_system = world_system

	if mo_system:
		if mo_system.has_method("set_context"):
			mo_system.set_context(context)
		else:
			mo_system.context = context

	var overlay_layer := context.get_overlay_layer()
	if overlay_layer and overlay_layer.has_method("set_context"):
		overlay_layer.set_context(context)
		if world_system and world_system.has_method("refresh_overlay_settings"):
			world_system.refresh_overlay_settings()

	if event_system:
		if event_system.has_method("set_context"):
			event_system.set_context(context)
		else:
			event_system.context = context

	if tile_effect_system:
		if tile_effect_system.has_method("initialize"):
			tile_effect_system.initialize(context)

	if tile_motion_system:
		if tile_motion_system.has_method("initialize"):
			tile_motion_system.initialize(context)

	if wild_encounter_system:
		if wild_encounter_system.has_method("initialize"):
			wild_encounter_system.initialize(context)
		# Conectar señal de battle_requested a DisplayManager
		if not wild_encounter_system.battle_requested.is_connected(_on_wild_battle_requested):
			wild_encounter_system.battle_requested.connect(_on_wild_battle_requested)


## Callback cuando WildEncounterSystem solicita un combate
func _on_wild_battle_requested(participants: Array, rules: BattleRules) -> void:
	var winner = await DisplayManager.start_battle(participants, rules)


## Métodos de utilidad para obtener sistemas específicos
## DEPRECATED: Usar context.get_system() en su lugar

func get_world_system() -> WorldSystem:
	return world_system

func get_event_system() -> EventSystem:
	return event_system

func get_warp_system() -> WarpSystem:
	return warp_system

## Obtiene el contexto del Overworld (método preferido)
func get_context() -> OverworldContext:
	return context


## Verifica que todos los sistemas estén correctamente inicializados
func verify_systems() -> bool:
	var all_ok := true

	if not world_system:
		push_error("OverworldCoordinator: WorldSystem no encontrado")
		all_ok = false

	if not event_system:
		push_error("OverworldCoordinator: EventSystem no encontrado")
		all_ok = false

	if not warp_system:
		push_error("OverworldCoordinator: WarpSystem no encontrado")
		all_ok = false

	return all_ok


## ================================================================================
## CONFIGURACIÓN DESDE GAMESTATE
## ================================================================================

## Configura el overworld según el estado del GameStateService
## Este método de alto nivel orquesta WorldSystem para:
## - Cargar el mapa correcto
## - Crear el jugador
## - Posicionarlo en las coordenadas guardadas
##
## Flujo:
## GameStart → OverworldCoordinator.configure_from_gamestate()
##   ├→ WorldSystem.change_to_map(map_id)
##   ├→ WorldSystem.load_player()
##   └→ Posicionar jugador vía OverworldGrid
func configure_from_gamestate() -> bool:
	# Verificar que tenemos los sistemas necesarios
	if not world_system:
		push_error("OverworldCoordinator: WorldSystem no disponible para configuración")
		return false

	# Obtener datos del GameStateService
	var map_id = GameStateService.get_current_map_id()
	var position = GameStateService.get_current_position()
	var facing_dir = GameStateService.get_facing_direction()

	# 1. Cambiar al mapa correcto (vía WorldSystem)
	var success = world_system.change_to_map(map_id)
	if not success:
		push_error("OverworldCoordinator: No se pudo cargar el mapa: " + map_id)
		return false

	# 2. Cargar el jugador si no existe (vía WorldSystem)
	if not world_system.player:
		success = world_system.load_player()
		if not success:
			push_error("OverworldCoordinator: No se pudo cargar el jugador")
			return false

	# 3. Posicionar al jugador en las coordenadas guardadas
	var grid = world_system.get_active_grid()
	if not grid:
		push_error("OverworldCoordinator: No se pudo obtener el OverworldGrid")
		return false

	var player = world_system.get_player()
	if not player:
		push_error("OverworldCoordinator: Player no disponible")
		return false

	grid.position_player_at_tile(position, player)
	grid.set_player_facing_direction(facing_dir, player)
	_sync_indoor_flag_from_active_map()

	return true


func _sync_indoor_flag_from_active_map() -> void:
	var active_map := world_system.get_active_map()
	if active_map == null:
		return
	var map_scene := active_map as MapScene
	if map_scene == null:
		return
	GameStateService.set_event_flag("indoor", map_scene.is_indoor)
