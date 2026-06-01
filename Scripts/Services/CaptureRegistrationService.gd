extends RefCounted
class_name CaptureRegistrationService

enum Destination {
	PARTY,
	PC,
	PENDING_STORAGE,
}

## Registra un Pokémon capturado en party, PC o cola temporal.
static func register_captured_pokemon(pokemon: Pokemon) -> Dictionary:
	if pokemon == null:
		return {
			"ok": false,
			"destination": Destination.PENDING_STORAGE,
			"message": "No se pudo registrar el Pokémon capturado.",
		}

	pokemon.is_wild = false
	var party_controller := PartyController.new()
	var display_name: String = pokemon.get_display_name()

	if party_controller.add_pokemon(pokemon):
		return {
			"ok": true,
			"destination": Destination.PARTY,
			"message": "¡%s se añadió a tu equipo!" % display_name,
		}

	if party_controller.send_to_pc(pokemon):
		return {
			"ok": true,
			"destination": Destination.PC,
			"message": "¡%s fue enviado al PC!" % display_name,
		}

	GameStateService.add_pending_pc_pokemon(pokemon)
	return {
		"ok": true,
		"destination": Destination.PENDING_STORAGE,
		"message": "¡%s fue guardado en espera (PC no disponible aún)." % display_name,
	}
