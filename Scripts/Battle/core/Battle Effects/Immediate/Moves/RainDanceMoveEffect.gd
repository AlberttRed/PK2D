extends BattleMoveEffect
class_name RainDanceMoveEffect

func _init(_user: BattlePokemon, _target: BattlePokemon = null) -> void:
	super._init(_user, _target)

func apply():
	# Crear efecto de lluvia con duración de 5 turnos
	# El parámetro 'true' indica que fue iniciado por un movimiento (no es lluvia natural)
	var rain_effect := RainWeatherEffect.new(user, 5, true)
	BattleEffectController.add_field_effect(rain_effect)

func visualize(ui: BattleUI):
	# Mostrar mensaje cuando la lluvia es provocada por el movimiento
	await ui.show_message_from_dict({
		"type": "wait",
		"text": "¡Comenzó a llover!",
		"wait_time": 1.5
	})
