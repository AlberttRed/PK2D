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
## TODO: Implementar la lógica completa de cambio de mapa
func _execute_warp(map_id: String, spawn_id: String) -> void:
	print("WarpSystem: Ejecutando warp - Mapa: ", map_id, ", Spawn: ", spawn_id)
	
	is_warping = true
	
	# TODO: Aquí se implementará la lógica completa:
	# 1. Cargar el nuevo mapa si es diferente
	# 2. Posicionar al jugador en el spawn point correspondiente
	# 3. Actualizar referencias y sistemas
	
	# Por ahora, simular el proceso
	await get_tree().create_timer(0.1).timeout
	
	# Actualizar estado
	current_map_id = map_id
	current_spawn_id = spawn_id
	is_warping = false
	
	# Emitir señal de finalización
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
