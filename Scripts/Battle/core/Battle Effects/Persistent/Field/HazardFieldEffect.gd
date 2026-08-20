class_name HazardFieldEffect
extends FieldBattleEffect

## Subbase para trampas de lado que se activan al entrar un Pokémon (switch-in).
## Ejemplos: Spikes, Toxic Spikes, Stealth Rock, Sticky Web.
##
## side_type identifica el lado donde están las trampas (normalmente el rival).
## La activación usa Phases.ON_SWITCH_IN (equivalente al ON_ENTRY del diseño).
##
## Las trampas no caducan por turnos por defecto (turns_left = null).
## La lógica concreta de daño/estado vive en apply_on_entry() de cada subclase.


var layers: int = 0
var max_layers: int = 1


func _init(
	_source = null,
	_side_type: BattleSide.Types = BattleSide.Types.NONE,
	_max_layers: int = 1
) -> void:
	super._init(_source, 1, _side_type)
	turns_left = null
	max_layers = maxi(_max_layers, 1)
	layers = 0


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == Phases.ON_END_BATTLE_TURN and _should_decrement_turns():
		next_turn()
	_apply_field_effect_for_phase(pokemon, phase, ctx)


func visualize_phase(
	pokemon: BattlePokemon,
	ui: BattleUI,
	phase: Phases,
	ctx: BattlePhaseContext = null
) -> void:
	if phase == Phases.ON_SWITCH_IN and _triggers_on_entry_for(pokemon):
		await visualize_on_entry(pokemon, ui)
	await super.visualize_phase(pokemon, ui, phase, ctx)


func _apply_field_effect_for_phase(
	pokemon: BattlePokemon,
	phase: Phases,
	_ctx: BattlePhaseContext = null
) -> void:
	if phase == Phases.ON_SWITCH_IN and _triggers_on_entry_for(pokemon):
		apply_on_entry(pokemon)


func apply_on_entry(_pokemon: BattlePokemon) -> void:
	pass


func visualize_on_entry(_pokemon: BattlePokemon, _ui: BattleUI) -> void:
	pass


func add_layers(amount: int = 1) -> int:
	var before := layers
	layers = mini(layers + amount, max_layers)
	return layers - before


func can_add_layers() -> bool:
	return layers < max_layers


func is_active() -> bool:
	return layers > 0


func is_full() -> bool:
	return layers >= max_layers


func _should_decrement_turns() -> bool:
	return turns_left != null


func _triggers_on_entry_for(pokemon: BattlePokemon) -> bool:
	if pokemon == null or pokemon.side == null:
		return false
	return is_active() and applies_to_side(pokemon.side.type)
