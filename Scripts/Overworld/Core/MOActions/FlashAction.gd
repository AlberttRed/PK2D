extends MOAction
class_name FlashAction

## Implementación de la MO DESTELLO

var mo_system: MOSystem = null

const DEFAULT_TARGET_DARKNESS := 0.25
const DEFAULT_TRANSITION_TIME := 3.0

func _init():
	mo_name = "FLASH"
	description = "Ilumina temporalmente áreas oscuras"
	requires_confirmation = false


func set_mo_system(system: MOSystem) -> void:
	mo_system = system

func get_detect_message(_target: Node) -> String:
	return ""

func can_use(player: Node, _target: Node) -> bool:
	if player == null:
		return false

	var pokemon_with_flash := _find_pokemon_with_FLASH(player)
	return pokemon_with_flash != null


func execute(player: Node, _target: Node, context: Node) -> Dictionary:
	var overworld_context := _extract_overworld_context(context)
	var map_system: MapSystem = overworld_context.get_map_system() if overworld_context else null
	var _overlay := overworld_context.get_overlay_layer() if overworld_context else null

	if not mo_system or not overworld_context or not map_system:
		push_warning("FlashAction: Dependencias no disponibles. Abortando.")
		return {"success": false, "cancelled": false, "error": "Dependencias no disponibles"}

	var active_map := map_system.get_active_map()
	if active_map == null:
		push_warning("FlashAction: No hay mapa activo para aplicar destello.")
		return {"success": false, "cancelled": false, "error": "Mapa no disponible"}

	var pokemon_used := _find_pokemon_with_FLASH(player)
	if pokemon_used:
		var pokemon_name := pokemon_used.get_display_name() if pokemon_used.has_method("get_display_name") else "Un Pokémon"
		print("FlashAction: %s iluminó el entorno con DESTELLO" % pokemon_name)
		if mo_system:
			await mo_system.play_overlay_for_pokemon(pokemon_used)

	# Determinar oscuridad objetivo en función del estado actual del overlay
	var target_darkness := 0.0

	await DisplayManager.play_flash_reveal(target_darkness, DEFAULT_TRANSITION_TIME)

	GameStateService.set_event_flag("flash_on", true)

	# Reaplicar configuraciones del mapa para reflejar flag global
	map_system.refresh_overlay_settings()

	return {"success": true, "cancelled": false}


func _find_pokemon_with_FLASH(player: Node) -> Pokemon:
	if not player or not player.has_method("get_party"):
		return _find_pokemon_with_FLASH_legacy(player)

	var party = player.get_party()
	if not party:
		return null

	if party is Array:
		if party.is_empty():
			return null
	elif party.has_method("is_empty") and party.is_empty():
		return null

	for pokemon in party:
		if _pokemon_has_flash(pokemon):
			return pokemon
	return null


func _find_pokemon_with_FLASH_legacy(player: Node) -> Pokemon:
	if not player:
		return null

	var battler = player.get("battler") if player else null
	if not battler:
		return null

	var party = battler.get("party") if battler else null
	if party == null:
		return null

	if party is Array:
		if party.is_empty():
			return null
	elif party.has_method("is_empty") and party.is_empty():
		return null

	for pokemon in party:
		if _pokemon_has_flash(pokemon):
			return pokemon

	return null


func _pokemon_has_flash(pokemon: Pokemon) -> bool:
	if not pokemon:
		return false

	if not pokemon.has_method("get_moves"):
		return _legacy_pokemon_has_flash(pokemon)

	for move in pokemon.get_moves():
		if move and move.get_id() == MovesEnum.Values.FLASH:
			return true
	return false


func _legacy_pokemon_has_flash(pokemon: Pokemon) -> bool:
	if not pokemon:
		return false

	var movements = pokemon.get("movements") if pokemon else null
	if not movements:
		return false

	for move in movements:
		if move and move.get_id() == MovesEnum.Values.FLASH:
			return true
	return false


func _extract_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		return context.context
	return null
