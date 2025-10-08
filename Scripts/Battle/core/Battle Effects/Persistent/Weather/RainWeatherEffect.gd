extends PersistentBattleEffect
class_name RainWeatherEffect

var started_by_move: bool = false  # Indica si fue iniciado por un movimiento (true) o es lluvia natural (false)

func _init(_source = null, _duration: int = 5, _started_by_move: bool = false) -> void:
	super._init(_source)
	turns_left = _duration
	started_by_move = _started_by_move

func apply_phase(_pokemon: BattlePokemon, phase: Phases) -> void:
	if phase == Phases.ON_END_BATTLE_TURN:
		turns_left -= 1
		if turns_left <= 0:
			BattleEffectController.remove_field_effect(self)

func visualize_phase(_pokemon: BattlePokemon, ui: BattleUI, phase: Phases) -> void:
	if phase == Phases.ON_ENTRY:
		await ui.show_message_from_dict({
			"type": "wait",
			"text": "¡Comenzó a llover!",
			"wait_time": 1.5
		})
	elif phase == Phases.ON_END_BATTLE_TURN:
		if turns_left > 0:
			await ui.show_message_from_dict({
				"type": "wait",
				"text": "La lluvia sigue cayendo.",
				"wait_time": 1.0
			})
		else:
			await ui.show_message_from_dict({
				"type": "wait",
				"text": "La lluvia ha cesado.",
				"wait_time": 1.0
			})

# Modificador de poder para movimientos según tipo
func on_modifier(modifier_type: int, move: BattleMove, _user, _target, value):
	if modifier_type == BattleEffect.Modifiers.MOVE_POWER:
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
