extends PersistentBattleEffect
class_name RainWeatherEffect

var started_by_move: bool = false  # Indica si fue iniciado por un movimiento (true) o es lluvia natural (false)

func _init(_source = null, _duration: int = 5, _started_by_move: bool = false) -> void:
	super._init(_source)
	turns_left = _duration
	started_by_move = _started_by_move

func apply_phase(_pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase == Phases.ON_END_BATTLE_TURN and started_by_move:
		next_turn()
		# No eliminamos aquí: el BattleEffectController lo hace después de visualize_phase()

func visualize_phase(_pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase == Phases.ON_BATTLE_START:
		await ui.show_message_from_dict(ui.message_controller.get_start_weather_message(source.id))
	elif phase == Phases.ON_END_BATTLE_TURN:
		if has_finished():
			await ui.show_message_from_dict(ui.message_controller.get_end_weather_message(source.id))
			return
		await ui.show_message_from_dict(ui.message_controller.get_ongoing_weather_message(source.id))

func on_power(move: BattleMove, _user, _target, value):
	var move_type = move.get_type()
	# Aumentar poder de movimientos Agua en 50%
	if move_type.id == TypesEnum.Values.WATER:
		return value * 1.5
	# Reducir poder de movimientos Fuego en 50%
	elif move_type.id == TypesEnum.Values.FIRE:
		return value * 0.5
	return value

func get_priority() -> int:
	return 5
