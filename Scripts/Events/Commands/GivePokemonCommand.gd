extends EventCommand
class_name GivePokemonCommand

@export var pokemon_def: PokemonDefinition = null
@export var show_message: bool = true
@export_multiline var message_template: String = "¡Obtuviste a [pokemon]!"

func execute(context: Node) -> void:
	if pokemon_def == null:
		push_warning("GivePokemonCommand: pokemon_def es null. Se omite.")
		context.continue_execution()
		return

	var pokemon: Pokemon = pokemon_def.create_pokemon()
	if pokemon == null or pokemon.base == null:
		push_warning("GivePokemonCommand: no se pudo crear Pokémon runtime desde pokemon_def.")
		context.continue_execution()
		return

	var party_controller := PartyController.new()
	var added_to_party := party_controller.add_pokemon(pokemon)
	var stored_successfully := added_to_party

	if show_message:
		var player_name := str(GameStateService.get_variable("PLAYER_NAME", "PLAYER")).strip_edges()
		if player_name.is_empty():
			player_name = "PLAYER"
		var pokemon_name := pokemon.get_display_name()
		if pokemon_name.strip_edges().is_empty():
			pokemon_name = pokemon.base.Name if pokemon.base != null else "POKeMON"

		var primary_message := _build_message(player_name, pokemon_name, int(pokemon.level))
		await DisplayManager.show_message(primary_message, {
			"waitInput": true,
			"closeAtEnd": true,
			"waitTime": 0.0,
			"showIconAtEnd": false,
			"frameStyle": MessageBoxFrameStyle.Values.HGSS
		})
		var nickname_choice := await DisplayManager.show_message_with_choices(
			"¿Quieres darle un mote a tu %s?" % pokemon_name.to_upper(),
			["SI", "NO"],
			true
		)
		if nickname_choice == 0:
			await DisplayManager.show_message("Asignacion de mote: pendiente de implementar.", {
				"waitInput": true,
				"closeAtEnd": true,
				"waitTime": 0.0,
				"showIconAtEnd": false,
				"frameStyle": MessageBoxFrameStyle.Values.HGSS
			})

		if not added_to_party:
			await DisplayManager.show_message("¡Tu equipo está lleno!", {
				"waitInput": true,
				"closeAtEnd": true,
				"waitTime": 0.0,
				"showIconAtEnd": false,
				"frameStyle": MessageBoxFrameStyle.Values.HGSS
			})
			var sent_to_pc := party_controller.send_to_pc(pokemon)
			stored_successfully = sent_to_pc
			if sent_to_pc:
				await DisplayManager.show_message("¡%s fue enviado al PC!" % pokemon_name, {
					"waitInput": true,
					"closeAtEnd": true,
					"waitTime": 0.0,
					"showIconAtEnd": false,
					"frameStyle": MessageBoxFrameStyle.Values.HGSS
				})
			else:
				await DisplayManager.show_message("No se pudo enviar %s al PC." % pokemon_name, {
					"waitInput": true,
					"closeAtEnd": true,
					"waitTime": 0.0,
					"showIconAtEnd": false,
					"frameStyle": MessageBoxFrameStyle.Values.FIRERED
				})

	if stored_successfully:
		_register_in_pokedex(pokemon)

	context.continue_execution()

func is_async() -> bool:
	return show_message

func is_safe_for_parallel() -> bool:
	return false

func _build_message(player_name: String, pokemon_name: String, level: int) -> String:
	var template := message_template.strip_edges()
	if template.is_empty():
		template = "¡Obtuviste a [pokemon]!"
	return template \
		.replace("[player]", player_name) \
		.replace("[pokemon]", pokemon_name) \
		.replace("[level]", str(maxi(1, level)))

func _register_in_pokedex(pokemon: Pokemon) -> void:
	if pokemon == null:
		return
	var species_id := int(pokemon.pokemon_id)
	if species_id <= 0 and pokemon.base != null:
		species_id = int(pokemon.base.id)
	if species_id <= 0:
		push_warning("GivePokemonCommand: species_id inválido para registrar en Pokédex.")
		return
	var pokedex = GameStateService.get_pokedex()
	if pokedex == null:
		push_warning("GivePokemonCommand: Pokédex no disponible para registrar species_id=%d." % species_id)
		return
	pokedex.mark_caught(species_id)
