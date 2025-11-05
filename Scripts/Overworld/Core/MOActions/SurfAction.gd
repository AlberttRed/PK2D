extends MOAction
class_name SurfAction

## Implementación de la MO SURF
## Permite navegar sobre tiles de agua

func _init():
	mo_name = "SURF"
	description = "Navega sobre el agua"
	requires_confirmation = true

## Valida si el jugador puede usar SURF
func can_use(_player: Node, _target: Node) -> bool:
	# Verificar que el jugador tiene un Pokémon con el movimiento SURF
	var pokemon_with_surf = _find_pokemon_with_SURF(_player)
	if not pokemon_with_surf:
		return false

	return true

## Busca en el party del jugador un Pokémon que tenga el movimiento SURF
func _find_pokemon_with_SURF(_player: Node) -> Pokemon:
	var party = _player.battler.party
	if party.is_empty():
		return null

	# Buscar un Pokémon que tenga SURF
	for pokemon in party:
		if pokemon and pokemon.movements.any(func(move):
			return move and move.get_id() == MovesEnum.Values.SURF
		):
			return pokemon

	return null

## Mensaje de detección cuando el jugador mira hacia agua
func get_detect_message(_target: Node) -> String:
	return "El agua está en calma."

## Ejecuta el FLUJO de SURF: activar modo surfing
func execute(_player: Node, _target: Node, context: Node) -> Dictionary:
	# Bloquear control del jugador durante la secuencia
	SignalManager.player_control_blocked.emit()

	# Obtener GUI para mensajes
	var gui = context.get_tree().get_first_node_in_group("GUI")
	if not gui:
		push_error("SurfAction: No se encontró el GUI")
		SignalManager.player_control_unblocked.emit()
		return {"success": false, "cancelled": false}

	# Obtener el Pokémon que tiene SURF
	var pokemon_with_surf = _find_pokemon_with_SURF(_player)
	var pokemon_name = pokemon_with_surf.get_display_name() if pokemon_with_surf else "Tu Pokémon"

	# Choice de confirmación
	if requires_confirmation:
		var choice = await gui.show_message_with_choices("El agua tiene buena pinta...\n¿Quieres hacer SURF?", ["Sí", "No"] as Array[String])
		if choice != 0:
			# Usuario canceló - desbloquear control
			SignalManager.player_control_unblocked.emit()
			return {"success": false, "cancelled": true}
		await Engine.get_main_loop().process_frame

	# Mensaje de activación
	await gui.show_message_with_config("¡%s usó SURF!" % pokemon_name, {
		"waitInput": true,
		"closeAtEnd": true
	})
	await Engine.get_main_loop().process_frame

	# Activar modo surfing en el jugador
	if _player.has_method("set_surfing_mode"):
		_player.set_surfing_mode(true)

	# Hacer un paso automático hacia el agua
	if _player.has_node("GridMotion"):
		var motion = _player.get_node("GridMotion")
		# Obtener dirección actual del jugador
		var facing_direction = motion.dir
		# Hacer el paso hacia el agua
		motion.try_step(facing_direction)
		# Esperar a que termine el movimiento
		if motion.moving:
			await motion.step_finished

	# Desbloquear control del jugador al finalizar
	SignalManager.player_control_unblocked.emit()

	return {"success": true, "cancelled": false}
