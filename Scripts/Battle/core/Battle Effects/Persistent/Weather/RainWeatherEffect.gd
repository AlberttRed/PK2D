extends PersistentBattleEffect
class_name RainWeatherEffect

var started:bool = false

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
		await ui.show_message_from_dict({
			"type": "wait",
			"text": "La lluvia sigue cayendo.",
			"wait_time": 1.0
		})

func get_priority() -> int:
	return 5
