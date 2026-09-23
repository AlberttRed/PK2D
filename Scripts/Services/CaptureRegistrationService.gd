extends RefCounted
class_name CaptureRegistrationService

enum Destination {
	PARTY,
	PC,
	FAILED,
}


## Registra un Pokémon capturado en party o PC.
## En combate, los mensajes extra de PC los muestra BattleController (no el de party).
## Si party y PC están llenos, la ball ya se bloquea en BagUI; esto es red de seguridad.
## También marca la especie como capturada en la Pokédex (party o PC; AB#920 / #921).
static func register_captured_pokemon(pokemon: Pokemon) -> Dictionary:
	if pokemon == null:
		return {
			"ok": false,
			"destination": Destination.FAILED,
			"display_name": "",
			"box_name": "",
			"message": "No se pudo registrar el Pokémon capturado.",
			"first_catch": false,
		}

	pokemon.is_wild = false
	var party_controller := PartyController.new()
	var display_name: String = pokemon.get_display_name()

	if party_controller.add_pokemon(pokemon):
		var first_party := _mark_species_caught(pokemon)
		return {
			"ok": true,
			"destination": Destination.PARTY,
			"display_name": display_name,
			"box_name": "",
			"message": "",
			"first_catch": first_party,
		}

	var box_name := ""
	if GameStateService != null:
		var pc = GameStateService.get_pc_storage()
		if pc != null and pc.has_method("find_first_free_slot"):
			var free: Vector2i = pc.find_first_free_slot()
			if free.x >= 0:
				box_name = str(pc.get_box_name(free.x))

	if party_controller.send_to_pc(pokemon):
		var first_pc := _mark_species_caught(pokemon)
		return {
			"ok": true,
			"destination": Destination.PC,
			"display_name": display_name,
			"box_name": box_name,
			"message": "",
			"first_catch": first_pc,
		}

	return {
		"ok": false,
		"destination": Destination.FAILED,
		"display_name": display_name,
		"box_name": "",
		"message": "¡La CAJA está llena!",
		"first_catch": false,
	}


## Marca la especie en Pokédex. Devuelve true si era la primera captura de esa especie.
static func _mark_species_caught(pokemon: Pokemon) -> bool:
	if pokemon == null or GameStateService == null:
		return false
	var species_id := int(pokemon.pokemon_id)
	if species_id <= 0 and pokemon.base != null:
		species_id = int(pokemon.base.id)
	if species_id <= 0:
		push_warning("CaptureRegistrationService: species_id inválido para Pokédex.")
		return false
	var pokedex = GameStateService.get_pokedex()
	if pokedex == null:
		push_warning("CaptureRegistrationService: Pokédex no disponible.")
		return false
	var first_catch: bool = not pokedex.is_caught(species_id)
	pokedex.mark_caught(species_id)
	return first_catch
