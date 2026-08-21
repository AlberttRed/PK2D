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
	if not _is_enemy_trainer_send_in():
		_load_incoming_pokemon()

func visualize(ui):
	if _is_enemy_trainer_send_in():
		var trainer_name := _resolve_trainer_name()
		var incoming_name := in_pokemon.get_display_name() if in_pokemon else "(ninguno)"
		await ui.show_trainer_send_in_display(trainer_name, incoming_name)
		_load_incoming_pokemon()
		await _play_send_in_ball_throw(ui)
		await _process_switch_in()
		print("[SWITCH] Entra %s (envío entrenador)" % incoming_name)
		return

	var out_name = out_pokemon.get_name() if out_pokemon else "(ninguno)"
	var in_name = in_pokemon.get_name() if in_pokemon else "(ninguno)"

	await ui.show_switch_message(side.to_string(), in_name)
	print("[SWITCH] Sale %s, entra %s" % [out_name, in_name])

	await _play_send_in_ball_throw(ui)
	await _process_switch_in()


func _play_send_in_ball_throw(ui: BattleUI) -> void:
	if spot == null or in_pokemon == null:
		return
	spot.set_pokemon_sprite_visible(false)
	if spot.hp_bar:
		spot.hp_bar.visible = false
	await BattleFieldAnimations.play_pokeball_throw(ui, spot)
	spot.set_pokemon_sprite_visible(true)
	if spot.hp_bar:
		spot.hp_bar.visible = true


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
