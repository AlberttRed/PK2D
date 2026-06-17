class_name TrapAilmentEffect
extends PersistentBattleEffect

const DAMAGE_DIVISOR: int = 16
const MIN_DURATION: int = 2
const MAX_DURATION: int = 5

var _finished: bool = false
var _turns_remaining: int = 0


func _init(_source, _min_turns = null, _max_turns = null, _application_chance: int = 100) -> void:
	super(_source, null, null, _application_chance)
	_turns_remaining = randi_range(MIN_DURATION, MAX_DURATION)


static func is_trapped(pokemon: BattlePokemon) -> bool:
	if pokemon == null:
		return false
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is TrapAilmentEffect:
			var trap := effect as TrapAilmentEffect
			if trap.is_active():
				return true
	return false


## Trap activo: no expirado y el atacante sigue en combate (misma lógica que enamoramiento).
func is_active() -> bool:
	return not has_finished() and not _should_end()


func _should_end() -> bool:
	return user == null or not user.in_battle or user.is_fainted()


func apply_phase(pokemon: BattlePokemon, phase: Phases) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	applied = true

	if _should_end():
		_finished = true
		return

	if pokemon.is_fainted():
		_finished = true
		return

	var dmg: int = maxi(1, int(ceil(float(pokemon.total_hp) / float(DAMAGE_DIVISOR))))
	var trap_damage := DamageEffect.new(null, pokemon, null, dmg)
	trap_damage.is_critical = false
	trap_damage.effectiveness = 1.0
	pokemon.take_damage(trap_damage)

	_turns_remaining -= 1
	if _turns_remaining <= 0:
		_finished = true


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN or not applied:
		return

	if _should_end():
		await ui.show_end_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, null, source_move_id
		)
		return

	if pokemon.is_fainted():
		return

	await ui.show_effect_message(
		MessageFamily.Values.AILMENT, pokemon, source.id, source_move_id
	)
	await pokemon.battle_spot.apply_damage()

	if has_finished():
		await ui.show_end_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, null, source_move_id
		)


func has_finished() -> bool:
	return _finished


func get_priority() -> int:
	return 10
