class_name WeatherMoveEffect
extends BattleMoveEffect

var already_active: bool = false
var weather: WeatherData = null


func _init(_move: BattleMove, _user: BattlePokemon, _target: BattlePokemon = null) -> void:
	super._init(_move, _user, _target)
	weather = move.get_weather()


func apply() -> void:
	if weather == null:
		return
	var effect_instance := weather.get_effect(5, true)
	if effect_instance == null:
		return
	if BattleEffectController.has_field_effect(effect_instance):
		already_active = true
		return
	BattleEffectController.remove_field_weather_effects()
	BattleEffectController.add_field_effect(effect_instance)


func visualize(ui: BattleUI) -> void:
	if weather == null:
		return
	if already_active:
		await ui.show_already_effect_message(MessageFamily.Values.WEATHER, null, weather.id)
		return
	await ui.show_start_effect_message(MessageFamily.Values.WEATHER, null, weather.id)
