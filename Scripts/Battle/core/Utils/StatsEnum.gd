class_name StatsEnum

# Stats de Pokémon
enum Values {
	ATTACK,
	DEFENSE,
	SP_ATTACK,
	SP_DEFENSE,
	SPEED,
	ACCURACY,
	EVASION,
	HP
}

static func stat_to_string(stat: Values) -> String:
	match stat:
		Values.ATTACK: return "Ataque"
		Values.DEFENSE: return "Defensa"
		Values.SP_ATTACK: return "Ataque Especial"
		Values.SP_DEFENSE: return "Defensa Especial"
		Values.SPEED: return "Velocidad"
		Values.ACCURACY: return "Precisión"
		Values.EVASION: return "Evasión"
		Values.HP: return "HP"
		_: return "Desconocido"
