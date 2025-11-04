extends MOAction
class_name CutActionExample

## EJEMPLO DE IMPLEMENTACIÓN DE UNA MO
## Este archivo es solo una referencia para futuras implementaciones
## NO USAR EN PRODUCCIÓN - Crear archivo específico en PBI correspondiente

## Constructor - Inicializa propiedades de la MO
func _init():
	mo_name = "CUT"
	description = "Corta árboles pequeños que bloquean el camino"

## Valida si el jugador puede usar CORTE en el contexto actual
## @param player: Nodo del jugador
## @param target: Nodo del evento sobre el que se intenta usar CORTE
## @return: true si se puede usar, false si no
func can_use(player: Node, target: Node) -> bool:
	# 1. Verificar que el jugador tiene la MO CORTE en su equipo
	# TODO: Implementar verificación real cuando tengamos el sistema de equipo
	# if not player_has_mo("CUT"):
	#     return false

	# 2. Verificar que el target es un evento válido
	if not target or not target is Event:
		print("CutAction: Target no es un Event válido")
		return false

	# 3. Verificar que el evento tiene la metadata "cuttable"
	if not target.has_meta("cuttable") or not target.get_meta("cuttable"):
		print("CutAction: Target no es cortable")
		return false

	# 4. Verificar que el evento no ha sido cortado previamente
	var event_id = target.name
	if GameStateManager.get_event_flag("cut_%s" % event_id):
		print("CutAction: Árbol ya fue cortado previamente")
		return false

	# Todas las validaciones pasaron
	return true

## Ejecuta el efecto lógico de CORTE sobre el target
## NO muestra mensajes ni animaciones - solo aplica cambios lógicos
## @param player: Nodo del jugador
## @param target: Nodo del evento a afectar
## @return: Dictionary con {success: bool, data: Dictionary}
func execute(player: Node, target: Node) -> Dictionary:
	var event_id = target.name

	# 1. Desactivar el evento para que no sea visible
	if target.has_method("set_enabled"):
		target.set_enabled(false)
		print("CutAction: Evento '%s' desactivado" % event_id)

	# 2. Marcar el flag global para persistencia
	GameStateManager.set_event_flag("cut_%s" % event_id, true)
	print("CutAction: Flag 'cut_%s' establecido" % event_id)

	# 3. Opcional: Guardar datos adicionales si es necesario
	# GameStateManager.set_variable("trees_cut", GameStateManager.get_variable("trees_cut") + 1)

	# 4. Retornar éxito con datos
	return {
		"success": true,
		"data": {
			"event_id": event_id,
			"event_name": target.name,
			"position": target.global_position if target.has_method("get_global_position") else Vector2.ZERO
		}
	}

## EJEMPLO DE REGISTRO EN MOSystem._initialize_mo_actions():
##
## func _initialize_mo_actions() -> void:
##     var cut_action = preload("res://Scripts/Overworld/Core/MOActions/CutAction.gd").new()
##     register_mo_action("CUT", cut_action)
##

## EJEMPLO DE USO EN UN EVENTO:
##
## EventPage:
##   - Trigger: ACTION_BUTTON
##   - Conditions: ninguna
##   - Commands:
##     1. ShowMessageCommand: "¡Hay un árbol cortable!"
##     2. UseMOCommand:
##        - mo_type: MOTypeEnum.Type.CUT
##        - target_path: (vacío para usar el evento de origen)
##     3. ShowMessageCommand: "¡El árbol fue cortado!"
##     4. PlayAnimationCommand: "cut_animation"
##
## METADATA DEL EVENTO:
##   - cuttable: true
##   - event_type: "cuttable_tree"
##
## NOTA: Si el árbol debe desaparecer tras cortarlo, usar SetSelfSwitchCommand
## o cambiar la página del evento con condiciones basadas en flags.
##

## NOTAS:
## - Los mensajes y animaciones se gestionan desde el evento, NO desde la MO
## - La MO solo cambia el estado lógico (flags, variables, desactivar eventos)
## - El comando UseMOCommand espera la señal mo_completed/mo_failed antes de continuar
## - El EventController pausará la ejecución hasta que la MO termine


