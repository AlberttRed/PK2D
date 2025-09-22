extends Node
class_name WarpSystem

## WarpSystem - Sistema global para gestionar cambios de mapa/posición
## Escucha las peticiones de warp del SignalManager y ejecuta los cambios correspondientes

signal warp_started(map_id: String, spawn_id: String)
signal warp_finished(map_id: String, spawn_id: String)

# Referencias a otros sistemas (obtenidas dinámicamente)
var map_system: Node = null
var player: Node = null

# Variables del estado actual
var is_warping: bool = false
var current_map_id: String = ""
var current_spawn_id: String = ""

func _ready() -> void:
	# Obtener referencias dinámicamente
	_update_references()
	
	# Conectar con las señales del SignalManager
	if SignalManager:
		SignalManager.warp_requested.connect(_on_warp_requested)
		print("WarpSystem: Conectado a SignalManager.warp_requested")
	else:
		push_error("WarpSystem: SignalManager no encontrado")
	
	print("WarpSystem: Sistema de warp inicializado")

## Actualiza las referencias a otros sistemas
func _update_references() -> void:
	# Obtener MapSystem por grupo
	map_system = get_tree().get_first_node_in_group("MapSystem")
	if not map_system:
		push_warning("WarpSystem: No se encontró el MapSystem")
		return
	
	# Obtener Player a través del MapSystem
	player = map_system.get_player()
	if not player:
		push_warning("WarpSystem: No se encontró el jugador (puede cargarse más tarde)")

## Método público para solicitar un warp
func request_warp(map_id: String, spawn_id: String) -> void:
	print("WarpSystem: Solicitud de warp recibida - Mapa: ", map_id, ", Spawn: ", spawn_id)
	
	if is_warping:
		push_warning("WarpSystem: Ya hay un warp en progreso, ignorando solicitud")
		return
	
	# Emitir señal de inicio
	warp_started.emit(map_id, spawn_id)
	if SignalManager:
		SignalManager.warp_started.emit(map_id, spawn_id)
	
	# Ejecutar el cambio de mapa/posición
	_execute_warp(map_id, spawn_id)

## Maneja las peticiones de warp desde el SignalManager
func _on_warp_requested(map_id: String, spawn_id: String) -> void:
	request_warp(map_id, spawn_id)

## Ejecuta el cambio de mapa/posición
func _execute_warp(map_id: String, spawn_id: String) -> void:
	print("WarpSystem: Ejecutando warp - Mapa: ", map_id, ", Spawn: ", spawn_id)
	
	is_warping = true
	
	# 0. Actualizar referencias antes de ejecutar el warp
	_update_references()
	
	# Verificar que tenemos las referencias necesarias
	if not map_system:
		push_error("WarpSystem: No se pudo obtener el MapSystem")
		is_warping = false
		return
	
	# 1. Verificar si necesitamos cambiar de mapa
	var current_map = map_system.get_active_map()
	var needs_map_change = not current_map or current_map.name != map_id
	
	if needs_map_change:
		print("WarpSystem: Cambiando de mapa a: ", map_id)
		var success = map_system.change_to_map(map_id)
		if not success:
			push_error("WarpSystem: No se pudo cambiar al mapa: " + map_id)
			is_warping = false
			return
	
	# 2. Posicionar al jugador en el spawn point correspondiente
	print("WarpSystem: Posicionando jugador en spawn: ", spawn_id)
	var grid = map_system.get_active_grid()
	if not grid:
		push_error("WarpSystem: No se pudo obtener el OverworldGrid del mapa activo")
		is_warping = false
		return
	
	var spawn_success = grid.position_player_at_spawn(spawn_id)
	if not spawn_success:
		push_warning("WarpSystem: No se pudo posicionar al jugador en el spawn: " + spawn_id)
	
	# 4. Actualizar estado interno
	current_map_id = map_id
	current_spawn_id = spawn_id
	is_warping = false
	
	# 5. Emitir señal de finalización
	warp_finished.emit(map_id, spawn_id)
	if SignalManager:
		SignalManager.warp_finished.emit(map_id, spawn_id)
	
	print("WarpSystem: Warp completado - Mapa: ", map_id, ", Spawn: ", spawn_id)

## Obtiene información del estado actual
func get_current_warp_info() -> Dictionary:
	return {
		"map_id": current_map_id,
		"spawn_id": current_spawn_id,
		"is_warping": is_warping
	}

## Verifica si el sistema está listo para realizar warps
func is_ready() -> bool:
	# Actualizar referencias antes de verificar
	_update_references()
	return not is_warping and map_system != null
