class_name ConfusionAilmentEffect
extends PersistentBattleEffect

func check_effect_success():
	# 50% de probabilidad de atacarse a sí mismo
	randomize()
	effect_success = randf() < 0.5

func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE or not pokemon.can_act_this_turn:
		return

	# Si el Pokémon ya no puede actuar por otro efecto (parálisis, sueño, etc.), no procesar confusión

	applied = true
	next_turn()

	if has_finished():
		# La confusión se cura automáticamente
		return

	check_effect_success()

	if effect_success:
		# Se golpea a sí mismo por confusión
		var damage: int = ceil(pokemon.total_hp / 8.0)
		var effect := DamageEffect.new(pokemon, pokemon, null, damage)
		pokemon.take_damage(effect)
		pokemon.can_act_this_turn = false


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases, _ctx: BattlePhaseContext = null):
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE or !applied:
		return

	# Si el Pokémon ya no puede actuar por otro efecto, no mostrar mensajes de confusión


	if has_finished():
		await ui.show_end_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
		return

	if source != null and source.has_method("play_battle_animation_on"):
		await source.play_battle_animation_on(ui, pokemon)

	# Mostrar mensaje de que está confuso
	await ui.show_previous_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)

	if effect_success:
		# Se golpeó a sí mismo
		await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
		await pokemon.battle_spot.play_hit_animation()
		await pokemon.battle_spot.apply_damage()

func get_priority() -> int:
	return BattleEffectPriority.PRE_MOVE_CONFUSION
