extends MOAction
class_name RockSmashAction

## Implementación de la MO GOLPE ROCA (ROCK SMASH)
## Permite romper rocas frágiles y puede provocar encuentros salvajes específicos

var mo_system: MOSystem = null

const ROCK_SMASH_ENCOUNTER_TYPE := EncounterAreaTypeEnum.Values.ROCK_SMASH

func _init():
	mo_name = "ROCK_SMASH"
	description = "Rompe rocas frágiles que bloquean el camino"
	requires_confirmation = true


func set_mo_system(system: MOSystem) -> void:
	mo_system = system


func can_use(player: Node, target: Node) -> bool:
	if not target:
		return false

	var pokemon_with_move = _find_pokemon_with_ROCK_SMASH(player)
	if not pokemon_with_move:
		return false

	return true


func _find_pokemon_with_ROCK_SMASH(player: Node) -> Pokemon:
	if not player:
		return null

	var battler = player.get("battler") if player.has_method("get") else null
	if not battler and player is Node and player.has_node("Battler"):
		battler = player.get_node_or_null("Battler")
	if not battler:
		return null

	var party = battler.party
	if party.is_empty():
		return null

	for pokemon in party:
		if pokemon and pokemon.movements.any(func(move):
			return move and move.get_id() == MovesEnum.Values.ROCK_SMASH
		):
			return pokemon

	return null


func get_detect_message(_target: Node) -> String:
	var player := _get_player_from_context()
	if player and not _find_pokemon_with_ROCK_SMASH(player):
		return "Es una roca muy dura, pero un POKéMON podría hacerla añicos."
	return ""


func execute(player: Node, target: Node, context: Node) -> Dictionary:
	var overworld_context := _extract_overworld_context(context)
	if overworld_context:
		overworld_context.block_player_control()

	var pokemon_with_move = _find_pokemon_with_ROCK_SMASH(player)
	var pokemon_name = pokemon_with_move.get_display_name() if pokemon_with_move else "Tu Pokémon"

	if requires_confirmation:
		var choice = await DisplayManager.show_message_with_choices("Parece que se puede romper esta roca.\n¿Usar GOLPE ROCA?", ["Sí", "No"])
		if choice != 0:
			if overworld_context:
				overworld_context.unblock_player_control()
			return {"success": false, "cancelled": true}
		await Engine.get_main_loop().process_frame

	await DisplayManager.show_message("%s usó GOLPE ROCA." % pokemon_name, {
		"waitInput": true,
		"closeAtEnd": true
	})
	await Engine.get_main_loop().process_frame

	await _play_player_mo_start(player)

	if mo_system:
		await mo_system.play_overlay_for_pokemon(pokemon_with_move)

	await _play_player_mo_end(player)

	await _play_animation(target)

	await _maybe_trigger_rock_smash_encounter(overworld_context, player)

	if overworld_context:
		overworld_context.unblock_player_control()
	return {"success": true, "cancelled": false}


func _play_animation(target: Node) -> void:
	var actor_animator = _find_actor_animator(target)
	if not actor_animator or not actor_animator.sprite or not actor_animator.sprite.sprite_frames:
		push_warning("RockSmashAction: No se puede reproducir animación, ActorAnimator no configurado")
		return

	var sprite_frames = actor_animator.sprite.sprite_frames
	var anim_name := ""

	if sprite_frames.has_animation("rock_smash"):
		anim_name = "rock_smash"
	elif sprite_frames.has_animation("default"):
		anim_name = "default"
	else:
		push_warning("RockSmashAction: No hay animación disponible")
		return

	actor_animator.play(anim_name)
	await actor_animator.sprite.animation_finished


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


func _extract_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		return context.context
	return null


func _maybe_trigger_rock_smash_encounter(overworld_context: OverworldContext, player: Node) -> void:
	if not overworld_context or not player:
		return

	var map_encounters := _get_current_map_encounters(overworld_context)
	if not map_encounters:
		return

	var encounter_data := map_encounters.try_wild_encounter(ROCK_SMASH_ENCOUNTER_TYPE)
	if encounter_data.is_empty():
		return

	await _start_wild_battle(encounter_data, player)


func _get_current_map_encounters(overworld_context: OverworldContext) -> MapAreaEncounters:
	var world_system := overworld_context.get_world_system()
	if not world_system:
		return null

	var active_map := world_system.get_active_map()
	if not active_map:
		return null

	var direct_node = active_map.get_node_or_null("MapAreaEncounters")
	if direct_node and direct_node is MapAreaEncounters:
		return direct_node

	for child in active_map.get_children():
		if child is MapAreaEncounters:
			return child

	return null


func _start_wild_battle(encounter_data: Dictionary, player: Node) -> void:
	var pokemon_id: int = int(encounter_data.get("pokemon_id", -1))
	var level: int = int(encounter_data.get("level", 1))

	if pokemon_id <= 0:
		push_warning("RockSmashAction: Datos de encuentro inválidos (pokemon_id)")
		return

	var wild_pokemon_instance := _create_wild_pokemon(pokemon_id, level)
	if not wild_pokemon_instance:
		return

	var wild_participant := BattleParticipantWild.new([wild_pokemon_instance.to_battle_pokemon()])
	var player_participant := _get_player_participant(player)

	if not player_participant:
		push_error("RockSmashAction: No se pudo obtener el participante del jugador para el combate")
		return

	var rules := BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE
	)

	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	await DisplayManager.start_battle(participants, rules)


func _create_wild_pokemon(pokemon_id: int, level: int) -> Pokemon:
	var pokemon_data := DatabaseService.get_pokemon(pokemon_id)
	if not pokemon_data:
		push_error("RockSmashAction: No se encontró PokemonData para id %d" % pokemon_id)
		return null

	var pokemon := Pokemon.new(
		pokemon_data,
		level,
		0,
		0,
		0,
		true
	)
	pokemon.is_wild = true
	return pokemon


func _get_player_participant(player: Node) -> BattleParticipant:
	if not player:
		return null

	var battler = player.get_node_or_null("Battler")
	if battler and battler is Battler:
		if battler.can_battle():
			return battler.to_battle_participant()
		else:
			push_error("RockSmashAction: El jugador no tiene Pokémon disponibles para combatir")
			return null

	var player_team: Array = GameStateService.get_player_party()
	if player_team.is_empty():
		push_error("RockSmashAction: El jugador no tiene Pokémon en el party (GameStateService)")
		return null

	var battle_team: Array[BattlePokemon] = []
	for pokemon_instance in player_team:
		if pokemon_instance is Pokemon:
			var battle_pokemon: BattlePokemon = pokemon_instance.to_battle_pokemon()
			battle_team.append(battle_pokemon)

	var participant := BattleParticipant.new(battle_team)
	participant.name = "Player"
	participant.is_player = true
	return participant


func _get_player_from_context() -> Node:
	if mo_system and mo_system.context:
		return mo_system.context.get_player()
	return null
