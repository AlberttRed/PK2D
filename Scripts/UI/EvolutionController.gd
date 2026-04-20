extends RefCounted

class_name EvolutionController

const EvolutionCheckResult := preload("res://Scripts/Runtime/EvolutionCheckResult.gd")
const EvolutionUIScript := preload("res://Scripts/UI/EvolutionUI.gd")
const _OriginCtx := preload("res://Scripts/Runtime/EvolutionOriginContext.gd")

## Ejecuta UI + aplicación de especie; no es Autoload.
func run(
	ui: Control,
	pokemon: Pokemon,
	target_species_id: int,
	_origin: _OriginCtx.Kind,
	evolution_method: int = CONST.EVOL_LVL_UP
) -> void:
	if pokemon == null:
		push_warning("EvolutionController.run: pokemon es null")
		return
	var evo_ui := ui as EvolutionUIScript
	if evo_ui == null:
		push_warning("EvolutionController.run: la escena debe usar el script EvolutionUI")
		return

	var target_data: PokemonData = DatabaseService.get_pokemon(target_species_id)
	if target_data == null:
		push_warning("EvolutionController.run: species_id=%d no existe en DatabaseService; evolución cancelada." % target_species_id)
		return

	if evolution_method == CONST.EVOL_LVL_UP:
		var chk: EvolutionCheckResult = pokemon.check_level_evolution()
		if not chk.can_evolve or chk.target_species_id != target_species_id:
			push_warning("EvolutionController.run: condiciones no cumplen o objetivo distinto; evolución cancelada.")
			pokemon.pending_evolution.clear()
			return

	var can_cancel: bool = _can_cancel_evolution(evolution_method)
	var ui_result: Dictionary = await start_evolution(evo_ui, pokemon, target_data, can_cancel)
	if bool(ui_result.get("cancelled", false)):
		cancel_evolution(pokemon, evolution_method)
		return

	if not confirm_evolution(pokemon, target_species_id):
		return

	pokemon.check_level_evolution()


func start_evolution(
	evo_ui: EvolutionUIScript,
	pokemon: Pokemon,
	target_data: PokemonData,
	can_cancel: bool
) -> Dictionary:
	var result: Variant = await evo_ui.call("play_evolution_sequence", pokemon, target_data, can_cancel)
	if result is Dictionary:
		return result as Dictionary
	return {"cancelled": false}


func confirm_evolution(pokemon: Pokemon, target_species_id: int) -> bool:
	if not pokemon.apply_species_evolution(target_species_id):
		push_warning("EvolutionController.confirm_evolution: apply_species_evolution falló.")
		return false
	return true


func cancel_evolution(pokemon: Pokemon, method: int) -> void:
	if pokemon == null:
		return
	pokemon.pending_evolution.clear()
	if method == CONST.EVOL_LVL_UP:
		pokemon.mark_level_evolution_cancelled()


func _can_cancel_evolution(method: int) -> bool:
	return method == CONST.EVOL_LVL_UP
