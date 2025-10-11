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

static func get_display_name(stat: StatsEnum.Values) -> String:
	match stat:
		StatsEnum.Values.ATTACK: return "Ataque"
		StatsEnum.Values.DEFENSE: return "Defensa"
		StatsEnum.Values.SP_ATTACK: return "At. Esp."
		StatsEnum.Values.SP_DEFENSE: return "Def. Esp."
		StatsEnum.Values.SPEED: return "Velocidad"
		StatsEnum.Values.ACCURACY: return "Precisión"
		StatsEnum.Values.EVASION: return "Evasión"
		_: return "Desconocido"
