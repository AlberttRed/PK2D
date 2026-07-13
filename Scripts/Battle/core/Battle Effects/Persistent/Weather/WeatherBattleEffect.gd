class_name WeatherBattleEffect
extends PersistentBattleEffect

## Clima iniciado por movimiento (true) o clima natural del combate (false).
var started_by_move: bool = false


func _init(_source: WeatherData = null, _duration: int = 5, _started_by_move: bool = false) -> void:
	super._init(_source)
	turns_left = _duration
	started_by_move = _started_by_move


func get_weather_data() -> WeatherData:
	return source as WeatherData


func get_weather_id() -> int:
	var data := get_weather_data()
	return data.id if data != null else 0


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == Phases.ON_END_BATTLE_TURN and _should_decrement_turns():
		next_turn()
		# No eliminamos aquí: BattleEffectController lo hace después de visualize_phase().
	_on_weather_tick(pokemon, phase, ctx)
	_apply_weather_effects_for_phase(pokemon, phase, ctx)


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	await _show_weather_messages_for_phase(pokemon, ui, phase, ctx)


func _should_decrement_turns() -> bool:
	return started_by_move


func _show_weather_messages_for_phase(
	_pokemon: BattlePokemon,
	ui: BattleUI,
	phase: Phases,
	_ctx: BattlePhaseContext = null
) -> void:
	var weather_id := get_weather_id()
	if weather_id == 0:
		return
	if phase == Phases.ON_BATTLE_START:
		await ui.show_message_from_dict(ui.message_controller.get_start_weather_message(weather_id))
	elif phase == Phases.ON_END_BATTLE_TURN:
		if has_finished():
			await ui.show_message_from_dict(ui.message_controller.get_end_weather_message(weather_id))
			return
		await ui.show_message_from_dict(ui.message_controller.get_ongoing_weather_message(weather_id))


func _apply_weather_effects_for_phase(
	_pokemon: BattlePokemon,
	_phase: Phases,
	_ctx: BattlePhaseContext = null
) -> void:
	pass


func _on_weather_tick(
	_pokemon: BattlePokemon,
	_phase: Phases,
	_ctx: BattlePhaseContext = null
) -> void:
	pass


func get_priority() -> int:
	return 5
