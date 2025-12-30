extends MOAction
class_name CutAction

## Implementación de la MO CORTE
## Permite cortar árboles pequeños que bloquean el camino

## Referencia al MOSystem (inyectada al registrarse)
var mo_system: MOSystem = null

func _init():
	mo_name = "CUT"
	description = "Corta árboles pequeños que bloquean el camino"
	requires_confirmation = true

## Establece la referencia al MOSystem (llamado desde MOSystem.register_mo_action)
func set_mo_system(system: MOSystem) -> void:
	mo_system = system

## Valida si el jugador puede usar CORTE en el contexto actual
func can_use(_player: Node, target: Node) -> bool:
	# 1. Verificar que el target es un nodo válido
	if not target:
		return false

	# 2. Verificar que el jugador tiene un Pokémon con el movimiento CORTE
	var pokemon_with_cut = _find_pokemon_with_CUT(_player)
	if not pokemon_with_cut:
		return false

	# 3. TODO FUTURO: Verificar que tiene la medalla necesaria
	# En Pokémon, cada MO requiere una medalla específica para usarse fuera de combate
	# Ejemplo:
	# if not PlayerBadges.has_badge("CASCADE_BADGE"):
	#     return false

	return true

## Busca en el party del jugador un Pokémon que tenga el movimiento CORTE
## @return: Pokemon que tiene CORTE, o null si ninguno lo tiene
func _find_pokemon_with_CUT(_player: Node) -> Pokemon:
	# Obtener el party del jugador
	var party = _player.battler.party
	if party.is_empty():
		return null

	# Buscar un Pokémon que tenga CORTE
	for pokemon in party:
		if pokemon and pokemon.movements.any(func(move):
			return move and move.get_id() == MovesEnum.Values.CUT
		):
			return pokemon

	return null

## Mensaje de detección que se muestra SIEMPRE (incluso si no puede usar CORTE)
func get_detect_message(_target: Node) -> String:
	return "Parece que puedes CORTAR este árbol."

## Ejecuta el FLUJO de CORTE: choice, animación, mensajes de éxito
## Se llama SOLO si can_use() retornó true
func execute(_player: Node, target: Node, context: Node) -> Dictionary:
	var overworld_context := _extract_overworld_context(context)
	if overworld_context:
		overworld_context.block_player_control()

	# Obtener el Pokémon que tiene CORTE (ya validado en can_use)
	var pokemon_with_cut = _find_pokemon_with_CUT(_player)
	var pokemon_name = pokemon_with_cut.get_display_name() if pokemon_with_cut else "Tu Pokémon"

	# 1. Choice de confirmación (si requires_confirmation)
	if requires_confirmation:
		var choice = await DisplayManager.show_message_with_choices("¿Usas CORTE?", ["Sí", "No"])
		if choice != 0:  # No o cancelado
			if overworld_context:
				overworld_context.unblock_player_control()
			return {"success": false, "cancelled": true}
		await Engine.get_main_loop().process_frame

	# 2. Mensaje de éxito con el nombre del Pokémon
	await DisplayManager.show_message("¡%s usó CORTE!" % pokemon_name, {
		"waitInput": true,
		"closeAtEnd": true
	})
	await Engine.get_main_loop().process_frame

	await _play_player_mo_start(_player)

	if mo_system:
		await mo_system.play_overlay_for_pokemon(pokemon_with_cut)

	await _play_player_mo_end(_player)

	# 3. Reproducir animación
	await _play_animation(target)

	# 4. Aplicar efectos de CUT: through=true y trigger=null
	_apply_cut_effects_to_event(target)

	# 5. Retornar éxito
	if overworld_context:
		overworld_context.unblock_player_control()

	# Debug: verificar estado de pausa
	var tree = overworld_context.get_tree() if overworld_context else null
	if tree:
		print("CutAction: Juego pausado al finalizar: %s" % tree.paused)

	return {"success": true, "cancelled": false}

## Reproduce la animación de corte en el target
func _play_animation(target: Node) -> void:
	# Buscar ActorAnimator
	var actor_animator = _find_actor_animator(target)
	if not actor_animator or not actor_animator.sprite or not actor_animator.sprite.sprite_frames:
		push_warning("CutAction: No se puede reproducir animación, ActorAnimator no configurado")
		return

	var sprite_frames = actor_animator.sprite.sprite_frames
	var anim_name = ""

	# Intentar "cut_tree" primero, fallback a "default"
	if sprite_frames.has_animation("cut_tree"):
		anim_name = "cut_tree"
	elif sprite_frames.has_animation("default"):
		anim_name = "default"
	else:
		push_warning("CutAction: No hay animación disponible")
		return

	# Reproducir y esperar
	actor_animator.play(anim_name)
	await actor_animator.sprite.animation_finished

## Busca el ActorAnimator en el target
func _find_actor_animator(node: Node) -> ActorAnimator:
	if node is ActorAnimator:
		return node

	for child in node.get_children():
		if child is ActorAnimator:
			return child
		var found = _find_actor_animator(child)
		if found:
			return found

	return null

## Aplica los efectos de CUT al evento target
## Establece through=true y trigger=null en la página actual
func _apply_cut_effects_to_event(target: Node) -> void:
	if not target or not target is Event:
		push_warning("CutAction: Target no es un Event válido")
		return

	var target_event = target as Event
	if not target_event.current_page:
		push_warning("CutAction: El evento '%s' no tiene página activa" % target_event.name)
		return

	# Obtener el índice de la página actual
	var current_page_index = target_event.current_page_index
	if current_page_index < 0 or current_page_index >= target_event.pages.size():
		push_warning("CutAction: Índice de página inválido para evento '%s'" % target_event.name)
		return

	# Duplicar la página para poder modificarla (evitar modificar el Resource original)
	var editable_page = target_event.current_page.duplicate(true) as EventPage
	if not editable_page:
		push_warning("CutAction: No se pudo duplicar la página del evento '%s'" % target_event.name)
		return

	# Aplicar los cambios: through=true y trigger=null
	editable_page.through = true
	editable_page.trigger = null

	# Reemplazar la página en el array
	target_event.pages[current_page_index] = editable_page

	# Refrescar la página activa para aplicar los cambios
	target_event.refresh_active_page()

	# Ocultar el sprite del evento (igual que SetActorVisibilityCommand)
	target_event.hide_sprite()

	print("CutAction: Efectos aplicados a evento '%s' (through=true, trigger=null, visible=false)" % target_event.name)

func _extract_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		return context.context
	return null
