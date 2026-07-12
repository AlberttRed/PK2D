class_name DisableAilmentEffect
extends PersistentBattleEffect

const DEFAULT_DURATION: int = 4

var _finished: bool = false
var _turns_remaining: int = 0
var _disabled_move_id: int = 0
var _rejected_move_id: int = 0


func _init(_source, _min_turns = null, _max_turns = null, _application_chance: int = 100) -> void:
	super(_source, _min_turns, _max_turns, _application_chance)
	if _min_turns != null and _max_turns != null:
		_turns_remaining = randi_range(int(_min_turns), int(_max_turns))
	else:
		_turns_remaining = DEFAULT_DURATION


static func get_active_effect(pokemon: BattlePokemon) -> DisableAilmentEffect:
	if pokemon == null:
		return null
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is DisableAilmentEffect:
			var disable := effect as DisableAilmentEffect
			if disable.is_active():
				return disable
	return null


static func get_candidate_move_id(pokemon: BattlePokemon) -> int:
	if pokemon == null:
		return 0
	var move_id: int = pokemon.last_used_move_id
	if move_id <= 0 or move_id == MovesEnum.Values.STRUGGLE:
		return 0
	if pokemon.find_move_index_by_id(move_id) < 0:
		return 0
	var move := pokemon.get_move_by_id(move_id)
	if move == null or move.get_pp() <= 0:
		return 0
	return move_id


static func blocks_move(pokemon: BattlePokemon, move: BattleMove) -> bool:
	if pokemon == null or move == null:
		return false
	return blocks_move_id(pokemon, move.get_id())


static func blocks_move_id(pokemon: BattlePokemon, move_id: int) -> bool:
	var disable := get_active_effect(pokemon)
	if disable == null or move_id <= 0:
		return false
	return move_id == disable._disabled_move_id


func is_active() -> bool:
	return not has_finished()


func can_apply() -> int:
	if target == null:
		return ApplyFailReason.Values.GENERIC_FAIL
	if BattleEffectController.has_effect_for(target, self):
		return ApplyFailReason.Values.ALREADY_ACTIVE
	var candidate := get_candidate_move_id(target)
	if candidate <= 0:
		return ApplyFailReason.Values.GENERIC_FAIL
	_disabled_move_id = candidate
	return ApplyFailReason.Values.OK


func get_start_causing_move_id() -> int:
	return _disabled_move_id if _disabled_move_id > 0 else source_move_id


func restrict_selectable_moves(pokemon: BattlePokemon, filter: MoveSelectionFilter) -> void:
	if not is_active() or pokemon != target:
		return
	for i in range(filter.moves.size()):
		if filter.moves[i].get_id() == _disabled_move_id:
			filter.block_index(i)


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == BattleEffect.Phases.ON_VALIDATE_MOVE:
		if ctx == null or ctx.move == null or pokemon != target:
			return
		applied = true
		_rejected_move_id = 0
		effect_success = false
		if not is_active():
			return
		if blocks_move(pokemon, ctx.move):
			effect_success = true
			_rejected_move_id = ctx.move.get_id()
			ctx.rejected = true
		return

	if phase == BattleEffect.Phases.ON_BEFORE_MOVE:
		if not pokemon.can_act_this_turn or pokemon != target or not is_active():
			return
		var move := _get_selected_move(pokemon)
		if move == null:
			return
		applied = true
		effect_success = false
		if blocks_move(pokemon, move):
			effect_success = true
			_rejected_move_id = move.get_id()
			pokemon.can_act_this_turn = false
		return

	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	applied = true

	if pokemon.is_fainted():
		_finished = true
		return

	_turns_remaining -= 1
	if _turns_remaining <= 0:
		_finished = true


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase == BattleEffect.Phases.ON_VALIDATE_MOVE:
		if not applied or not effect_success:
			return
		await ui.show_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, _rejected_move_id
		)
		return

	if phase == BattleEffect.Phases.ON_BEFORE_MOVE:
		if not applied or not effect_success or not pokemon.controllable:
			return
		await ui.show_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, _rejected_move_id
		)
		return

	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN or not applied:
		return

	if has_finished():
		await ui.show_end_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, null, source_move_id
		)


func has_finished() -> bool:
	return _finished


func get_priority() -> int:
	return BattleEffectPriority.VALIDATE_DISABLE


func get_disabled_move_id() -> int:
	return _disabled_move_id


static func _get_selected_move(pokemon: BattlePokemon) -> BattleMove:
	if pokemon == null or not pokemon.selectedBattleChoice is BattleMoveChoice:
		return null
	return (pokemon.selectedBattleChoice as BattleMoveChoice).get_move()
