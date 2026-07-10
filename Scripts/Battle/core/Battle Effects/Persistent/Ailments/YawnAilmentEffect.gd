class_name YawnAilmentEffect
extends PersistentBattleEffect

const DEFAULT_TURNS_TO_SLEEP: int = 2
const _SLEEP_AILMENT_PATH := "res://Resources/Data/Ailments/SLEEP.tres"
const _INSOMNIA_ABILITY_ID: int = 15
const _VITAL_SPIRIT_ABILITY_ID: int = 72

var _finished: bool = false
var _turns_remaining: int = 0
var _sleep_applied: bool = false


func _init(_source, _min_turns = null, _max_turns = null, _application_chance: int = 100) -> void:
	super(_source, _min_turns, _max_turns, _application_chance)
	var min_turns := int(_min_turns) if _min_turns != null else DEFAULT_TURNS_TO_SLEEP
	var max_turns := int(_max_turns) if _max_turns != null else DEFAULT_TURNS_TO_SLEEP
	if min_turns > 0 and max_turns > 0:
		_turns_remaining = randi_range(min_turns, max_turns)
	else:
		_turns_remaining = DEFAULT_TURNS_TO_SLEEP


static func is_yawning(pokemon: BattlePokemon) -> bool:
	return get_active_effect(pokemon) != null


static func get_active_effect(pokemon: BattlePokemon) -> YawnAilmentEffect:
	if pokemon == null:
		return null
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is YawnAilmentEffect:
			var yawn := effect as YawnAilmentEffect
			if yawn.is_active():
				return yawn
	return null


func is_active() -> bool:
	return not has_finished()


func can_apply() -> int:
	if target == null:
		return ApplyFailReason.Values.GENERIC_FAIL
	if _has_major_status(target):
		return ApplyFailReason.Values.GENERIC_FAIL
	var existing := get_active_effect(target)
	if existing != null:
		BattleEffectController.remove_pokemon_effect(target, existing)
	return ApplyFailReason.Values.OK


func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	applied = true
	_sleep_applied = false

	if pokemon != target or not is_active():
		return

	if pokemon.is_fainted():
		_finished = true
		return

	_turns_remaining -= 1
	if _turns_remaining > 0:
		return

	if _try_apply_sleep(pokemon):
		_sleep_applied = true
	_finished = true


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN or not applied:
		return
	if pokemon != target:
		return

	if _sleep_applied:
		await ui.show_start_effect_message(
			MessageFamily.Values.AILMENT,
			pokemon,
			AilmentsEnum.Values.SLEEP,
			null,
			null,
			source_move_id
		)
		pokemon.status_changed.emit()


func has_finished() -> bool:
	return _finished


func get_priority() -> int:
	return 10


static func _has_major_status(pokemon: BattlePokemon) -> bool:
	if pokemon == null:
		return false
	if pokemon.status != null and pokemon.status.is_persistent:
		return true
	if pokemon.base_data != null:
		var major_status: int = pokemon.base_data.major_status
		return major_status != CONST.STATUS.OK and major_status != CONST.STATUS.NONE
	return false


static func _blocks_sleep(pokemon: BattlePokemon) -> bool:
	if pokemon == null:
		return true
	if _has_major_status(pokemon):
		return true
	if pokemon.ability != null:
		var ability_id := int(pokemon.ability.id)
		if ability_id == _INSOMNIA_ABILITY_ID or ability_id == _VITAL_SPIRIT_ABILITY_ID:
			return true
	return false


func _try_apply_sleep(pokemon: BattlePokemon) -> bool:
	if pokemon == null or pokemon.is_fainted() or not pokemon.in_battle:
		return false
	if _blocks_sleep(pokemon):
		return false

	var sleep_data := load(_SLEEP_AILMENT_PATH) as AilmentData
	if sleep_data == null or sleep_data.effect == null:
		push_warning("YawnAilmentEffect: no se pudo cargar SLEEP.tres")
		return false
	var ctx := BattlePhaseContext.for_ailment(pokemon, sleep_data)
	BattleEffectController.run_apply_phase(pokemon, BattleEffect.Phases.ON_VALIDATE_AILMENT, ctx)
	if ctx.rejected:
		return false

	var sleep_effect := sleep_data.get_effect(null, null) as PersistentBattleEffect
	if sleep_effect == null:
		return false

	sleep_effect.target = pokemon
	sleep_effect.source = sleep_data
	sleep_effect.source_move_id = source_move_id
	pokemon.set_status(sleep_data)
	BattleEffectController.add_pokemon_effect(pokemon, sleep_effect)
	return true
