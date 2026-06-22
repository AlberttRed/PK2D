class_name TauntAilmentEffect
extends PersistentBattleEffect

const DEFAULT_DURATION: int = 3

var _finished: bool = false
var _turns_remaining: int = 0
var _blocked_move_id: int = 0


func _init(_source, _min_turns = null, _max_turns = null, _application_chance: int = 100) -> void:
	super(_source, _min_turns, _max_turns, _application_chance)
	if _min_turns != null and _max_turns != null:
		_turns_remaining = randi_range(int(_min_turns), int(_max_turns))
	else:
		_turns_remaining = DEFAULT_DURATION


static func is_taunted(pokemon: BattlePokemon) -> bool:
	if pokemon == null:
		return false
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is TauntAilmentEffect:
			var taunt := effect as TauntAilmentEffect
			if taunt.is_active():
				return true
	return false


static func blocks_status_move(pokemon: BattlePokemon, move: BattleMove) -> bool:
	if not is_taunted(pokemon) or move == null:
		return false
	return move.is_status_category()


static func _get_selected_move(pokemon: BattlePokemon) -> BattleMove:
	if pokemon == null or not pokemon.selectedBattleChoice is BattleMoveChoice:
		return null
	return (pokemon.selectedBattleChoice as BattleMoveChoice).get_move()


func is_active() -> bool:
	return not has_finished()


func restrict_selectable_moves(pokemon: BattlePokemon, filter: MoveSelectionFilter) -> void:
	for i in range(filter.moves.size()):
		if blocks_status_move(pokemon, filter.moves[i]):
			filter.block_index(i)


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == BattleEffect.Phases.ON_VALIDATE_MOVE:
		if ctx == null or ctx.move == null:
			return
		applied = true
		_blocked_move_id = 0
		effect_success = false
		if blocks_status_move(pokemon, ctx.move):
			effect_success = true
			_blocked_move_id = ctx.move.get_id()
			ctx.rejected = true
		return

	if phase == BattleEffect.Phases.ON_BEFORE_MOVE:
		if not pokemon.can_act_this_turn:
			return

		applied = true
		_blocked_move_id = 0
		effect_success = false

		var move := _get_selected_move(pokemon)
		if blocks_status_move(pokemon, move):
			effect_success = true
			_blocked_move_id = move.get_id() if move != null else 0
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


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == BattleEffect.Phases.ON_VALIDATE_MOVE:
		if not applied or not effect_success:
			return
		await ui.show_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, _blocked_move_id
		)
		return

	if phase == BattleEffect.Phases.ON_BEFORE_MOVE:
		if not applied or not effect_success:
			return
		# Solo el jugador ve el mensaje al intentar un movimiento de estado (menú).
		# La IA no debe elegirlos; ON_BEFORE_MOVE queda como red de seguridad sin UI.
		if not pokemon.controllable:
			return
		await ui.show_effect_message(
			MessageFamily.Values.AILMENT, pokemon, source.id, _blocked_move_id
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
	return 10
