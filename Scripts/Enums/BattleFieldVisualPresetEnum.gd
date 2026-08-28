class_name BattleFieldVisualPresetEnum
## Combinaciones válidas (battle_back + base_variant) según PNG en Battlebacks/.


enum Values {
	FIELD_PLAIN,
	FIELD_GRASS,
	FIELD_SAND,
	FIELD_PUDDLE,
	FOREST_PLAIN,
	FOREST_GRASS,
	FOREST_MUD,
	MOUNTAIN_PLAIN,
	MOUNTAIN_GRASS,
	CAVE_PLAIN,
	CAVE_WATER,
	CAVE_DARK_PLAIN,
	CAVE_DARK_WATER,
	CAVE_DARKER_PLAIN,
	CAVE_DARKER_WATER,
	WATER,
	SNOW,
	UNDERWATER,
	INDOOR_A,
	INDOOR_B,
	INDOOR_C,
	ELITE_A,
	ELITE_B,
	ELITE_C,
	ELITE_D,
	CHAMPION,
}


static func to_visuals(preset: Values) -> Dictionary:
	var battle_back: BattleBackEnum.Values = BattleBackEnum.Values.FIELD
	var base_variant: BattleBaseVariantEnum.Values = BattleBaseVariantEnum.Values.NONE
	match preset:
		Values.FIELD_PLAIN:
			battle_back = BattleBackEnum.Values.FIELD
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.FIELD_GRASS:
			battle_back = BattleBackEnum.Values.FIELD
			base_variant = BattleBaseVariantEnum.Values.GRASS
		Values.FIELD_SAND:
			battle_back = BattleBackEnum.Values.FIELD
			base_variant = BattleBaseVariantEnum.Values.SAND
		Values.FIELD_PUDDLE:
			battle_back = BattleBackEnum.Values.FIELD
			base_variant = BattleBaseVariantEnum.Values.PUDDLE
		Values.FOREST_PLAIN:
			battle_back = BattleBackEnum.Values.FOREST
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.FOREST_GRASS:
			battle_back = BattleBackEnum.Values.FOREST
			base_variant = BattleBaseVariantEnum.Values.GRASS
		Values.FOREST_MUD:
			battle_back = BattleBackEnum.Values.FOREST
			base_variant = BattleBaseVariantEnum.Values.MUD
		Values.MOUNTAIN_PLAIN:
			battle_back = BattleBackEnum.Values.MOUNTAIN
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.MOUNTAIN_GRASS:
			battle_back = BattleBackEnum.Values.MOUNTAIN
			base_variant = BattleBaseVariantEnum.Values.GRASS
		Values.CAVE_PLAIN:
			battle_back = BattleBackEnum.Values.CAVE
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.CAVE_WATER:
			battle_back = BattleBackEnum.Values.CAVE
			base_variant = BattleBaseVariantEnum.Values.WATER
		Values.CAVE_DARK_PLAIN:
			battle_back = BattleBackEnum.Values.CAVE_DARK
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.CAVE_DARK_WATER:
			battle_back = BattleBackEnum.Values.CAVE_DARK
			base_variant = BattleBaseVariantEnum.Values.WATER
		Values.CAVE_DARKER_PLAIN:
			battle_back = BattleBackEnum.Values.CAVE_DARKER
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.CAVE_DARKER_WATER:
			battle_back = BattleBackEnum.Values.CAVE_DARKER
			base_variant = BattleBaseVariantEnum.Values.WATER
		Values.WATER:
			battle_back = BattleBackEnum.Values.WATER
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.SNOW:
			battle_back = BattleBackEnum.Values.SNOW
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.UNDERWATER:
			battle_back = BattleBackEnum.Values.UNDERWATER
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.INDOOR_A:
			battle_back = BattleBackEnum.Values.INDOOR_A
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.INDOOR_B:
			battle_back = BattleBackEnum.Values.INDOOR_B
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.INDOOR_C:
			battle_back = BattleBackEnum.Values.INDOOR_C
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.ELITE_A:
			battle_back = BattleBackEnum.Values.ELITE_A
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.ELITE_B:
			battle_back = BattleBackEnum.Values.ELITE_B
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.ELITE_C:
			battle_back = BattleBackEnum.Values.ELITE_C
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.ELITE_D:
			battle_back = BattleBackEnum.Values.ELITE_D
			base_variant = BattleBaseVariantEnum.Values.NONE
		Values.CHAMPION:
			battle_back = BattleBackEnum.Values.CHAMPION
			base_variant = BattleBaseVariantEnum.Values.NONE
		_:
			battle_back = BattleBackEnum.Values.FIELD
			base_variant = BattleBaseVariantEnum.Values.GRASS
	return {"battle_back": battle_back, "base_variant": base_variant}


static func get_label(preset: Values) -> String:
	match preset:
		Values.FIELD_PLAIN: return "Field (plain)"
		Values.FIELD_GRASS: return "Field + Grass"
		Values.FIELD_SAND: return "Field + Sand"
		Values.FIELD_PUDDLE: return "Field + Puddle"
		Values.FOREST_PLAIN: return "Forest (plain)"
		Values.FOREST_GRASS: return "Forest + Grass"
		Values.FOREST_MUD: return "Forest + Mud"
		Values.MOUNTAIN_PLAIN: return "Mountain (plain)"
		Values.MOUNTAIN_GRASS: return "Mountain + Grass"
		Values.CAVE_PLAIN: return "Cave (plain)"
		Values.CAVE_WATER: return "Cave + Water"
		Values.CAVE_DARK_PLAIN: return "Cave Dark (plain)"
		Values.CAVE_DARK_WATER: return "Cave Dark + Water"
		Values.CAVE_DARKER_PLAIN: return "Cave Darker (plain)"
		Values.CAVE_DARKER_WATER: return "Cave Darker + Water"
		Values.WATER: return "Water"
		Values.SNOW: return "Snow"
		Values.UNDERWATER: return "Underwater"
		Values.INDOOR_A: return "Indoor A"
		Values.INDOOR_B: return "Indoor B"
		Values.INDOOR_C: return "Indoor C"
		Values.ELITE_A: return "Elite A"
		Values.ELITE_B: return "Elite B"
		Values.ELITE_C: return "Elite C"
		Values.ELITE_D: return "Elite D"
		Values.CHAMPION: return "Champion"
		_: return "Unknown"
