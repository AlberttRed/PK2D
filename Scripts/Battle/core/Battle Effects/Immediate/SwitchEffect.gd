class_name SwitchEffect
extends ImmediateBattleEffect

var side: BattleSide
var spot: BattleSpot
var out_pokemon: BattlePokemon
var in_pokemon: BattlePokemon
var rules: BattleRules

func _init(_side: BattleSide, _spot: BattleSpot, _out: BattlePokemon, _in: BattlePokemon, _rules: BattleRules):
	side = _side
	spot = _spot
	out_pokemon = _out
	in_pokemon = _in
	rules = _rules

func apply():
	if out_pokemon:
		var effects_ctrl := BattleEffectController.get_instance()
		if effects_ctrl != null:
			effects_ctrl._clear_pokemon_effects(out_pokemon)
		out_pokemon.in_battle = false
	# El load del entrante va en visualize tras el recall (así el sprite saliente sigue visible).

func visualize(ui):
	if _is_enemy_trainer_send_in():
		await _visualize_enemy_trainer(ui)
		return

	await _visualize_player_or_generic(ui)


func _visualize_enemy_trainer(ui: BattleUI) -> void:
	var trainer_name := _resolve_trainer_name()
	var outgoing_name := _pokemon_display_name(out_pokemon)
	var incoming_name := _pokemon_display_name(in_pokemon)
	var has_live_out := out_pokemon != null and not out_pokemon.is_fainted()

	if has_live_out:
		await ui.show_enemy_switch_out_message(trainer_name, outgoing_name)
		await _play_exit_visual(ui)

	await ui.show_enemy_switch_in_message(trainer_name, incoming_name)
	_load_incoming_pokemon()
	await _play_send_in_visual(ui)
	await _process_switch_in()
	print("[SWITCH] Entra %s (envío entrenador)" % incoming_name)


func _visualize_player_or_generic(ui: BattleUI) -> void:
	var outgoing_name := _pokemon_display_name(out_pokemon)
	var incoming_name := _pokemon_display_name(in_pokemon)
	var has_live_out := out_pokemon != null and not out_pokemon.is_fainted()

	print("[SWITCH] Sale %s, entra %s" % [outgoing_name, incoming_name])

	if has_live_out:
		await ui.show_player_switch_out_messages(outgoing_name)
		await _play_exit_visual(ui)

	await ui.show_player_switch_in_message(incoming_name)
	_load_incoming_pokemon()
	await _play_send_in_visual(ui)
	await _process_switch_in()


func _pokemon_display_name(bp: BattlePokemon) -> String:
	if bp == null:
		return "(ninguno)"
	if bp.has_method("get_display_name"):
		return bp.get_display_name()
	return bp.get_name()


func _play_exit_visual(ui: BattleUI) -> void:
	if spot == null or out_pokemon == null:
		return
	await BattleFieldAnimations.play_pokemon_exit(ui, spot)


func _play_send_in_visual(ui: BattleUI) -> void:
	if spot == null or in_pokemon == null:
		return
	await BattleFieldAnimations.play_send_in(ui, spot)


func _load_incoming_pokemon() -> void:
	if spot and in_pokemon:
		in_pokemon.clear_last_used_move()
		spot.load_active_pokemon(in_pokemon, rules)


func _process_switch_in() -> void:
	if in_pokemon != null and not in_pokemon.is_fainted():
		await BattleEffectController.process_phase(in_pokemon, BattleEffect.Phases.ON_SWITCH_IN)


func _is_enemy_trainer_send_in() -> bool:
	return (
		side != null
		and side.type == BattleSide.Types.ENEMY
		and rules != null
		and rules.type == BattleRules.BattleTypes.TRAINER
	)


func _resolve_trainer_name() -> String:
	if side == null:
		return "Entrenador"
	var names := side.get_trainer_names()
	if not names.is_empty() and not names[0].is_empty():
		return names[0]
	return "Entrenador"
