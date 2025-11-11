extends EventCommand
class_name UseMOCommand

## Comando para usar una Máquina Oculta (MO) desde un evento
## GESTIONA TODO EL FLUJO: mensajes, choice, validación, animación
##
## Este comando se encarga de:
## - Mostrar mensaje de detección del obstáculo
## - Mostrar choice (Sí/No) si es necesario
## - Ejecutar validación y lógica de la MO
## - Mostrar mensaje de éxito/fallo
## - Reproducir animación si está configurada
##
## Los mensajes y animación se definen en la MOAction (ej: CutAction)
##
## LÓGICA DE TARGET:
## - Si target_path está vacío → usa el evento de origen como target
## - Si target_path tiene valor → usa el nodo especificado en ese path

## Tipo de MO a usar
@export var mo_type: MOTypeEnum.Type = MOTypeEnum.Type.CUT

## Target sobre el que se aplica la MO (opcional)
## Si está vacío, se usa el evento de origen como target
## Si tiene valor, se usa el nodo en ese path
@export var target_path: NodePath = NodePath()

## Self-Switch a activar tras éxito (opcional)
## Si no está vacío, activa este self-switch cuando la MO se complete con éxito
## Valores: "A", "B", "C", "D", o vacío para no activar ninguno
@export var activate_self_switch_on_success: String = "A"

func execute(context: Node) -> void:
	var mo_type_str = MOTypeEnum.type_to_string(mo_type)
	print("UseMOCommand: Solicitando MO '%s'" % mo_type_str)

	# Obtener el target
	var target: Node = _get_target(context)
	if not target:
		push_error("UseMOCommand: No se pudo obtener el target")
		context.continue_execution()
		return

	# Obtener MOSystem del contexto
	var overworld_context = _get_overworld_context(context)
	if not overworld_context:
		push_error("UseMOCommand: OverworldContext no disponible")
		context.continue_execution()
		return

	var mo_system: MOSystem = overworld_context.get_mo_system()
	if not mo_system or not mo_system.has_mo_action(mo_type_str):
		push_error("UseMOCommand: MO '%s' no encontrada" % mo_type_str)
		context.continue_execution()

	var mo_action = mo_system.mo_actions.get(mo_type_str)

	# SIEMPRE mostrar mensaje de detección (antes de validar)
	var detect_msg = mo_action.get_detect_message(target)
	if not detect_msg.is_empty():
		await DisplayManager.show_message(detect_msg, {"waitInput": true, "closeAtEnd": true})
		await Engine.get_main_loop().process_frame

	# Solicitar la ejecución de la MO a través del contexto
	var result: Dictionary = await overworld_context.request_mo(mo_type_str, target)

	# Si fue exitoso, activar self-switch
	if result.get("success", false) and not activate_self_switch_on_success.is_empty():
		_activate_self_switch(target, activate_self_switch_on_success)

	# Continuar con la ejecución del evento
	context.continue_execution()

## Obtiene el nodo target según la configuración
## Si target_path está vacío → usa el evento de origen
## Si target_path tiene valor → usa el nodo en ese path
func _get_target(context: Node) -> Node:
	var event_controller = context as EventController

	# Si NO se especificó un NodePath, usar el evento de origen
	if target_path.is_empty():
		if event_controller and event_controller.current_page:
			var source_event = event_controller.current_page.source_event
			if source_event:
				print("UseMOCommand: Usando evento de origen como target - %s" % source_event.name)
				return source_event
		push_error("UseMOCommand: No se pudo obtener el evento de origen")
		return null

	# Si se especificó un NodePath, usar ese nodo
	var target = context.get_node_or_null(target_path)
	if target:
		print("UseMOCommand: Usando NodePath como target - %s" % target.name)
		return target

	push_error("UseMOCommand: No se encontró el nodo en el path '%s'" % target_path)
	return null

## Activa un self-switch en el target
func _activate_self_switch(target: Node, switch_letter: String) -> void:
	if not target:
		push_warning("UseMOCommand: Target nulo, no se puede activar self-switch")
		return

	# Validar que es una letra válida
	if not switch_letter in ["A", "B", "C", "D"]:
		push_warning("UseMOCommand: Self-switch '%s' inválido. Usa A, B, C o D" % switch_letter)
		return

	# Obtener el ID del evento
	var event_id = target.name

	# Activar el self-switch en GameStateService
	GameStateService.set_self_switch(event_id, switch_letter, true)
	print("UseMOCommand: Self-switch '%s:%s' activado" % [event_id, switch_letter])

## Indica que este comando es asíncrono
func is_async() -> bool:
	return true

## No es seguro para ejecución paralela
func is_safe_for_parallel() -> bool:
	return false

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null
