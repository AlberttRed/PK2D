extends Node
class_name WarpSystem

## WarpSystem - Sistema global para gestionar cambios de mapa/posición
## Escucha las peticiones de warp del SignalManager y ejecuta los cambios correspondientes

signal warp_started(map_id: String, spawn_id: String)
signal warp_finished(map_id: String, spawn_id: String)

# Referencias a otros sistemas
@onready var map_system: Node = get_parent().get_node("MapSystem")
@onready var player: Node = map_system.get_node("Player")

# Variables del estado actual
var is_warping: bool = false
var current_map_id: String = ""
var current_spawn_id: String = ""

func _ready() -> void:
	# Conectar con las señales del SignalManager
	if SignalManager:
		SignalManager.warp_requested.connect(_on_warp_requested)
		print("WarpSystem: Conectado a SignalManager.warp_requested")
	else:
		push_error("WarpSystem: SignalManager no encontrado")
	
	print("WarpSystem: Sistema de warp inicializado")

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
	var spawn_success = map_system.position_player_at_spawn(spawn_id)
	if not spawn_success:
		push_warning("WarpSystem: No se pudo posicionar al jugador en el spawn: " + spawn_id)
	
	# 3. Actualizar el estado del juego
	GameStateManager.change_map(map_id, spawn_id)
	
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
	return not is_warping and map_system != null and player != null
