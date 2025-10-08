# NaturesEnum.gd
class_name NaturesEnum

# Naturalezas de Pokémon
enum {
	NONE,
	HARDY, LONELY, BRAVE, ADAMANT, NAUGHTY,
	BOLD, DOCILE, RELAXED, IMPISH, LAX,
	TIMID, HASTY, SERIOUS, JOLLY, NAIVE,
	MODEST, MILD, QUIET, BASHFUL, RASH,
	CALM, GENTLE, SASSY, CAREFUL, QUIRKY
}

static func get_id(nature: int) -> String:
	# Obtiene el nombre de la naturaleza por su ID
	match nature:
		NONE: return "NONE"
		HARDY: return "HARDY"
		LONELY: return "LONELY"
		BRAVE: return "BRAVE"
		ADAMANT: return "ADAMANT"
		NAUGHTY: return "NAUGHTY"
		BOLD: return "BOLD"
		DOCILE: return "DOCILE"
		RELAXED: return "RELAXED"
		IMPISH: return "IMPISH"
		LAX: return "LAX"
		TIMID: return "TIMID"
		HASTY: return "HASTY"
		SERIOUS: return "SERIOUS"
		JOLLY: return "JOLLY"
		NAIVE: return "NAIVE"
		MODEST: return "MODEST"
		MILD: return "MILD"
		QUIET: return "QUIET"
		BASHFUL: return "BASHFUL"
		RASH: return "RASH"
		CALM: return "CALM"
		GENTLE: return "GENTLE"
		SASSY: return "SASSY"
		CAREFUL: return "CAREFUL"
		QUIRKY: return "QUIRKY"
		_: return "UNKNOWN"

static func get_random_nature() -> int:
	return randi_range(0, 24)  # 0 (NONE) a 24 (QUIRKY)
