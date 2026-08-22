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
	# Reservar al entrante ya en apply: evita que otro switch del mismo turno
	# (p. ej. 2vs2 con banca mal filtrada) cargue la misma instancia en dos spots.
	if in_pokemon:
		in_pokemon.in_battle = true
	# El load visual del entrante va en visualize tras el recall.

func visualize(ui):
	if _is_enemy_trainer_send_in():
		await _visualize_enemy_trainer(ui)
	else:
		await _visualize_player_or_generic(ui)
	BattleFieldAnimations.refresh_party_bars(ui, rules)


func _visualize_enemy_trainer(ui: BattleUI) -> void:
	var trainer_name := _resolve_trainer_name()
	var outgoing_name := _pokemon_display_name(out_pokemon)
	var incoming_name := _pokemon_display_name(in_pokemon)
	var has_live_out := out_pokemon != null and not out_pokemon.is_fainted()

	if has_live_out:
		await ui.show_enemy_switch_out_message(trainer_name, outgoing_name)
		await _play_exit_visual(ui)

	await BattleFieldAnimations.play_enemy_trainer_send_in_pre_entry(
		ui, rules, trainer_name, incoming_name, spot, in_pokemon
	)
	_load_incoming_pokemon()
	await _play_send_in_visual(ui)
	await _process_switch_in()
	print("[SWITCH] Entra %s (envío entrenador)" % incoming_name)


func _visualize_player_or_generic(ui: BattleUI) -> void:
	if ui != null and ui.field_ui != null:
		ui.field_ui.hide_all_party_bars()

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
		if spot.hp_bar:
			spot.hp_bar.visible = false


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
	if spot != null and side.participants.size() >= 2 and side.battle_spots.size() >= 2:
		var idx := side.battle_spots.find(spot)
		if idx >= 0 and idx < side.participants.size():
			var participant: BattleParticipant = side.participants[idx]
			if participant != null and not participant.name.is_empty():
				return participant.name
	var names := side.get_trainer_names()
	if not names.is_empty() and not names[0].is_empty():
		return names[0]
	return "Entrenador"
