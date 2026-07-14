class_name SunWeatherEffect
extends WeatherBattleEffect


func on_power(move: BattleMove, _user, _target, value):
	var move_type = move.get_type()
	if move_type.id == TypesEnum.Values.FIRE:
		return value * 1.5
	elif move_type.id == TypesEnum.Values.WATER:
		return value * 0.5
	return value
