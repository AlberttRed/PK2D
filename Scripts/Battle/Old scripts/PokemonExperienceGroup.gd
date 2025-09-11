class_name PokemonExperienceGroup

var id : CONST.EXPERIENCE_GROUP

func _init(id : CONST.EXPERIENCE_GROUP):
	self.id = id

func calculateExp(level:int):
	match id:
		CONST.EXPERIENCE_GROUP.SLOW:
			return calculateSlow(level)
		CONST.EXPERIENCE_GROUP.MEDIUM:
			return calculateMedium(level)
		CONST.EXPERIENCE_GROUP.FAST:
			return calculateFast(level)
		CONST.EXPERIENCE_GROUP.MEDIUM_SLOW:
			return calculateMediumSlow(level)
		CONST.EXPERIENCE_GROUP.ERRATIC:
			return calculateErratic(level)
		CONST.EXPERIENCE_GROUP.FLUCTUATING:
			return calculateFluctuating(level)


func calculateSlow(level:int):
	return 5 * (pow(level, 3)) / 4
	
func calculateMedium(level:int):
	return pow(level, 3)

func calculateFast(level:int):
	return 0.8 * pow(level, 3)

func calculateMediumSlow(level:int):
	return (1.2 * pow(level, 3)) - (15 * pow(level, 2)) + (100 * level) - (140)

func calculateErratic(level:int):
	if level > 0 and level <= 50:
		return pow(level, 3) * (2 - 0.02*level)
	elif level >= 51 and level <= 68:
		return pow(level, 3) * (1.5 - 0.01*level)
	elif level >= 69 and level <= 98:
		return (pow(level, 3) * ((1911 - 10*level)/3))/500
	elif level >= 99 and level <= 100:
		return pow(level, 3) * (1.6 - 0.01*level)

func calculateFluctuating(level:int):
	if level > 0 and level <= 15:
		return pow(level, 3) * (24 + (level + 1)/3) / 50
	elif level >= 16 and level <= 35:
		return pow(level, 3) * (14 + level) / 50
	elif level >= 36 and level <= 100:
		return pow(level, 3) * (32 + (level / 2)) / 50
