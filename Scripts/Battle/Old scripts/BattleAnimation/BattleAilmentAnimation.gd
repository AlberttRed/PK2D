class_name BattleAilmentAnimation

var ailment : CONST.AILMENTS

func _init(_ailment : CONST.AILMENTS):  ## Li passarem també la CONST amb el tipus de temps
	ailment = _ailment

func doAnimation(_target : BattleSpot):
	assert(false, "Please override doAnimation()` in the derived script.")
