extends BattleMoveEffect
class_name RainDanceMoveEffect

var already_active: bool = false
var weather: Weather = null

func _init(_move: BattleMove, _user: BattlePokemon, _target: BattlePokemon = null) -> void:
	super._init(_move, _user, _target)
	weather = move.get_weather()

func apply():
	# Crear efecto de lluvia con duración de 5 turnos
	# El parámetro 'true' indica que fue iniciado por un movimiento (no es lluvia natural)
	var effect_instance = weather.get_effect(5, true)
	
	# Evitar duplicar clima: si ya está lloviendo, no hacemos nada
	if BattleEffectController.has_field_effect(effect_instance):
		already_active = true
		return

	BattleEffectController.add_field_effect(effect_instance)

func visualize(ui: BattleUI):
	# Mostrar mensajes según si ya estaba activa la lluvia
	if already_active:
		await ui.show_message_from_dict(ui.message_controller.get_already_active_weather_message(weather.id))
		return
	await ui.show_message_from_dict(ui.message_controller.get_start_weather_message(weather.id))
