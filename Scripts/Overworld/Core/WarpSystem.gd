extends Node
class_name WarpSystem

## WarpSystem - Sistema global para gestionar cambios de mapa/posición
## Escucha las peticiones de warp del SignalManager y ejecuta los cambios correspondientes

signal warp_started(map_id: String, spawn_id: String)
signal warp_finished(map_id: String, spawn_id: String)

# Referencias a otros sistemas (inyectadas desde OverworldCoordinator)
# NO usar get_tree().get_first_node_in_group() - usar inyección de dependencias
var map_system: MapSystem = null
var world_system: WorldSystem = null

# Variables del estado actual
var is_warping: bool = false
var current_map_id: String = ""
var current_spawn_id: String = ""

func _ready() -> void:
	# Las referencias se inyectan desde OverworldCoordinator
	# Verificar que las tenemos (se ejecutará después de la inyección)
	await get_tree().process_frame
	
	if not map_system or not world_system:
		push_warning("WarpSystem: Dependencias no inyectadas correctamente. Intentando fallback...")
		_update_references()
	
	# Conectar con las señales del SignalManager
	if SignalManager:
		SignalManager.warp_requested.connect(_on_warp_requested)
		print("WarpSystem: Conectado a SignalManager.warp_requested")
	else:
		push_error("WarpSystem: SignalManager no encontrado")
	
	print("WarpSystem: Sistema de warp inicializado")

## Actualiza las referencias a otros sistemas (FALLBACK - no recomendado)
## Las dependencias deberían ser inyectadas por OverworldCoordinator
func _update_references() -> void:
	# Solo ejecutar si las referencias no fueron inyectadas
	if not map_system:
		map_system = get_tree().get_first_node_in_group("MapSystem")
		if map_system:
			push_warning("WarpSystem: MapSystem detectado por fallback. Debería ser inyectado.")
	
	if not world_system:
		world_system = get_tree().get_first_node_in_group("WorldSystem")
		if world_system:
			push_warning("WarpSystem: WorldSystem detectado por fallback. Debería ser inyectado.")

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
	
	# 0. CRÍTICO: Detener completamente cualquier movimiento en curso
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("GridMotion"):
		var motion = player.get_node("GridMotion")
		if motion:
			# Si está en movimiento, esperar que termine
			if motion.moving:
				print("WarpSystem: Esperando a que termine el paso actual...")
				await motion.step_finished
				print("WarpSystem: Paso completado")
			
			# Detener completamente el movimiento (cancela tweens, resetea estado)
			if motion.has_method("stop_movement"):
				motion.stop_movement()
			
			print("WarpSystem: Movimiento detenido, continuando warp")
	
	# 1. Actualizar referencias antes de ejecutar el warp
	_update_references()
	
	# Verificar que tenemos las referencias necesarias
	if not map_system:
		push_error("WarpSystem: No se pudo obtener el MapSystem")
		is_warping = false
		return
	
	if not world_system:
		push_error("WarpSystem: No se pudo obtener el WorldSystem")
		is_warping = false
		return
	
	# 1. Verificar si necesitamos cambiar de mapa
	var current_map = map_system.get_active_map()
	var needs_map_change = not current_map or current_map.name != map_id
	
	if needs_map_change:
		print("WarpSystem: Cambiando de mapa a través de WorldSystem: ", map_id)
		
		# Usar gestión de estado avanzada para interiores (PBI 374)
		if world_system.has_method("warp_with_state_management"):
			var success = await world_system.warp_with_state_management(map_id, spawn_id)
			if not success:
				push_error("WarpSystem: No se pudo cambiar al mapa con gestión de estado: " + map_id)
				is_warping = false
				return
			# Si el warp con gestión de estado se completó, salir temprano
			_emit_warp_finished(map_id, spawn_id)
			return
		else:
			# Fallback al método tradicional
			var success = world_system.change_to_map(map_id)
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

	# Emitir warp_finished de forma diferida (siguiente frame) para que los comandos puedan await correctamente
	call_deferred("_emit_warp_finished", map_id, spawn_id)
	return

## Emisión diferida de warp_finished para evitar carreras con await en comandos
func _emit_warp_finished(map_id: String, spawn_id: String) -> void:
	# Marcar que ya no estamos warpeando justo antes de emitir
	is_warping = false
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
	return not is_warping and map_system != null and world_system != null
