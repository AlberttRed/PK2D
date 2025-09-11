extends ImmediateBattleEffect
class_name RainDanceMoveEffect

var user: BattlePokemon

func _init(_user: BattlePokemon) -> void:
	user = _user

func apply():
	var rain_effect := RainWeatherEffect.new(user)
	BattleEffectController.add_field_effect(rain_effect)

func visualize(ui: BattleUI):
	await ui.show_message_from_dict({
		"type": "wait",
		"text": "¡Comenzó a llover!",
		"wait_time": 1.5
	})
