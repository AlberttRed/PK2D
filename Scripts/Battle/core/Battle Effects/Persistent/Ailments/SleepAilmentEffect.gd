class_name SleepAilmentEffect
extends PersistentBattleEffect


## Sin turnos desde el movimiento (p. ej. estado persistente al entrar), duración típica gen 3.
func _init(src, min_turns = null, max_turns = null, _application_chance: int = 100) -> void:
	if min_turns == null and max_turns == null:
		super(src, 2, 5, _application_chance)
	else:
		super(src, min_turns, max_turns, _application_chance)


func apply_phase(pokemon, phase: Phases) -> void: 
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	
	next_turn()
	
	if has_finished():
		pokemon.set_status(null)
	else:
		pokemon.can_act_this_turn = false 

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases):
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	if has_finished():
		await ui.show_end_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
		pokemon.status_changed.emit()
	else:
		await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)

func get_priority() -> int:
	return 10
