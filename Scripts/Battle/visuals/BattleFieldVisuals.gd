class_name BattleFieldVisuals
extends RefCounted
## Resuelve rutas/texturas de fondo y bases de combate (Essentials: backdrop + variant + time).


const BATTLEBACKS_DIR := "res://Sprites/Batalla/Battlebacks/"


## backdrop + base_variant + time → { bg, player_base, enemy_base, paths }.
static func resolve(
	battle_back: BattleBackEnum.Values,
	base_variant: BattleBaseVariantEnum.Values,
	time: BattleRules.BattleTime
) -> Dictionary:
	var effective_back := _effective_battle_back(battle_back)
	var effective_variant := _effective_base_variant(effective_back, base_variant)
	var backdrop_key := BattleBackEnum.to_key_name(effective_back)
	var variant_key := BattleBaseVariantEnum.to_key_name(effective_variant)
	var time_suffix := _time_suffix(time)

	var bg_stem := "battlebg%s" % backdrop_key
	var player_stem := _base_stem("playerbase", backdrop_key, variant_key, effective_back)
	var enemy_stem := _base_stem("enemybase", backdrop_key, variant_key, effective_back)

	var bg_result := _load_with_time_fallback(bg_stem, time_suffix)
	var player_result := _load_with_time_fallback(player_stem, time_suffix)
	var enemy_result := _load_with_time_fallback(enemy_stem, time_suffix)

	return {
		"bg": bg_result.texture,
		"player_base": player_result.texture,
		"enemy_base": enemy_result.texture,
		"paths": {
			"bg": bg_result.path,
			"player_base": player_result.path,
			"enemy_base": enemy_result.path,
		},
		"battle_back": effective_back,
		"base_variant": effective_variant,
		"time": time,
	}


static func apply_to_field_ui(field_ui: FieldUI, resolved: Dictionary) -> void:
	if field_ui == null:
		push_warning("BattleFieldVisuals.apply_to_field_ui: field_ui es null")
		return
	field_ui._apply_resolved_field_visuals(resolved)


## EncounterAreaType → BattleRules.environment (combate salvaje).
static func encounter_to_environment(area_type: EncounterAreaTypeEnum.Values) -> BattleRules.BattleEnvironments:
	match area_type:
		EncounterAreaTypeEnum.Values.LAND, EncounterAreaTypeEnum.Values.HEADBUTT:
			return BattleRules.BattleEnvironments.GRASS
		EncounterAreaTypeEnum.Values.CAVE, EncounterAreaTypeEnum.Values.ROCK_SMASH:
			return BattleRules.BattleEnvironments.CAVE
		EncounterAreaTypeEnum.Values.WATER, EncounterAreaTypeEnum.Values.FISHING:
			return BattleRules.BattleEnvironments.WATER
		EncounterAreaTypeEnum.Values.SAND:
			return BattleRules.BattleEnvironments.FIELD
		_:
			return BattleRules.BattleEnvironments.GRASS


## Default de backdrop según área de encuentro (mapa/trainer pueden override en PBIs 863/867).
static func encounter_to_default_battle_back(area_type: EncounterAreaTypeEnum.Values) -> BattleBackEnum.Values:
	match area_type:
		EncounterAreaTypeEnum.Values.WATER, EncounterAreaTypeEnum.Values.FISHING:
			return BattleBackEnum.Values.WATER
		EncounterAreaTypeEnum.Values.CAVE, EncounterAreaTypeEnum.Values.ROCK_SMASH:
			return BattleBackEnum.Values.CAVE
		EncounterAreaTypeEnum.Values.HEADBUTT:
			return BattleBackEnum.Values.FOREST
		_:
			return BattleBackEnum.Values.FIELD


