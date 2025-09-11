class_name StatTypes

enum Stat {
	ATTACK,
	DEFENSE,
	SP_ATTACK,
	SP_DEFENSE,
	SPEED,
	ACCURACY,
	EVASION,
	HP
}

static func stat_to_string(stat: Stat) -> String:
	match stat:
		Stat.ATTACK: return "Ataque"
		Stat.DEFENSE: return "Defensa"
		Stat.SP_ATTACK: return "Ataque Especial"
		Stat.SP_DEFENSE: return "Defensa Especial"
		Stat.SPEED: return "Velocidad"
		Stat.ACCURACY: return "Precisión"
		Stat.EVASION: return "Evasión"
		Stat.HP: return "HP"
		_: return "Desconocido"
