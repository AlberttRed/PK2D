class_name StatsEnum

# Stats de Pokémon
enum {
	ATTACK,
	DEFENSE,
	SP_ATTACK,
	SP_DEFENSE,
	SPEED,
	ACCURACY,
	EVASION,
	HP
}

static func stat_to_string(stat: int) -> String:
	match stat:
		ATTACK: return "Ataque"
		DEFENSE: return "Defensa"
		SP_ATTACK: return "Ataque Especial"
		SP_DEFENSE: return "Defensa Especial"
		SPEED: return "Velocidad"
		ACCURACY: return "Precisión"
		EVASION: return "Evasión"
		HP: return "HP"
		_: return "Desconocido"
