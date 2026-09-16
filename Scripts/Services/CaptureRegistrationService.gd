extends RefCounted
class_name CaptureRegistrationService

enum Destination {
	PARTY,
	PC,
	PENDING_STORAGE,
}

## Registra un Pokémon capturado en party, PC o cola temporal.
## En combate, los mensajes extra de PC los muestra BattleController (no el de party).
static func register_captured_pokemon(pokemon: Pokemon) -> Dictionary:
	if pokemon == null:
		return {
			"ok": false,
			"destination": Destination.PENDING_STORAGE,
			"display_name": "",
			"box_name": "",
			"message": "No se pudo registrar el Pokémon capturado.",
		}

	pokemon.is_wild = false
	var party_controller := PartyController.new()
	var display_name: String = pokemon.get_display_name()

	if party_controller.add_pokemon(pokemon):
		return {
			"ok": true,
			"destination": Destination.PARTY,
			"display_name": display_name,
			"box_name": "",
			"message": "",
		}

	var box_name := ""
	if GameStateService != null:
		var pc = GameStateService.get_pc_storage()
		if pc != null and pc.has_method("find_first_free_slot"):
			var free: Vector2i = pc.find_first_free_slot()
			if free.x >= 0:
				box_name = str(pc.get_box_name(free.x))

	if party_controller.send_to_pc(pokemon):
		return {
			"ok": true,
			"destination": Destination.PC,
			"display_name": display_name,
			"box_name": box_name,
			"message": "",
		}

	GameStateService.add_pending_pc_pokemon(pokemon)
	return {
		"ok": true,
		"destination": Destination.PENDING_STORAGE,
		"display_name": display_name,
		"box_name": "",
		"message": "¡%s fue guardado en espera (PC lleno)." % display_name,
	}
