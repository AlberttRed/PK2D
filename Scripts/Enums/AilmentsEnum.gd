class_name AilmentsEnum

# Ailments alineados con IDs de PokeAPI
enum Values {
	NONE = 0,
	PARALYSIS = 1,
	SLEEP = 2,
	FREEZE = 3,
	BURN = 4,
	POISON = 5,
	CONFUSION = 6,
	INFATUATION = 7,
	TRAP = 8,
	NIGHTMARE = 9,
	TORMENT = 12,
	DISABLE = 13,
	YAWN = 14,
	HEAL_BLOCK = 15,
	NO_TYPE_IMMUNITY = 17,
	LEECH_SEED = 18,
	EMBARGO = 19,
	PERISH_SONG = 20,
	INGRAIN = 21,
	FLINCH = 22,
}

static func from_string(id: String) -> int:
	match id:
		"none": return Values.NONE
		"paralysis": return Values.PARALYSIS
		"sleep": return Values.SLEEP
		"freeze": return Values.FREEZE
		"burn": return Values.BURN
		"poison": return Values.POISON
		"confusion": return Values.CONFUSION
		"infatuation": return Values.INFATUATION
		"trap": return Values.TRAP
		"nightmare": return Values.NIGHTMARE
		"torment": return Values.TORMENT
		"disable": return Values.DISABLE
		"yawn": return Values.YAWN
		"heal-block": return Values.HEAL_BLOCK
		"no-type-immunity": return Values.NO_TYPE_IMMUNITY
		"leech-seed": return Values.LEECH_SEED
		"embargo": return Values.EMBARGO
		"perish-song": return Values.PERISH_SONG
		"ingrain": return Values.INGRAIN
		"flinch": return Values.FLINCH
		_:
			return Values.NONE

static func from_id(numeric_id: int) -> int:
	# Mapea IDs de PokeAPI -> enum interno
	match numeric_id:
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22:
			return numeric_id
		_:
			return Values.NONE

static func get_string(val: int) -> String:
	match val:
		Values.NONE: return "none"
		Values.PARALYSIS: return "paralysis"
		Values.SLEEP: return "sleep"
		Values.FREEZE: return "freeze"
		Values.BURN: return "burn"
		Values.POISON: return "poison"
		Values.CONFUSION: return "confusion"
		Values.INFATUATION: return "infatuation"
		Values.TRAP: return "trap"
		Values.NIGHTMARE: return "nightmare"
		Values.TORMENT: return "torment"
		Values.DISABLE: return "disable"
		Values.YAWN: return "yawn"
		Values.HEAL_BLOCK: return "heal-block"
		Values.NO_TYPE_IMMUNITY: return "no-type-immunity"
		Values.LEECH_SEED: return "leech-seed"
		Values.EMBARGO: return "embargo"
		Values.PERISH_SONG: return "perish-song"
		Values.INGRAIN: return "ingrain"
		Values.FLINCH: return "flinch"
		_:
			return "none"


