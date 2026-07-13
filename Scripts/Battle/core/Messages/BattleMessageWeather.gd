class_name BattleMessageWeather
extends RefCounted


func get_start_weather_message(weather_id: int) -> Dictionary:
	var msg:String = ""
	match weather_id:
		WeathersEnum.Values.RAIN:
			msg = "¡Ha empezado a llover!" #Validado HGSS
		WeathersEnum.Values.SUN:
			msg = "¡El sol está brillando!" #Validado HGSS
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
			push_warning("Invalid WeatherData on get_start_weather_message()")
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
			msg = "Sigue lloviendo..." #Validado HGSS
		WeathersEnum.Values.SUN:
			msg = "Hace mucho sol..." #Validado HGSS
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
			push_warning("Invalid WeatherData on get_ongoing_weather_message()")
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
			msg = "Ha dejado de llover." #Validado HGSS
		WeathersEnum.Values.SUN:
			msg = "Se ha ido el sol." #Validado HGSS
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
			push_warning("Invalid WeatherData on get_end_weather_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 1.0
	}


func get_already_active_weather_message() -> Dictionary:
	return { "type": "wait", "text": "¡Pero falló!", "wait_time": 1.0 }


func get_residual_damage_message(weather_id: int, pokemon: BattlePokemon) -> Dictionary:
	if pokemon == null:
		return {}
	var msg := ""
	match weather_id:
		WeathersEnum.Values.HAIL:
			msg = "¡El granizo daña a %s!" % pokemon.get_battle_display_name(true)
		WeathersEnum.Values.SANDSTORM:
			msg = "¡La tormenta de arena daña a %s!" % pokemon.get_battle_display_name(true)
		_:
			return {}
	return { "type": "wait", "text": msg, "wait_time": 1.0 }

