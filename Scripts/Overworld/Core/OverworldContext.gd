extends Node
class_name OverworldContext

## OverworldContext - Registro local de sistemas del Overworld
##
## Este contexto centraliza el acceso a los sistemas del Overworld,
## eliminando la necesidad de usar get_tree().get_node_in_group()
## y reduciendo el acoplamiento global.
##
## Responsabilidades:
## - Registrar sistemas del Overworld (MapSystem, WarpSystem, MOSystem, etc.)
## - Proveer acceso tipado y seguro a los sistemas
## - Facilitar la inyección de dependencias entre sistemas
##
## Uso:
##   var player = context.get_player()
##   var map_system = context.get_system("Map")
##

# Diccionario de sistemas registrados
var systems := {}

# Referencias directas para acceso rápido y tipado
var map_system: MapSystem = null
var warp_system: WarpSystem = null
var mo_system: MOSystem = null
var event_system: EventSystem = null
var world_system: WorldSystem = null
var player: Node = null
var overlay_layer: OverlayLayer = null

# === Señales locales del Overworld ===
signal event_requested(event)
signal event_started(event)
signal event_finished(event)

signal warp_started(map_id, spawn_id)
signal warp_finished(map_id, spawn_id)

signal seamless_map_crossed(from_map_id, to_map_id)
signal active_grid_changed(grid)

signal player_control_blocked()
signal player_control_unblocked()

signal mo_requested(mo_type, target)
signal mo_finished(mo_type, success, reason)

## Registra un sistema en el contexto
## @param sys_name: Nombre identificador del sistema (ej: "Map", "Warp", "MO")
## @param system: Instancia del sistema a registrar
func register_system(sys_name: String, system: Node) -> void:
	if sys_name.is_empty():
		push_error("OverworldContext: No se puede registrar un sistema sin nombre")
		return

	if not system:
		push_error("OverworldContext: No se puede registrar un sistema nulo: %s" % sys_name)
		return

	systems[sys_name] = system

	# Actualizar referencias directas para acceso tipado
	match sys_name:
		"Map":
			map_system = system as MapSystem
		"Warp":
			warp_system = system as WarpSystem
		"MO":
			mo_system = system as MOSystem
		"Event":
			event_system = system as EventSystem
		"World":
			world_system = system as WorldSystem
		"Player":
			player = system
		"Overlay":
			overlay_layer = system as OverlayLayer

	print("OverworldContext: Sistema registrado → %s (%s)" % [sys_name, system.name])

## Obtiene un sistema registrado por su nombre
## @param sys_name: Nombre del sistema (ej: "Map", "Warp")
## @return: Instancia del sistema o null si no existe
func get_system(sys_name: String) -> Node:
	if not systems.has(sys_name):
		push_warning("OverworldContext: Sistema no registrado: %s" % sys_name)
		return null
	return systems.get(sys_name)

## Obtiene el MapSystem (acceso directo tipado)
func get_map_system() -> MapSystem:
	return map_system

## Obtiene el WarpSystem (acceso directo tipado)
func get_warp_system() -> WarpSystem:
	return warp_system

## Obtiene el MOSystem (acceso directo tipado)
func get_mo_system() -> MOSystem:
	return mo_system

## Obtiene el EventSystem (acceso directo tipado)
func get_event_system() -> EventSystem:
	return event_system

## Obtiene el WorldSystem (acceso directo tipado)
func get_world_system() -> WorldSystem:
	return world_system

## Obtiene la capa de overlays (OverlayLayer)
func get_overlay_layer() -> OverlayLayer:
	return overlay_layer

## Obtiene el Player (acceso directo)
func get_player() -> Node:
	return player

## Verifica si un sistema está registrado
## @param sys_name: Nombre del sistema
## @return: true si está registrado, false en caso contrario
func has_system(sys_name: String) -> bool:
	return systems.has(sys_name)

## Obtiene todos los nombres de sistemas registrados
## @return: Array de nombres de sistemas
func get_registered_systems() -> Array:
	return systems.keys()

