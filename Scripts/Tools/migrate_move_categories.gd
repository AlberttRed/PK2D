@tool
extends EditorScript

const MOVES_DIR := "res://Resources/Data/Moves"

const CATEGORY_MAP := {
	0: preload("res://Resources/Move Categories/DamageMoveCategory.tres"),
	1: preload("res://Resources/Move Categories/AilmentMoveCategory.tres"),
	2: preload("res://Resources/Move Categories/NetGoodStatsMoveCategory.tres"),
	3: preload("res://Resources/Move Categories/HealMoveCategory.tres"),
	4: preload("res://Resources/Move Categories/DamageAilmentMoveCategory.tres"),
	5: preload("res://Resources/Move Categories/SwaggerMoveCategory.tres"),
	6: preload("res://Resources/Move Categories/DamageLowerMoveCategory.tres"),
	7: preload("res://Resources/Move Categories/DamageRaiseMoveCategory.tres"),
	8: preload("res://Resources/Move Categories/DamageHealMoveCategory.tres"),
	9: preload("res://Resources/Move Categories/OhkoMoveCategory.tres"),
	10: preload("res://Resources/Move Categories/WholeFieldEffectMoveCategory.tres"),
	11: preload("res://Resources/Move Categories/FieldEffectMoveCategory.tres"),
	12: preload("res://Resources/Move Categories/ForceSwitchMoveCategory.tres"),
	13: preload("res://Resources/Move Categories/UniqueMoveCategory.tres")
}

func _run():
	var dir := DirAccess.open(MOVES_DIR)
	if dir == null:
		push_error("No se pudo abrir " + MOVES_DIR)
		return

	var files := dir.get_files()
	files.sort()
	var updated := 0
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var path := MOVES_DIR + "/" + file
		var move_res: Resource = ResourceLoader.load(path)
		if move_res == null:
			push_warning("No se pudo cargar: " + path)
			continue

		var has_meta_category := false
		for prop in move_res.get_property_list():
			if typeof(prop) == TYPE_DICTIONARY and prop.has("name") and prop.name == "meta_category_id":
				has_meta_category = true
				break

		if not has_meta_category:
			continue

		var cat_id := int(move_res.meta_category_id)
		if not CATEGORY_MAP.has(cat_id):
			continue

		move_res.category = CATEGORY_MAP[cat_id]
		var err := ResourceSaver.save(move_res, path)
		if err == OK:
			updated += 1
		else:
			push_warning("No se pudo guardar: " + path)

	print("[migrate_move_categories] Actualizados: ", updated)
