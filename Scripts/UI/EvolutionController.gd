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
	_origin: _OriginCtx.Kind
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

	var chk: EvolutionCheckResult = pokemon.check_level_evolution()
	if not chk.can_evolve or chk.target_species_id != target_species_id:
		push_warning("EvolutionController.run: condiciones no cumplen o objetivo distinto; evolución cancelada.")
		pokemon.pending_evolution.clear()
		return

	await evo_ui.play_evolution_sequence(pokemon, target_data)

	if not pokemon.apply_species_evolution(target_species_id):
		push_warning("EvolutionController.run: apply_species_evolution falló tras la secuencia.")
		return

	pokemon.check_level_evolution()