## Valida que todos los sistemas críticos estén registrados
## @return: true si todos los sistemas críticos están presentes
func validate() -> bool:
	var required_systems := ["Map", "Warp", "MO", "Event", "World"]
	var all_ok := true

	for sys_name in required_systems:
		if not has_system(sys_name):
			push_error("OverworldContext: Sistema crítico no registrado: %s" % sys_name)
			all_ok = false

	if not player:
		push_warning("OverworldContext: Player no registrado (puede cargarse dinámicamente)")

	return all_ok

## Imprime un resumen de los sistemas registrados (útil para debug)
func print_summary() -> void:
	print("OverworldContext: Sistemas registrados (%d):" % systems.size())
	for sys_name in systems.keys():
		var system = systems[sys_name]
		var type_name = system.get_class() if system else "null"
		print("  ✓ %s → %s (%s)" % [sys_name, system.name if system else "null", type_name])

		# Configurar conexiones de señales locales
		_connect_system_signals(sys_name, system)

## Conecta las señales locales de un sistema registrado al contexto
func _connect_system_signals(sys_name: String, system: Node) -> void:
	match sys_name:
		"Event":
			if system is EventSystem:
				if not system.event_started.is_connected(_on_event_started):
					system.event_started.connect(_on_event_started)
				if not system.event_finished.is_connected(_on_event_finished):
					system.event_finished.connect(_on_event_finished)
				if not system.event_requested.is_connected(_on_event_requested):
					system.event_requested.connect(_on_event_requested)
		"Warp":
			if system is WarpSystem:
				if not system.warp_started.is_connected(_on_warp_started):
					system.warp_started.connect(_on_warp_started)
				if not system.warp_finished.is_connected(_on_warp_finished):
					system.warp_finished.connect(_on_warp_finished)
		"MO":
			if system is MOSystem:
				if not system.mo_requested.is_connected(_on_mo_requested):
					system.mo_requested.connect(_on_mo_requested)
				if not system.mo_finished.is_connected(_on_mo_finished):
					system.mo_finished.connect(_on_mo_finished)

## Wrapper público para solicitar ejecución de eventos
func request_event(event: Event) -> void:
	if event_system:
		event_system.request_event(event)
	else:
		push_error("OverworldContext: EventSystem no disponible para request_event()")

## Wrapper público para solicitar un warp
func request_warp(map_id: String, spawn_id: String) -> void:
	if not warp_system:
		push_error("OverworldContext: WarpSystem no disponible para request_warp()")
		return
	await warp_system.request_warp(map_id, spawn_id)

## Wrapper público para solicitar uso de una MO
func request_mo(mo_type: String, target: Node) -> Dictionary:
	if not mo_system:
		push_error("OverworldContext: MOSystem no disponible para request_mo()")
		return {"success": false, "error": "MOSystem no disponible"}
	return await mo_system.request_mo(mo_type, target)

## Emite el cambio de grid activo a todos los interesados
func emit_active_grid_changed(grid: OverworldGrid) -> void:
	active_grid_changed.emit(grid)

## Emite el cruce seamless entre mapas
func emit_seamless_map_crossed(from_map_id: String, to_map_id: String) -> void:
	seamless_map_crossed.emit(from_map_id, to_map_id)

## Bloquea el control del jugador
func block_player_control() -> void:
	if player and player.has_method("block_controls"):
		player.block_controls()
	player_control_blocked.emit()

## Desbloquea el control del jugador
func unblock_player_control() -> void:
	if player and player.has_method("unblock_controls"):
		player.unblock_controls()
	player_control_unblocked.emit()

## Callbacks internos para reenviar señales locales
func _on_event_requested(event) -> void:
	event_requested.emit(event)

func _on_event_started(event) -> void:
	event_started.emit(event)

func _on_event_finished(event) -> void:
	event_finished.emit(event)

func _on_warp_started(map_id, spawn_id) -> void:
	warp_started.emit(map_id, spawn_id)

func _on_warp_finished(map_id, spawn_id) -> void:
	warp_finished.emit(map_id, spawn_id)

func _on_mo_requested(mo_type, target) -> void:
	mo_requested.emit(mo_type, target)

func _on_mo_finished(mo_type, success, reason) -> void:
	mo_finished.emit(mo_type, success, reason)
