extends RefCounted

class_name PokemonExperienceGroup

const _ExpGroup := preload("res://Scripts/Enums/ExpGroupEnum.gd")

## Identificador de tabla (`ExpGroupEnum.Values` ⇄ `PokemonData.growth_rate_id`).
var id: _ExpGroup.Values = _ExpGroup.Values.MEDIUM


func _init(rate_id: int = int(_ExpGroup.Values.MEDIUM)) -> void:
	id = _ExpGroup.from_growth_rate_id(rate_id)


## EXP total acumulada necesaria para estar en `level` (compatible con el sistema antiguo del proyecto).
func get_total_exp_for_level(level: int) -> int:
	if level <= 0:
		return 0
	var v: int = 0
	match id:
		_ExpGroup.Values.SLOW:
			v = _slow(level)
		_ExpGroup.Values.MEDIUM:
			v = _medium(level)
		_ExpGroup.Values.FAST:
			v = _fast(level)
		_ExpGroup.Values.MEDIUM_SLOW:
			v = _medium_slow(level)
		_ExpGroup.Values.ERRATIC:
			v = _erratic(level)
		_ExpGroup.Values.FLUCTUATING:
			v = _fluctuating(level)
		_:
			v = _medium(level)
	return maxi(0, v)


## Nombre legacy del sistema antiguo; delega en `get_total_exp_for_level`.
func calculateExp(level: int) -> int:
	return get_total_exp_for_level(level)


func _slow(level: int) -> int:
	return int(floor(5.0 * pow(level, 3) / 4.0))


func _medium(level: int) -> int:
	return int(floor(pow(level, 3)))


func _fast(level: int) -> int:
	return int(floor(0.8 * pow(level, 3)))


func _medium_slow(level: int) -> int:
	return int(floor(1.2 * pow(level, 3) - 15.0 * pow(level, 2) + 100.0 * level - 140.0))


func _erratic(level: int) -> int:
	if level > 0 and level <= 50:
		return int(floor(pow(level, 3) * (2.0 - 0.02 * level)))
	elif level >= 51 and level <= 68:
		return int(floor(pow(level, 3) * (1.5 - 0.01 * level)))
	elif level >= 69 and level <= 98:
		return int(floor((pow(level, 3) * (1911.0 - 10.0 * level)) / 500.0))
	elif level >= 99 and level <= 100:
		return int(floor(pow(level, 3) * (1.6 - 0.01 * level)))
	return _medium(level)


func _fluctuating(level: int) -> int:
	if level > 0 and level <= 15:
		return int(floor((pow(level, 3) * (24.0 + (level + 1.0) / 3.0)) / 50.0))
	elif level >= 16 and level <= 35:
		return int(floor((pow(level, 3) * (14.0 + level)) / 50.0))
	elif level >= 36 and level <= 100:
		return int(floor((pow(level, 3) * (32.0 + level / 2.0)) / 50.0))
	return _medium(level)