## Rellena contexto visual en combates salvajes (PBI 864).
static func configure_wild_rules(
	rules: BattleRules,
	encounter_area: EncounterAreaTypeEnum.Values,
	world_system: WorldSystem,
	player: Node = null
) -> void:
	if rules == null:
		return
	var map_back := get_map_battle_back(world_system)
	var surfing := is_player_surfing(player)
	var diving := is_player_diving(player)
	rules.time = BattleRules.BattleTime.DAY
	rules.encounter_area = encounter_area
	rules.environment = encounter_to_environment(encounter_area)
	rules.battle_back = resolve_battle_back(map_back, encounter_area, surfing, diving)
	rules.base_variant = encounter_to_default_base_variant(encounter_area, rules.battle_back)


## Rellena contexto visual en combates contra entrenador (PBI 864 + overrides #867).
static func configure_trainer_rules(
	rules: BattleRules,
	world_system: WorldSystem,
	trainer_data: TrainerData = null
) -> void:
	if rules == null:
		return
	if trainer_data != null:
		trainer_data.initialize()
	var map_back := get_map_battle_back(world_system)
	rules.time = BattleRules.BattleTime.DAY
	rules.battle_back = resolve_trainer_battle_back(trainer_data, map_back)
	rules.base_variant = resolve_trainer_base_variant(trainer_data, rules.battle_back)
	rules.environment = BattleWildIntroEnum.environment_for_battle_back(rules.battle_back)


## Prioridad: trainer → clase → mapa.
static func resolve_trainer_battle_back(
	trainer_data: TrainerData,
	map_battle_back: BattleBackEnum.Values
) -> BattleBackEnum.Values:
	if trainer_data != null:
		var override := trainer_data.get_battle_back_override()
		if override != BattleBackEnum.Values.INHERIT:
			return override
	return map_battle_back


## Prioridad: trainer → clase → INHERIT (resolver en FieldUI).
static func resolve_trainer_base_variant(
	trainer_data: TrainerData,
	resolved_battle_back: BattleBackEnum.Values
) -> BattleBaseVariantEnum.Values:
	if BattleBackEnum.uses_fixed_base_set(resolved_battle_back):
		return BattleBaseVariantEnum.Values.NONE
	if trainer_data != null:
		var override := trainer_data.get_base_variant_override()
		if override != BattleBaseVariantEnum.Values.INHERIT:
			return override
	return BattleBaseVariantEnum.Values.INHERIT


static func get_map_battle_back(world_system: WorldSystem) -> BattleBackEnum.Values:
	if world_system == null:
		return BattleBackEnum.Values.FIELD
	return world_system.get_active_map_battle_back()


static func is_player_surfing(player: Node) -> bool:
	return player != null and player.get("is_surfing") == true


static func is_player_diving(player: Node) -> bool:
	return player != null and player.get("is_diving") == true


## Inferencia para combates salvajes por evento cuando no hay tile de encuentro.
static func infer_encounter_area_from_map(map_battle_back: BattleBackEnum.Values) -> EncounterAreaTypeEnum.Values:
	match map_battle_back:
		BattleBackEnum.Values.CAVE, BattleBackEnum.Values.CAVE_DARK, BattleBackEnum.Values.CAVE_DARKER:
			return EncounterAreaTypeEnum.Values.CAVE
		BattleBackEnum.Values.UNDERWATER:
			return EncounterAreaTypeEnum.Values.LAND
		BattleBackEnum.Values.WATER:
			return EncounterAreaTypeEnum.Values.WATER
		_:
			return EncounterAreaTypeEnum.Values.LAND


## battle_back efectivo: mapa + buceo/surf + área de encuentro.
static func resolve_battle_back(
	map_battle_back: BattleBackEnum.Values,
	encounter_area: EncounterAreaTypeEnum.Values,
	player_is_surfing: bool,
	player_is_diving: bool = false
) -> BattleBackEnum.Values:
	if player_is_diving:
		return BattleBackEnum.Values.UNDERWATER
	if player_is_surfing:
		return BattleBackEnum.Values.WATER
	match encounter_area:
		EncounterAreaTypeEnum.Values.WATER, EncounterAreaTypeEnum.Values.FISHING:
			return BattleBackEnum.Values.WATER
	return map_battle_back


