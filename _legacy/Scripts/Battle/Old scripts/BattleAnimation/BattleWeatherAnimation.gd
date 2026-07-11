class_name BattleWeatherAnimation

var target : BattlePokemon
#var weather : CONST.BATTLE_WEATHER 

func _init(_target : BattlePokemon):  ## Li passarem també la CONST amb el tipus de temps
	target = _target

func doAnimation():
	assert(false, "Please override doAnimation()` in the derived script.")
