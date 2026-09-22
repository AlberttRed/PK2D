@tool
extends RefCounted

## Resolución de ítems para el database editor (@tool).
## No llama métodos de ItemData (no es @tool → placeholder en editor).
const ITEM_INDEX := preload("res://Services/ItemResourceIndex.gd")
const ITEMS_DIR := "res://Resources/Data/Items"


static func get_item_path(item_id: int) -> String:
	if item_id <= 0:
		return ""

	var indexed: Variant = ITEM_INDEX.BY_ID.get(item_id, "")
	var indexed_path := str(indexed) if indexed != null else ""
	if not indexed_path.is_empty() and ResourceLoader.exists(indexed_path):
		return indexed_path

	var dir := DirAccess.open(ProjectSettings.globalize_path(ITEMS_DIR))
	if dir == null:
		dir = DirAccess.open(ITEMS_DIR)
	if dir == null:
		return ""

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var file_base := file_name.get_basename()
			var parts := file_base.split(" - ", false, 1)
			var id_str := parts[0].strip_edges()
			if id_str.is_valid_int() and int(id_str) == item_id:
				dir.list_dir_end()
				return "%s/%s" % [ITEMS_DIR, file_name]
		file_name = dir.get_next()
	dir.list_dir_end()
	return ""


## Solo lee propiedades @export vía get(); no invoca métodos del script.
static func format_item_line(item_id: int) -> String:
	if item_id <= 0:
		return "(id inválido)"

	var path := get_item_path(item_id)
	if path.is_empty():
		return "%d — (ítem no encontrado)" % item_id

	var name_text := ""
	var buy := 0

	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded == null:
			loaded = load(path)
		if loaded != null:
			var dn: Variant = loaded.get("display_name")
			if dn != null and str(dn) != "":
				name_text = str(dn)
			var bp: Variant = loaded.get("buy_price")
			if bp != null:
				buy = int(bp)

	if name_text.is_empty():
		var base := path.get_file().get_basename()
		var parts := base.split(" - ", false, 1)
		if parts.size() >= 2:
			name_text = parts[1].strip_edges()
		else:
			name_text = base

	if buy > 0:
		return "%d — %s (%d₽)" % [item_id, name_text, buy]
	return "%d — %s" % [item_id, name_text]
