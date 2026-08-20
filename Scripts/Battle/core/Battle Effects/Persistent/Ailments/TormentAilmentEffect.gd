class_name TormentAilmentEffect
extends PersistentBattleEffect

const DEFAULT_DURATION: int = 3

var _finished: bool = false
var _turns_remaining: int = 0
var _has_turn_limit: bool = false
var _rejected_move_id: int = 0


func _init(_source, _min_turns = null, _max_turns = null, _application_chance: int = 100) -> void:
	super(_source, _min_turns, _max_turns, _application_chance)
	var min_turns := int(_min_turns) if _min_turns != null else 0
	var max_turns := int(_max_turns) if _max_turns != null else 0
	# Sin meta explícito en el movimiento, MoveData devuelve 1 por defecto; Tormento dura hasta cambio.
	if min_turns > 0 and max_turns > 0 and not _is_default_move_turn_meta(min_turns, max_turns):
		_has_turn_limit = true
		_turns_remaining = randi_range(min_turns, max_turns)
	else:
		_has_turn_limit = false


static func is_tormented(pokemon: BattlePokemon) -> bool:
	return get_active_effect(pokemon) != null


static func get_active_effect(pokemon: BattlePokemon) -> TormentAilmentEffect:
	if pokemon == null:
		return null
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is TormentAilmentEffect:
			var torment := effect as TormentAilmentEffect
			if torment.is_active():
				return torment
	return null


static func get_blocked_move_id(pokemon: BattlePokemon) -> int:
	if pokemon == null or not is_tormented(pokemon):
		return 0
	var last_id: int = pokemon.last_used_move_id
	if last_id <= 0 or last_id == MovesEnum.Values.STRUGGLE:
		return 0
	return last_id


static func blocks_move(pokemon: BattlePokemon, move: BattleMove) -> bool:
	if pokemon == null or move == null:
		return false
	return blocks_move_id(pokemon, move.get_id())


static func blocks_move_id(pokemon: BattlePokemon, move_id: int) -> bool:
	if move_id <= 0 or move_id == MovesEnum.Values.STRUGGLE:
		return false
	var blocked_id := get_blocked_move_id(pokemon)
	return blocked_id > 0 and move_id == blocked_id


func is_active() -> bool:
	return not has_finished()


func can_apply() -> int:
	if target == null:
		return ApplyFailReason.Values.GENERIC_FAIL
	if BattleEffectController.has_effect_for(target, self):
		return ApplyFailReason.Values.ALREADY_ACTIVE
	return ApplyFailReason.Values.OK


func restrict_selectable_moves(pokemon: BattlePokemon, filter: MoveSelectionFilter) -> void:
	if not is_active() or pokemon != target:
		return
	var blocked_id := get_blocked_move_id(pokemon)
	if blocked_id <= 0:
		return
	for i in range(filter.moves.size()):
		if filter.moves[i].get_id() == blocked_id:
			filter.block_index(i)


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == BattleEffect.Phases.ON_VALIDATE_MOVE:
		if ctx == null or ctx.choice == null or ctx.choice.move == null or pokemon != target:
			return
		applied = true
		_rejected_move_id = 0
		effect_success = false
		if not is_active():
			return
		var blocked_move := ctx.choice.move
		if blocks_move(pokemon, blocked_move):
			effect_success = true
			_rejected_move_id = blocked_move.get_id()
			if ctx.validation != null:
				ctx.validation.rejected = true
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

	if not _has_turn_limit:
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
	return BattleEffectPriority.VALIDATE_TORMENT


static func _get_selected_move(pokemon: BattlePokemon) -> BattleMove:
	if pokemon == null or not pokemon.selectedBattleChoice is BattleMoveChoice:
		return null
	return (pokemon.selectedBattleChoice as BattleMoveChoice).get_move()


static func _is_default_move_turn_meta(min_turns: int, max_turns: int) -> bool:
	return min_turns == 1 and max_turns == 1
