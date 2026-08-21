class_name PerishSongAilmentEffect
extends PersistentBattleEffect

const DEFAULT_PERISH_COUNTER: int = 3

var _finished: bool = false
var _perish_counter: int = DEFAULT_PERISH_COUNTER
var _ko_this_turn: bool = false
var _ko_hp_loss: int = 0
var _defer_first_tick: bool = true


func _init(_source, min_turns = null, _max_turns = null, _application_chance: int = 100) -> void:
	super(_source, min_turns, _max_turns, _application_chance)
	var start_counter := int(min_turns) if min_turns != null else DEFAULT_PERISH_COUNTER
	if start_counter <= 0:
		start_counter = DEFAULT_PERISH_COUNTER
	_perish_counter = start_counter


static func get_active_effect(pokemon: BattlePokemon) -> PerishSongAilmentEffect:
	if pokemon == null:
		return null
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is PerishSongAilmentEffect:
			var perish := effect as PerishSongAilmentEffect
			if perish.is_active():
				return perish
	return null


func is_active() -> bool:
	return not has_finished()


func can_apply() -> int:
	if target == null:
		return ApplyFailReason.Values.GENERIC_FAIL
	var existing := get_active_effect(target)
	if existing != null:
		BattleEffectController.remove_pokemon_effect(target, existing)
	return ApplyFailReason.Values.OK


func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	applied = true
	_ko_this_turn = false
	_ko_hp_loss = 0

	if pokemon != target or not is_active():
		return

	if pokemon.is_fainted() or not pokemon.in_battle:
		_finished = true
		return

	if _defer_first_tick:
		_defer_first_tick = false
		return

	_perish_counter -= 1
	if _perish_counter > 0:
		return

	_ko_hp_loss = pokemon.hp
	_ko_this_turn = true
	_finished = true


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN or not applied:
		return
	if pokemon != target:
		return
	if _perish_counter < 0:
		return

	var tick_msg := ui.message_controller.get_perish_song_tick_message(pokemon, _perish_counter)
	if not tick_msg.is_empty():
		await ui.show_message_from_dict(tick_msg)

	if _ko_this_turn and pokemon.battle_spot != null and _ko_hp_loss > 0:
		await pokemon.battle_spot.apply_damage(_ko_hp_loss)
		pokemon.hp = 0
		pokemon.fainted = true


func has_finished() -> bool:
	return _finished


func get_priority() -> int:
	return BattleEffectPriority.END_PERISH_SONG
