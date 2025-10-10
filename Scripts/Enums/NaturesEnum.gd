# NaturesEnum.gd
class_name NaturesEnum

# Naturalezas de Pokémon
enum Values {
	NONE,
	HARDY, LONELY, BRAVE, ADAMANT, NAUGHTY,
	BOLD, DOCILE, RELAXED, IMPISH, LAX,
	TIMID, HASTY, SERIOUS, JOLLY, NAIVE,
	MODEST, MILD, QUIET, BASHFUL, RASH,
	CALM, GENTLE, SASSY, CAREFUL, QUIRKY
}

static func get_id(nature: Values) -> String:
	# Obtiene el nombre de la naturaleza por su ID
	match nature:
		Values.NONE: return "NONE"
		Values.HARDY: return "HARDY"
		Values.LONELY: return "LONELY"
		Values.BRAVE: return "BRAVE"
		Values.ADAMANT: return "ADAMANT"
		Values.NAUGHTY: return "NAUGHTY"
		Values.BOLD: return "BOLD"
		Values.DOCILE: return "DOCILE"
		Values.RELAXED: return "RELAXED"
		Values.IMPISH: return "IMPISH"
		Values.LAX: return "LAX"
		Values.TIMID: return "TIMID"
		Values.HASTY: return "HASTY"
		Values.SERIOUS: return "SERIOUS"
		Values.JOLLY: return "JOLLY"
		Values.NAIVE: return "NAIVE"
		Values.MODEST: return "MODEST"
		Values.MILD: return "MILD"
		Values.QUIET: return "QUIET"
		Values.BASHFUL: return "BASHFUL"
		Values.RASH: return "RASH"
		Values.CALM: return "CALM"
		Values.GENTLE: return "GENTLE"
		Values.SASSY: return "SASSY"
		Values.CAREFUL: return "CAREFUL"
		Values.QUIRKY: return "QUIRKY"
		_: return "UNKNOWN"

static func get_random_nature() -> int:  # Returns NaturesEnum.Values
	return randi_range(0, 24)  # 0 (NONE) a 24 (QUIRKY)
