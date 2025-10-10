class_name BattleMessageWeather
extends RefCounted


func get_start_weather_message(weather_id: int) -> Dictionary:
	var msg:String = ""
	match weather_id:
		WeathersEnum.Values.RAIN:
			msg = "¡Comenzó a llover!"
		WeathersEnum.Values.SUN:
			msg = "¡El sol brilla intensamente!"
		WeathersEnum.Values.SANDSTORM:
			msg = "¡Se desató una tormenta de arena!"
		WeathersEnum.Values.HAIL:
			msg = "¡Comenzó a granizar!"
		WeathersEnum.Values.SNOW:
			msg = "¡Comenzó a nevar!"
		WeathersEnum.Values.FOG:
			msg = "¡Una densa niebla cubre el campo!"
		WeathersEnum.Values.WIND:
			msg = "¡El viento arrecia en el campo!"
		_:
			push_warning("Invalid Weather on get_start_weather_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 1.5
	}


func get_ongoing_weather_message(weather_id: int) -> Dictionary:
	var msg:String = ""
	match weather_id:
		WeathersEnum.Values.RAIN:
			msg = "La lluvia sigue cayendo."
		WeathersEnum.Values.SUN:
			msg = "La luz solar es intensa."
		WeathersEnum.Values.SANDSTORM:
			msg = "La tormenta de arena continúa."
		WeathersEnum.Values.HAIL:
			msg = "El granizo sigue cayendo."
		WeathersEnum.Values.SNOW:
			msg = "La nieve sigue cayendo."
		WeathersEnum.Values.FOG:
			msg = "La niebla reduce la visibilidad."
		WeathersEnum.Values.WIND:
			msg = "El viento sigue soplando con fuerza."
		_:
			push_warning("Invalid Weather on get_ongoing_weather_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 1.0
	}


func get_end_weather_message(weather_id: int) -> Dictionary:
	var msg:String = ""
	match weather_id:
		WeathersEnum.Values.RAIN:
			msg = "La lluvia ha cesado."
		WeathersEnum.Values.SUN:
			msg = "La luz solar se desvaneció."
		WeathersEnum.Values.SANDSTORM:
			msg = "La tormenta de arena amainó."
		WeathersEnum.Values.HAIL:
			msg = "Dejó de granizar."
		WeathersEnum.Values.SNOW:
			msg = "Ha dejado de nevar."
		WeathersEnum.Values.FOG:
			msg = "La niebla se disipó."
		WeathersEnum.Values.WIND:
			msg = "El viento se calmó."
		_:
			push_warning("Invalid Weather on get_end_weather_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 1.0
	}


func get_already_active_weather_message(weather_id: int) -> Dictionary:
	var msg:String = ""
	match weather_id:
		WeathersEnum.Values.RAIN:
			msg = "¡Pero ya está lloviendo!"
		WeathersEnum.Values.SUN:
			msg = "¡Pero la luz solar ya es intensa!"
		WeathersEnum.Values.SANDSTORM:
			msg = "¡Pero ya hay una tormenta de arena!"
		WeathersEnum.Values.HAIL:
			msg = "¡Pero ya está granizando!"
		WeathersEnum.Values.SNOW:
			msg = "¡Pero ya está nevando!"
		WeathersEnum.Values.FOG:
			msg = "¡Pero ya hay niebla en el campo!"
		WeathersEnum.Values.WIND:
			msg = "¡Pero el viento ya arrecia!"
		_:
			push_warning("Invalid Weather on get_already_active_weather_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 1.0
	}


