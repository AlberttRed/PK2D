extends EventCommand
class_name HealPartyCommand

## Cura completa del party (HP, status, PP) vía GameStateService.
## Sin mensajes ni SFX: el evento aporta el diálogo/presentación.
## Síncrono: NO llamar continue_execution (lo hace EventController).


func execute(_context: Node) -> void:
	if GameStateService == null:
		push_warning("HealPartyCommand: GameStateService no disponible")
		return
	var party = GameStateService.get_party()
	if party == null:
		push_warning("HealPartyCommand: party null; no-op")
		return
	if party.has_method("heal_all"):
		party.heal_all()
	else:
		push_warning("HealPartyCommand: Party sin heal_all()")


func is_async() -> bool:
	return false


func is_safe_for_parallel() -> bool:
	return false
