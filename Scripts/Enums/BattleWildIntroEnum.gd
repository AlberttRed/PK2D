class_name BattleWildIntroEnum
## Tipos de overlay de intro salvaje (Gen 3 / Essentials).


enum Values {
	NONE,
	GRASS,
	TALL_GRASS,
	SEA,
	STILL_WATER,
	UNDERWATER,
	CAVE,
	SAND,
}


static func get_type_name(type: Values) -> String:
	match type:
		Values.GRASS: return "Grass"
		Values.TALL_GRASS: return "TallGrass"
		Values.SEA: return "Sea"
		Values.STILL_WATER: return "StillWater"
		Values.UNDERWATER: return "Underwater"
		Values.CAVE: return "Cave"
		Values.SAND: return "Sand"
		_: return "None"


static func get_texture_path(type: Values) -> String:
	match type:
		Values.GRASS:
			return "res://Sprites/Batalla/Battle Animations/battleWildIntroGrass.png"
		Values.TALL_GRASS:
			return "res://Sprites/Batalla/Battle Animations/battleWildIntroTallGrass.png"
		Values.SEA:
			return "res://Sprites/Batalla/Battle Animations/battleWildIntroSea.png"
		Values.STILL_WATER:
			return "res://Sprites/Batalla/Battle Animations/battleWildIntroStillWater.png"
		Values.UNDERWATER:
			return "res://Sprites/Batalla/Battle Animations/battleWildIntroUnderwater.png"
		Values.CAVE:
			return "res://Sprites/Batalla/Battle Animations/battleWildIntroCave.png"
		Values.SAND:
			return "res://Sprites/Batalla/Battle Animations/battleWildIntroSand.png"
		_:
			return ""


static func uses_water_rise_fade_motion(type: Values) -> bool:
	return type == Values.SEA


static func uses_still_water_motion(type: Values) -> bool:
	return type == Values.STILL_WATER


static func uses_scroll_fade_motion(type: Values) -> bool:
	return type == Values.SAND or type == Values.UNDERWATER


static func uses_sand_motion(type: Values) -> bool:
	return uses_scroll_fade_motion(type)


static func uses_cave_motion(type: Values) -> bool:
	return type == Values.CAVE


static func uses_tall_grass_motion(type: Values) -> bool:
	return type == Values.TALL_GRASS


static func uses_grass_drop_motion(type: Values) -> bool:
	return type == Values.GRASS


static func min_intro_duration(type: Values) -> float:
	if type == Values.TALL_GRASS:
		return 2.1
	return 1.85


static func environment_for_battle_back(battle_back: BattleBackEnum.Values) -> BattleRules.BattleEnvironments:
	match battle_back:
		BattleBackEnum.Values.WATER, BattleBackEnum.Values.UNDERWATER:
			return BattleRules.BattleEnvironments.WATER
		BattleBackEnum.Values.CAVE:
			return BattleRules.BattleEnvironments.CAVE
		_:
			return BattleRules.BattleEnvironments.GRASS


static func resolve_from_rules(rules: BattleRules) -> Values:
	if rules == null or rules.type != BattleRules.BattleTypes.WILD:
		return Values.NONE
	if rules.battle_back == BattleBackEnum.Values.FOREST:
		match rules.environment:
			BattleRules.BattleEnvironments.GRASS, BattleRules.BattleEnvironments.FIELD:
				return Values.TALL_GRASS
	if rules.battle_back == BattleBackEnum.Values.UNDERWATER:
		return Values.UNDERWATER
	if rules.environment == BattleRules.BattleEnvironments.WATER:
		return resolve_water_intro(rules)
	if is_sand_context(rules):
		return Values.SAND
	return from_environment(rules.environment)


static func is_sand_context(rules: BattleRules) -> bool:
	if rules.encounter_area == EncounterAreaTypeEnum.Values.SAND:
		return true
	return rules.base_variant == BattleBaseVariantEnum.Values.SAND


static func resolve_water_intro(rules: BattleRules) -> Values:
	if rules.encounter_area == EncounterAreaTypeEnum.Values.FISHING:
		return Values.STILL_WATER
	return Values.SEA


static func from_environment(environment: BattleRules.BattleEnvironments) -> Values:
	match environment:
		BattleRules.BattleEnvironments.GRASS:
			return Values.GRASS
		BattleRules.BattleEnvironments.CAVE:
			return Values.CAVE
		BattleRules.BattleEnvironments.WATER:
			return Values.SEA
		BattleRules.BattleEnvironments.FIELD:
			return Values.GRASS
		_:
			return Values.NONE
