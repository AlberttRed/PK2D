extends Node
class_name OverworldCoordinator

## OverworldCoordinator - Gestor principal del overworld
## Coordina las dependencias entre WorldSystem, MapSystem, EventSystem, etc.
## Sigue el principio de Dependency Injection para evitar acoplamientos indeseados
##
## Responsabilidades:
## - Inyectar referencias entre sistemas hermanos
## - Coordinar la inicialización de todos los sistemas
## - Proveer acceso centralizado a los sistemas del overworld

@onready var world_system: WorldSystem = $WorldSystem
@onready var map_system: MapSystem = $MapSystem
@onready var event_system: EventSystem = $EventSystem
@onready var warp_system: WarpSystem = $WarpSystem

func _ready() -> void:
	print("OverworldCoordinator: Inicializando sistemas del overworld...")
	
	# Esperar a que todos los nodos hijos completen su _ready()
	await get_tree().process_frame
	
	# Inyectar dependencias (el padre conoce a todos sus hijos)
	_inject_dependencies()
	
	print("OverworldCoordinator: Todos los sistemas inicializados y conectados")


## Inyecta las referencias necesarias entre sistemas
## Este es el único lugar donde se establecen las conexiones entre sistemas
func _inject_dependencies() -> void:
	print("OverworldCoordinator: Inyectando dependencias entre sistemas...")
	
	# MapSystem necesita WorldSystem para delegar carga de mapas
	if map_system and world_system:
		map_system.world_system = world_system
		print("  ✓ WorldSystem → MapSystem")
	
	# WorldSystem necesita MapSystem para activar mapas
	if world_system and map_system:
		world_system.map_system = map_system
		print("  ✓ MapSystem → WorldSystem")
	
	# WarpSystem necesita WorldSystem y MapSystem
	if warp_system:
		if world_system:
			warp_system.world_system = world_system
			print("  ✓ WorldSystem → WarpSystem")
		if map_system:
			warp_system.map_system = map_system
			print("  ✓ MapSystem → WarpSystem")
	
	print("OverworldCoordinator: Inyección de dependencias completada")


## Métodos de utilidad para obtener sistemas específicos
## Útiles para otros scripts que necesiten acceder a los sistemas del overworld

func get_world_system() -> WorldSystem:
	return world_system

func get_map_system() -> MapSystem:
	return map_system

func get_event_system() -> EventSystem:
	return event_system

func get_warp_system() -> WarpSystem:
	return warp_system


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

## Configura el overworld según el estado del GameStateManager
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
	
	# Obtener datos del GameStateManager
	var map_id = GameStateManager.get_current_map_id()
	var position = GameStateManager.get_current_position()
	var facing_dir = GameStateManager.get_facing_direction()
	
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
	
	grid.position_player_at_tile(position)
	grid.set_player_facing_direction(facing_dir)
	
	print("OverworldCoordinator: ✓ Configuración desde GameState completada exitosamente")
	return true
