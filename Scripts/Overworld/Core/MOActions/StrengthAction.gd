extends MOAction
class_name StrengthAction

## Implementación de la MO FUERZA (STRENGTH)
## Permite empujar rocas pesadas que bloquean el camino

## Referencia al MOSystem (inicializada al primer uso)
var mo_system: Node = null

func _init():
	mo_name = "STRENGTH"
	description = "Empuja rocas pesadas"
	requires_confirmation = true

## Obtiene o inicializa la referencia al MOSystem
func _get_mo_system() -> Node:
	if not mo_system or not is_instance_valid(mo_system):
		mo_system = Engine.get_main_loop().root.get_tree().get_first_node_in_group("MOSystem")
	return mo_system

## Valida si el jugador puede usar FUERZA
func can_use(_player: Node, target: Node) -> bool:
	# 1. Verificar que el target es un nodo válido
	if not target:
		return false

	# 2. Verificar que el jugador tiene un Pokémon con el movimiento FUERZA
	var pokemon_with_strength = _find_pokemon_with_STRENGTH(_player)
	if not pokemon_with_strength:
		return false

	# 3. TODO FUTURO: Verificar que tiene la medalla necesaria (RAINBOW_BADGE)

	return true

## Busca en el party del jugador un Pokémon que tenga el movimiento FUERZA
func _find_pokemon_with_STRENGTH(_player: Node) -> Pokemon:
	var party = _player.battler.party
	if party.is_empty():
		return null

	# Buscar un Pokémon que tenga STRENGTH
	for pokemon in party:
		if pokemon and pokemon.movements.any(func(move):
			return move and move.get_id() == MovesEnum.Values.STRENGTH
		):
			return pokemon

	return null

## Mensaje de detección que se muestra SIEMPRE
func get_detect_message(_target: Node) -> String:
	# Verificar si STRENGTH ya está activo
	var mo_sys = _get_mo_system()
	var strength_already_active = mo_sys and mo_sys.is_effect_active("STRENGTH_ENABLED")

	if strength_already_active:
		return "Usar FUERZA ha permitido desplazar la roca a un lado."
	else:
		return "Es una roca enorme, pero un POKéMON podría apartarla."

## Ejecuta el FLUJO de FUERZA: choice, empuje, animación
func execute(_player: Node, _target: Node, context: Node) -> Dictionary:
	# Obtener GUI para mensajes y choices
	var gui = context.get_tree().get_first_node_in_group("GUI")
	if not gui:
		push_error("StrengthAction: No se encontró el GUI")
		return {"success": false, "cancelled": false}

	# Verificar si STRENGTH ya está activo
	var mo_sys = _get_mo_system()
	var strength_already_active = mo_sys and mo_sys.is_effect_active("STRENGTH_ENABLED")

	# Si STRENGTH ya está activo, empujar directamente sin activar de nuevo
	if strength_already_active:
		return {"success": true, "cancelled": false}

	# STRENGTH no está activo - flujo normal de activación
	# Obtener el Pokémon que tiene FUERZA
	var pokemon_with_strength = _find_pokemon_with_STRENGTH(_player)
	var pokemon_name = pokemon_with_strength.get_display_name() if pokemon_with_strength else "Tu Pokémon"

	# 1. Choice de confirmación
	if requires_confirmation:
		var choice = await gui.show_message_with_choices("¿Usas FUERZA?", ["Sí", "No"] as Array[String])
		if choice != 0:
			return {"success": false, "cancelled": true}
		await Engine.get_main_loop().process_frame

	# 2. Activar el efecto STRENGTH en el mapa (persistente hasta cambiar de mapa)
	if mo_sys:
		mo_sys.activate_effect("STRENGTH_ENABLED", true)

	# 3. Mensaje de activación
	await gui.show_message_with_config("¡%s usó FUERZA!" % pokemon_name, {
		"waitInput": true,
		"closeAtEnd": true
	})
	await Engine.get_main_loop().process_frame

	await gui.show_message_with_config("La FUERZA de %s logró desplazar la roca." % pokemon_name, {
		"waitInput": true,
		"closeAtEnd": true
	})
	await Engine.get_main_loop().process_frame

	# 4. Retornar éxito (la roca se empujará al colisionar)
	return {"success": true, "cancelled": false}

## Activa el modo de empuje en la roca target
func _activate_push_mode(target: Node, player: Node, _context: Node) -> Dictionary:
	# Verificar que la roca tiene el método push()
	if not target.has_method("push"):
		push_warning("StrengthAction: El target no tiene método push()")
		return {"success": false, "error": "Target no empujable"}

	# Calcular la dirección del empuje basándose en posiciones
	var push_direction = _calculate_push_direction(player, target)

	# Intentar empujar la roca
	var can_push = await target.push(push_direction)

	if not can_push:
		return {"success": false, "error": "Bloqueado"}

	return {"success": true}

## Calcula la dirección de empuje basándose en las posiciones del jugador y la roca
## @param player: Nodo del jugador
## @param target: Nodo de la roca
## @return: Vector2 con la dirección cardinal (UP, DOWN, LEFT, RIGHT)
func _calculate_push_direction(player: Node, target: Node) -> Vector2:
	# Calcular diferencia de posiciones
	var diff = target.global_position - player.global_position

	# Convertir a dirección cardinal (la más dominante)
	if abs(diff.x) > abs(diff.y):
		# Movimiento horizontal dominante
		return Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
	else:
		# Movimiento vertical dominante
		return Vector2.DOWN if diff.y > 0 else Vector2.UP
