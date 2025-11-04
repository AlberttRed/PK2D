extends Node
class_name MOSystem

## MOSystem - Sistema central para gestionar el uso de Máquinas Ocultas (MO)
## Se encarga de:
## - Validar si una MO puede ser usada
## - Ejecutar el efecto lógico de la MO
## - Comunicar el resultado mediante señales
##
## NO gestiona mensajes ni animaciones visuales, eso lo hacen los eventos

# Diccionario de acciones MO disponibles: {"CUT": MOAction, "SURF": MOAction, ...}
var mo_actions: Dictionary = {}

# Estado actual del sistema
var is_processing_mo: bool = false
var current_mo_type: String = ""
var current_target: Node = null

func _ready() -> void:
	# Conectar con el SignalManager para escuchar peticiones de MO
	if SignalManager:
		SignalManager.mo_requested.connect(_on_mo_requested)
		print("MOSystem: Conectado a SignalManager.mo_requested")
	else:
		push_error("MOSystem: SignalManager no encontrado")

	# Inicializar el diccionario de acciones MO
	_initialize_mo_actions()

	print("MOSystem: Sistema de Máquinas Ocultas inicializado con %d MO(s)" % mo_actions.size())

## Inicializa el diccionario de acciones MO disponibles
## Las clases específicas de cada MO se registrarán aquí cuando se implementen
func _initialize_mo_actions() -> void:
	# Registrar MO: CORTE (CUT)
	var cut_action = preload("res://Scripts/Overworld/Core/MOActions/CutAction.gd").new()
	register_mo_action("CUT", cut_action)

	# Aquí se registrarán otras MO cuando se implementen:
	# register_mo_action("SURF", preload("res://Scripts/Overworld/Core/MOActions/SurfAction.gd").new())
	# register_mo_action("STRENGTH", preload("res://Scripts/Overworld/Core/MOActions/StrengthAction.gd").new())

## Registra una nueva acción MO en el sistema
## @param mo_type: Identificador de la MO (ej: "CUT", "SURF")
## @param action: Instancia de MOAction que define el comportamiento
func register_mo_action(mo_type: String, action: Resource) -> void:
	if mo_type.is_empty():
		push_error("MOSystem: No se puede registrar una MO sin tipo")
		return

	if not action:
		push_error("MOSystem: No se puede registrar una acción MO nula")
		return

	mo_actions[mo_type] = action
	print("MOSystem: MO registrada - Tipo: %s, Nombre: %s" % [mo_type, action.get_mo_name()])

## Elimina una acción MO del sistema
## @param mo_type: Identificador de la MO a eliminar
func unregister_mo_action(mo_type: String) -> void:
	if mo_actions.has(mo_type):
		mo_actions.erase(mo_type)
		print("MOSystem: MO desregistrada - Tipo: %s" % mo_type)

## Verifica si una MO está registrada
## @param mo_type: Identificador de la MO
## @return: true si está registrada, false si no
func has_mo_action(mo_type: String) -> bool:
	return mo_actions.has(mo_type)

## Maneja las peticiones de uso de MO desde el SignalManager
## @param mo_type: Tipo de MO solicitada (ej: "CUT", "SURF")
## @param target: Nodo sobre el que se intenta usar la MO
func _on_mo_requested(mo_type: String, target: Node) -> void:
	var target_name = target.name if target else "null"
	print("MOSystem: Petición de MO recibida - Tipo: %s, Target: %s" % [mo_type, target_name])

	# Verificar si ya hay una MO procesándose
	if is_processing_mo:
		push_warning("MOSystem: Ya hay una MO en proceso, ignorando solicitud")
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "Ya hay una MO en proceso")
		return

	# Validar parámetros
	if mo_type.is_empty():
		push_error("MOSystem: Tipo de MO vacío")
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "Tipo de MO vacío")
		return

	if not target:
		push_error("MOSystem: Target nulo")
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "Target nulo")
		return

	# Verificar si la MO está registrada
	if not mo_actions.has(mo_type):
		push_warning("MOSystem: MO '%s' no está registrada (aún no implementada)" % mo_type)
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "MO '%s' no está registrada" % mo_type)
		return

	# Ejecutar la validación y acción
	_process_mo_request(mo_type, target)

## Procesa una petición de MO validando y ejecutando la acción
## @param mo_type: Tipo de MO
## @param target: Nodo target
func _process_mo_request(mo_type: String, target: Node) -> void:
	is_processing_mo = true
	current_mo_type = mo_type
	current_target = target

	# Obtener la acción MO
	var action: Resource = mo_actions[mo_type]

	# Obtener el jugador
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_error("MOSystem: No se encontró el jugador")
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "No se encontró el jugador")
		_reset_state()
		return

	# Validar si se puede usar la MO
	if not action.can_use(player, target):
		print("MOSystem: No se puede usar la MO '%s' en el contexto actual" % mo_type)
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "No se puede usar la MO en el contexto actual")
		_reset_state()
		return

	# Obtener el EventController como context
	var event_system = get_tree().get_first_node_in_group("EventSystem")
	if not event_system or not event_system.controller:
		push_error("MOSystem: No se encontró el EventController")
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "No se encontró el EventController")
		_reset_state()
		return

	var context = event_system.controller

	# Ejecutar el flujo completo de la MO (mensajes, choice, animación, etc.)
	var result: Dictionary = await action.execute(player, target, context)

	# Verificar el resultado y emitir señal unificada
	if result.get("success", false):
		print("MOSystem: MO '%s' ejecutada con éxito" % mo_type)
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, true, "")
	elif result.get("cancelled", false):
		print("MOSystem: MO '%s' cancelada por el jugador" % mo_type)
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, "Cancelado")
	else:
		var error_msg = result.get("error", "Error desconocido")
		print("MOSystem: MO '%s' falló - %s" % [mo_type, error_msg])
		if SignalManager:
			SignalManager.mo_finished.emit(mo_type, false, error_msg)

	_reset_state()

## Resetea el estado interno del sistema
func _reset_state() -> void:
	is_processing_mo = false
	current_mo_type = ""
	current_target = null

## Verifica si el sistema está procesando una MO
func is_busy() -> bool:
	return is_processing_mo

## Obtiene información del estado actual
func get_current_mo_info() -> Dictionary:
	return {
		"is_processing": is_processing_mo,
		"mo_type": current_mo_type,
		"target": current_target,
		"registered_mos": mo_actions.keys()
	}

## Obtiene todas las MO registradas
func get_registered_mo_types() -> Array:
	return mo_actions.keys()
