extends Node
class_name EventSystem

## EventSystem - Sistema que gestiona múltiples EventControllers
## Coordina qué EventController está activo y maneja el control del jugador

# Controladores de eventos
var main_controller: EventController = null  # Mapa actual del jugador
var secondary_controllers: Array[EventController] = []  # Mapas vecinos

# Referencias
var player: Node = null
var player_control_blocked_by_events: bool = false

func _ready() -> void:
	# Buscar el jugador
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning("EventSystem: No se encontró el jugador en el grupo 'Player'")
	
	# Conectar señales del SignalManager
	SignalManager.event_requested.connect(_on_event_requested)
	SignalManager.event_system_ready.connect(_on_system_ready)
	SignalManager.message_requested.connect(_on_message_requested)
	SignalManager.message_finished.connect(_on_message_finished)
	
	# Notificar que el sistema está listo
	SignalManager.event_system_ready.emit(self)

##Registra un EventController en el sistema
func register_controller(controller: EventController, is_main: bool = false) -> void:
	if is_main:
		main_controller = controller
		print("EventSystem: Registrado controlador principal para mapa '%s'" % controller.map_node.name)
	else:
		if not secondary_controllers.has(controller):
			secondary_controllers.append(controller)
			print("EventSystem: Registrado controlador secundario para mapa '%s'" % controller.map_node.name)

##Desregistra un EventController del sistema
func unregister_controller(controller: EventController) -> void:
	if main_controller == controller:
		main_controller = null
		print("EventSystem: Desregistrado controlador principal")
	
	secondary_controllers.erase(controller)
	print("EventSystem: Desregistrado controlador secundario")

##Cambia el controlador principal (cuando el jugador cambia de mapa)
func set_main_controller(controller: EventController) -> void:
	if main_controller:
		# Mover el controlador anterior a secundarios si no está ya
		if not secondary_controllers.has(main_controller):
			secondary_controllers.append(main_controller)
	
	main_controller = controller
	secondary_controllers.erase(controller)
	
	print("EventSystem: Nuevo controlador principal: '%s'" % controller.map_node.name)

##Inicia un evento en el controlador apropiado
func start_event(event: Event) -> bool:
	# Determinar qué controlador debe manejar este evento
	var target_controller = get_controller_for_event(event)
	
	if not target_controller:
		print("EventSystem: No se encontró controlador para el evento '%s'" % event.event_name)
		return false
	
	# Solo permitir eventos en el controlador principal
	if target_controller != main_controller:
		print("EventSystem: Evento '%s' ignorado - no está en el mapa principal" % event.event_name)
		return false
	
	# Verificar que no hay otro evento en curso
	if is_any_controller_busy():
		print("EventSystem: Evento '%s' ignorado - ya hay un evento en curso" % event.event_name)
		return false
	
	# Iniciar evento
	return target_controller.start_event(event)

## --- Señales del SignalManager ---
## Maneja solicitudes de eventos desde el SignalManager
func _on_event_requested(event: Event, controller: EventController) -> void:
	start_event(event)

## Maneja notificaciones de sistemas listos
func _on_system_ready(system: Node) -> void:
	if system == self:
		print("EventSystem: Sistema listo y conectado al SignalManager")

## Bloquea el control del jugador cuando se muestra un mensaje
func _on_message_requested(text: String, config: Dictionary) -> void:
	block_player_control()

## Desbloquea el control del jugador cuando termina un mensaje
func _on_message_finished() -> void:
	unblock_player_control()

##Encuentra el controlador responsable de un evento
func get_controller_for_event(event: Event) -> EventController:
	# Buscar en el controlador principal
	if main_controller and is_event_in_controller(event, main_controller):
		return main_controller
	
	# Buscar en controladores secundarios
	for controller in secondary_controllers:
		if is_event_in_controller(event, controller):
			return controller
	
	return null

##Verifica si un evento pertenece a un controlador específico
func is_event_in_controller(event: Event, controller: EventController) -> bool:
	if not controller or not controller.grid:
		return false
	
	# Verificar si el evento está registrado en el grid de este controlador
	var event_tile = controller.grid.world_to_tile(event.global_position)
	var registered_event = controller.grid.event_at(event_tile)
	
	return registered_event == event

##Bloquea el control del jugador
func block_player_control() -> void:
	if not player_control_blocked_by_events:
		player_control_blocked_by_events = true
		if player and player.has_method("set_movement_enabled"):
			player.set_movement_enabled(false)
		SignalManager.player_control_blocked.emit()
		print("EventSystem: Control del jugador bloqueado")

##Desbloquea el control del jugador
func unblock_player_control() -> void:
	if player_control_blocked_by_events:
		player_control_blocked_by_events = false
		if player and player.has_method("set_movement_enabled"):
			player.set_movement_enabled(true)
		SignalManager.player_control_unblocked.emit()
		print("EventSystem: Control del jugador desbloqueado")

## --- Estado del Sistema ---
##Verifica si algún controlador está ejecutando un evento
func is_any_controller_busy() -> bool:
	if main_controller and main_controller.is_busy():
		return true
	
	for controller in secondary_controllers:
		if controller.is_busy():
			return true
	
	return false

##Retorna el controlador que está ejecutando un evento, o null si ninguno
func get_busy_controller() -> EventController:
	if main_controller and main_controller.is_busy():
		return main_controller
	
	for controller in secondary_controllers:
		if controller.is_busy():
			return controller
	
	return null

##Llamado por EventControllers cuando terminan un evento
func on_controller_event_finished(controller: EventController) -> void:
	print("EventSystem: Evento terminado en controlador '%s'" % controller.map_node.name)
	
	# Si era el controlador principal, desbloquear jugador
	if controller == main_controller:
		unblock_player_control()
