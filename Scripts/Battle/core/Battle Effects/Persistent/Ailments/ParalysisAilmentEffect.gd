class_name ParalysisAilmentEffect
extends PersistentBattleEffect

func check_effect_success():
	effect_success = randf() < 0.25

func apply_phase(pokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	if not pokemon.can_act_this_turn:
		return
	check_effect_success()

	if effect_success:
		pokemon.can_act_this_turn = false


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases, _ctx: BattlePhaseContext = null):
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return

	if effect_success:
		if source != null and source.has_method("play_battle_animation_on"):
			await source.play_battle_animation_on(ui, pokemon)
		await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)

func get_priority() -> int:
	return BattleEffectPriority.PRE_MOVE_PARALYSIS
