@tool
extends EditorScript

const ITEMS_DIR := "res://Resources/Data/Items"


func _run() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("[migrate_item_battle_categories] No se pudo abrir " + ITEMS_DIR)
		return

	var updated := 0
	var files := dir.get_files()
	files.sort()

	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue

		var path := ITEMS_DIR + "/" + file_name
		var item_res: Resource = ResourceLoader.load(path)
		if item_res == null:
			continue

		var kind: int = int(item_res.get("kind"))
		var item_category_id: int = int(item_res.get("item_category_id"))
		item_res.set("category", _map_item_to_battle_category(kind, item_category_id))

		var err := ResourceSaver.save(item_res, path)
		if err == OK:
			updated += 1
		else:
			push_warning("[migrate_item_battle_categories] Error guardando %s (%d)" % [path, err])

	print("[migrate_item_battle_categories] Items actualizados: %d" % updated)


func _map_item_to_battle_category(kind: int, item_category_id: int) -> Resource:
	if kind == ItemEnums.Kind.POKEBALL:
		return _new_category("res://Resources/BattleCategories/Items/BattlePokeballItemCategory.tres")
	if kind == ItemEnums.Kind.HEAL_HP:
		return _new_category("res://Resources/BattleCategories/Items/BattleHealingItemCategory.tres")
	if kind == ItemEnums.Kind.CURE_STATUS:
		return _new_category("res://Resources/BattleCategories/Items/BattleStatusHealItemCategory.tres")
	if kind == ItemEnums.Kind.REVIVE:
		return _new_category("res://Resources/BattleCategories/Items/BattleReviveItemCategory.tres")

	# Fallback opcional por IDs de categoría comunes de PokeAPI.
	if item_category_id in [27, 28]:
		return _new_category("res://Resources/BattleCategories/Items/BattleHealingItemCategory.tres")
	if item_category_id == 29:
		return _new_category("res://Resources/BattleCategories/Items/BattleStatusHealItemCategory.tres")
	if item_category_id == 30:
		return _new_category("res://Resources/BattleCategories/Items/BattleReviveItemCategory.tres")
	if item_category_id in [34, 35]:
		return _new_category("res://Resources/BattleCategories/Items/BattlePokeballItemCategory.tres")

	return _new_category("res://Resources/BattleCategories/Items/BattleUnsupportedItemCategory.tres")


func _new_category(path: String) -> Resource:
	var res := load(path)
	if res == null:
		push_warning("[migrate_item_battle_categories] No se pudo cargar %s" % path)
	return res
