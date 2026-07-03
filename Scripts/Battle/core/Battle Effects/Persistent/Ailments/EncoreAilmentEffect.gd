class_name EncoreAilmentEffect
extends PersistentBattleEffect

const DEFAULT_DURATION: int = 3

## Movimientos que no pueden quedar bloqueados por Otra vez (Gen 4).
const UNENCOREABLE_MOVE_IDS: Array[int] = [
	MovesEnum.Values.ENCORE,
	MovesEnum.Values.MIMIC,
	MovesEnum.Values.MIRROR_MOVE,
	MovesEnum.Values.SKETCH,
	MovesEnum.Values.STRUGGLE,
	MovesEnum.Values.TRANSFORM,
]

var _finished: bool = false
var _turns_remaining: int = 0
var _locked_move_id: int = 0
var _rejected_move_id: int = 0


func _init(_source, _min_turns = null, _max_turns = null, _application_chance: int = 100) -> void:
	super(_source, _min_turns, _max_turns, _application_chance)
	if _min_turns != null and _max_turns != null:
		_turns_remaining = randi_range(int(_min_turns), int(_max_turns))
	else:
		_turns_remaining = DEFAULT_DURATION


static func is_encored(pokemon: BattlePokemon) -> bool:
	return get_active_effect(pokemon) != null


static func get_active_effect(pokemon: BattlePokemon) -> EncoreAilmentEffect:
	if pokemon == null:
		return null
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is EncoreAilmentEffect:
			var encore := effect as EncoreAilmentEffect
			if encore.is_active():
				return encore
	return null


static func get_candidate_move_id(pokemon: BattlePokemon) -> int:
	if pokemon == null:
		return 0
	var move_id: int = pokemon.last_used_move_id
	if move_id <= 0 or move_id in UNENCOREABLE_MOVE_IDS:
		return 0
	if pokemon.find_move_index_by_id(move_id) < 0:
		return 0
	var move := pokemon.get_move_by_id(move_id)
	if move == null or move.get_pp() <= 0:
		return 0
	return move_id


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
	_locked_move_id = candidate
	return ApplyFailReason.Values.OK


func restrict_selectable_moves(pokemon: BattlePokemon, filter: MoveSelectionFilter) -> void:
	if not is_active() or pokemon != target:
		return
	var locked_index := pokemon.find_move_index_by_id(_locked_move_id)
	if locked_index < 0 or not _is_locked_move_usable(pokemon):
		_finish_early()
		return
	for i in range(filter.moves.size()):
		if i != locked_index:
			filter.block_index(i)
	filter.request_auto_submit(locked_index)


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == BattleEffect.Phases.ON_VALIDATE_MOVE:
		if ctx == null or ctx.move == null or pokemon != target:
			return
		applied = true
		_rejected_move_id = 0
		effect_success = false
		if not is_active():
			return
		if ctx.move.get_id() != _locked_move_id:
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
		if move.get_id() != _locked_move_id or not _is_locked_move_usable(pokemon):
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
			MessageFamily.Values.AILMENT, pokemon, source.id, _locked_move_id
		)
		return

	if phase == BattleEffect.Phases.ON_BEFORE_MOVE:
		if not applied or not effect_success or not pokemon.controllable:
			return
		await ui.show_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, _locked_move_id
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
	return 11


func get_locked_move_id() -> int:
	return _locked_move_id


func _is_locked_move_usable(pokemon: BattlePokemon) -> bool:
	var locked_index := pokemon.find_move_index_by_id(_locked_move_id)
	return BattleEffectController.is_move_index_selectable(pokemon, locked_index, self)


func _finish_early() -> void:
	_finished = true


static func _get_selected_move(pokemon: BattlePokemon) -> BattleMove:
	if pokemon == null or not pokemon.selectedBattleChoice is BattleMoveChoice:
		return null
	return (pokemon.selectedBattleChoice as BattleMoveChoice).get_move()
