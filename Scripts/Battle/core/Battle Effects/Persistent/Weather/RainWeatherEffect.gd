class_name RainWeatherEffect
extends WeatherBattleEffect


func on_power(move: BattleMove, _user, _target, value):
	var move_type = move.get_type()
	if move_type.id == TypesEnum.Values.WATER:
		return value * 1.5
	elif move_type.id == TypesEnum.Values.FIRE:
		return value * 0.5
	return value


func visualize_phase(
	pokemon: BattlePokemon,
	ui: BattleUI,
	phase: Phases,
	ctx: BattlePhaseContext = null
) -> void:
	if phase == Phases.ON_BATTLE_START:
		await super.visualize_phase(pokemon, ui, phase, ctx)
		await _play_rain_burst(ui)
	elif phase == Phases.ON_END_BATTLE_TURN:
		await super.visualize_phase(pokemon, ui, phase, ctx)
		if not has_finished():
			await _play_rain_burst(ui)
	else:
		await super.visualize_phase(pokemon, ui, phase, ctx)


static func _play_rain_burst(ui: BattleUI) -> void:
	if ui == null or ui.field_ui == null:
		return
	var overlay: FieldWeatherOverlay = ui.field_ui.get_weather_overlay()
	if overlay == null:
		return
	await overlay.play_rain_burst()


static func clear_rain_visual(ui: BattleUI) -> void:
	if ui == null or ui.field_ui == null:
		return
	var overlay: FieldWeatherOverlay = ui.field_ui.get_weather_overlay()
	if overlay != null:
		overlay.clear()
