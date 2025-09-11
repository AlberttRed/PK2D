# NatureTypes.gd
class_name NatureTypes

enum Nature {
	NONE,
	HARDY, LONELY, BRAVE, ADAMANT, NAUGHTY,
	BOLD, DOCILE, RELAXED, IMPISH, LAX,
	TIMID, HASTY, SERIOUS, JOLLY, NAIVE,
	MODEST, MILD, QUIET, BASHFUL, RASH,
	CALM, GENTLE, SASSY, CAREFUL, QUIRKY
}

static func get_id(nature: NatureTypes.Nature) -> String:
	return NatureTypes.Nature.keys()[nature]

static func get_random_nature() -> NatureTypes.Nature:
	return randi_range(0, NatureTypes.Nature.size() - 1)
