extends Node
class_name OverworldCoordinator

## OverworldCoordinator - Gestor principal del overworld
## Coordina las dependencias entre WorldSystem, MapSystem, EventSystem, etc.
## Utiliza OverworldContext para reducir acoplamiento y eliminar búsquedas globales
##
## Responsabilidades:
## - Crear y configurar el OverworldContext
## - Registrar todos los sistemas en el contexto
## - Inyectar el contexto a los sistemas que lo necesiten
## - Coordinar la inicialización de todos los sistemas
## - Proveer acceso centralizado a los sistemas del overworld

@onready var world_system: WorldSystem = $WorldSystem
@onready var map_system: MapSystem = $MapSystem
@onready var event_system: EventSystem = $EventSystem
@onready var warp_system: WarpSystem = $WarpSystem
@onready var mo_system: MOSystem = $MOSystem

# Contexto compartido entre sistemas del Overworld
var context: OverworldContext = null

func _ready() -> void:
	print("OverworldCoordinator: Inicializando sistemas del overworld...")

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

	print("OverworldCoordinator: Todos los sistemas inicializados y conectados")


## Registra todos los sistemas en el OverworldContext
func _register_systems_in_context() -> void:
	print("OverworldCoordinator: Registrando sistemas en el contexto...")

	# Registrar sistemas principales
	if world_system:
		context.register_system("World", world_system)

	if map_system:
		context.register_system("Map", map_system)

	if event_system:
		context.register_system("Event", event_system)

	if warp_system:
		context.register_system("Warp", warp_system)

	if mo_system:
		context.register_system("MO", mo_system)

	# El Player se registrará dinámicamente cuando MapSystem lo cargue
	print("OverworldCoordinator: Player se cargará dinámicamente desde MapSystem")

	print("OverworldCoordinator: Registro de sistemas completado")

## Inyecta las referencias necesarias entre sistemas
## Este es el único lugar donde se establecen las conexiones entre sistemas
func _inject_dependencies() -> void:
	print("OverworldCoordinator: Inyectando dependencias entre sistemas...")

	# Inyectar el contexto a todos los sistemas
	if map_system:
		if map_system.has_method("set_context"):
			map_system.set_context(context)
		else:
			map_system.context = context
		# Mantener compatibilidad temporal con world_system directo
		map_system.world_system = world_system
		print("  ✓ Context → MapSystem")

	if world_system:
		if world_system.has_method("set_context"):
			world_system.set_context(context)
		else:
			world_system.context = context
		# Mantener compatibilidad temporal con map_system directo
		world_system.map_system = map_system
		print("  ✓ Context → WorldSystem")

	if warp_system:
		if warp_system.has_method("set_context"):
			warp_system.set_context(context)
		else:
			warp_system.context = context
		# Mantener compatibilidad temporal
		warp_system.world_system = world_system
		warp_system.map_system = map_system
		print("  ✓ Context → WarpSystem")

	if mo_system:
		if mo_system.has_method("set_context"):
			mo_system.set_context(context)
		else:
			mo_system.context = context
		print("  ✓ Context → MOSystem")

	if event_system:
		if event_system.has_method("set_context"):
			event_system.set_context(context)
		else:
			event_system.context = context
		print("  ✓ Context → EventSystem")

	print("OverworldCoordinator: Inyección de dependencias completada")


## Métodos de utilidad para obtener sistemas específicos
## DEPRECATED: Usar context.get_system() en su lugar

func get_world_system() -> WorldSystem:
	return world_system

func get_map_system() -> MapSystem:
	return map_system

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

	if not map_system:
		push_error("OverworldCoordinator: MapSystem no encontrado")
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
## Este método de alto nivel orquesta WorldSystem y MapSystem para:
## - Cargar el mapa correcto
## - Crear el jugador
## - Posicionarlo en las coordenadas guardadas
##
## Flujo:
## GameStart → OverworldCoordinator.configure_from_gamestate()
##   ├→ WorldSystem.change_to_map(map_id)
##   │   └→ MapSystem.change_to_map_instance()
##   ├→ MapSystem.load_player()
##   └→ Posicionar jugador vía OverworldGrid
func configure_from_gamestate() -> bool:
	print("OverworldCoordinator: Iniciando configuración desde GameState...")

	# Verificar que tenemos los sistemas necesarios
	if not world_system or not map_system:
		push_error("OverworldCoordinator: Sistemas no disponibles para configuración")
		return false

	# Obtener datos del GameStateService
	var map_id = GameStateService.get_current_map_id()
	var position = GameStateService.get_current_position()
	var facing_dir = GameStateService.get_facing_direction()

	print("OverworldCoordinator: Configurando - Mapa: %s, Posición: %s, Dirección: %s" % [map_id, position, facing_dir])

	# 1. Cambiar al mapa correcto (vía WorldSystem)
	print("OverworldCoordinator: Cargando mapa '%s'..." % map_id)
	var success = world_system.change_to_map(map_id)
	if not success:
		push_error("OverworldCoordinator: No se pudo cargar el mapa: " + map_id)
		return false

	# 2. Cargar el jugador si no existe (vía MapSystem)
	if not map_system.player:
		print("OverworldCoordinator: Cargando jugador...")
		success = map_system.load_player()
		if not success:
			push_error("OverworldCoordinator: No se pudo cargar el jugador")
			return false
	else:
		print("OverworldCoordinator: Jugador ya existe")

	# 3. Posicionar al jugador en las coordenadas guardadas
	print("OverworldCoordinator: Posicionando jugador...")
	var grid = map_system.get_active_grid()
	if not grid:
		push_error("OverworldCoordinator: No se pudo obtener el OverworldGrid")
		return false

	var player = map_system.get_player()
	if not player:
		push_error("OverworldCoordinator: Player no disponible")
		return false

	grid.position_player_at_tile(position, player)
	grid.set_player_facing_direction(facing_dir, player)

	print("OverworldCoordinator: ✓ Configuración desde GameState completada exitosamente")
	return true
