extends BattleMoveEffect
class_name RainDanceMoveEffect

var already_active: bool = false

func _init(_user: BattlePokemon, _target: BattlePokemon = null) -> void:
	super._init(_user, _target)

func apply():
	# Evitar duplicar clima: si ya está lloviendo, no hacemos nada
	var temp_effect := RainWeatherEffect.new(user, 5, true)
	if BattleEffectController.has_field_effect(temp_effect):
		already_active = true
		return
	# Crear efecto de lluvia con duración de 5 turnos
	# El parámetro 'true' indica que fue iniciado por un movimiento (no es lluvia natural)
	var rain_effect := RainWeatherEffect.new(user, 5, true)
	BattleEffectController.add_field_effect(rain_effect)

func visualize(ui: BattleUI):
	# Mostrar mensajes según si ya estaba activa la lluvia
	if already_active:
		await show_effect_message(ui, "¡Pero ya está lloviendo!", 1.0)
		return
	await show_effect_message(ui, "¡Comenzó a llover!", 1.5)
