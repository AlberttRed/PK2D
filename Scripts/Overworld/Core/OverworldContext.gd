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