## base_variant según encounter + backdrop (combinaciones válidas de PNG).
static func encounter_to_default_base_variant(
	encounter_area: EncounterAreaTypeEnum.Values,
	battle_back: BattleBackEnum.Values
) -> BattleBaseVariantEnum.Values:
	if BattleBackEnum.uses_fixed_base_set(battle_back):
		return BattleBaseVariantEnum.Values.NONE
	match encounter_area:
		EncounterAreaTypeEnum.Values.SAND:
			if battle_back == BattleBackEnum.Values.FIELD:
				return BattleBaseVariantEnum.Values.SAND
			if _supports_grass_variant(battle_back):
				return BattleBaseVariantEnum.Values.GRASS
			return BattleBaseVariantEnum.Values.NONE
		EncounterAreaTypeEnum.Values.CAVE, EncounterAreaTypeEnum.Values.ROCK_SMASH:
			return BattleBaseVariantEnum.Values.NONE
		EncounterAreaTypeEnum.Values.WATER, EncounterAreaTypeEnum.Values.FISHING:
			return BattleBaseVariantEnum.Values.NONE
		EncounterAreaTypeEnum.Values.LAND, EncounterAreaTypeEnum.Values.HEADBUTT:
			if _supports_grass_variant(battle_back):
				return BattleBaseVariantEnum.Values.GRASS
			return BattleBaseVariantEnum.Values.NONE
		_:
			if _supports_grass_variant(battle_back):
				return BattleBaseVariantEnum.Values.GRASS
			return BattleBaseVariantEnum.Values.NONE


static func _supports_grass_variant(battle_back: BattleBackEnum.Values) -> bool:
	match battle_back:
		BattleBackEnum.Values.FIELD, BattleBackEnum.Values.FOREST, BattleBackEnum.Values.MOUNTAIN:
			return true
		_:
			return false


static func format_resolved_paths(resolved: Dictionary) -> String:
	var paths: Dictionary = resolved.get("paths", {})
	return "bg=%s | player=%s | enemy=%s" % [
		paths.get("bg", "?"),
		paths.get("player_base", "?"),
		paths.get("enemy_base", "?"),
	]


static func _effective_battle_back(battle_back: BattleBackEnum.Values) -> BattleBackEnum.Values:
	if battle_back == BattleBackEnum.Values.INHERIT:
		return BattleBackEnum.Values.FIELD
	return battle_back


static func _effective_base_variant(
	battle_back: BattleBackEnum.Values,
	base_variant: BattleBaseVariantEnum.Values
) -> BattleBaseVariantEnum.Values:
	if BattleBackEnum.uses_fixed_base_set(battle_back):
		return BattleBaseVariantEnum.Values.NONE
	if base_variant == BattleBaseVariantEnum.Values.INHERIT:
		return BattleBaseVariantEnum.Values.GRASS
	return base_variant


static func _base_stem(
	prefix: String,
	backdrop_key: String,
	variant_key: String,
	battle_back: BattleBackEnum.Values
) -> String:
	if BattleBackEnum.uses_fixed_base_set(battle_back) or variant_key.is_empty():
		return "%s%s" % [prefix, backdrop_key]
	return "%s%s%s" % [prefix, backdrop_key, variant_key]


static func _time_suffix(time: BattleRules.BattleTime) -> String:
	match time:
		BattleRules.BattleTime.NIGHT:
			return "Night"
		BattleRules.BattleTime.EVENING:
			return "Eve"
		_:
			return ""


static func _load_with_time_fallback(stem: String, time_suffix: String) -> Dictionary:
	if time_suffix != "":
		var timed := _load_texture(stem + time_suffix)
		if timed.texture != null:
			return timed
	var base := _load_texture(stem)
	if base.texture != null:
		return base
	push_warning("BattleFieldVisuals: no se encontró PNG para stem '%s'" % stem)
	return {"texture": null, "path": ""}


static func _load_texture(stem: String) -> Dictionary:
	var path := BATTLEBACKS_DIR + stem + ".png"
	if ResourceLoader.exists(path):
		return {"texture": load(path) as Texture2D, "path": path}
	return {"texture": null, "path": ""}
