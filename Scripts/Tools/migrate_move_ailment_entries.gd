@tool
extends EditorScript

## Migra ailment + meta_ailment_chance + meta_flinch_chance → ailment_entries en cada MoveData.
## Ejecutar desde: Editor > Tools > Execute Script

const MOVES_DIR := "res://Resources/Data/Moves"
const FLINCH_AILMENT_PATH := "res://Resources/Data/Ailments/FLINCH.tres"

var _flinch_ailment_cache: AilmentData = null


func _run() -> void:
	print("[MigrateMoveAilmentEntries] Iniciando...")
	var dir := DirAccess.open(MOVES_DIR)
	if dir == null:
		push_error("[MigrateMoveAilmentEntries] No se pudo abrir %s" % MOVES_DIR)
		return

	var updated := 0
	var skipped := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := MOVES_DIR + "/" + file_name
			var move_data := load(path) as MoveData
			if move_data == null:
				file_name = dir.get_next()
				continue

			var built := _build_entries_from_legacy(move_data)
			if built.is_empty():
				skipped += 1
				file_name = dir.get_next()
				continue

			if _entries_equal(move_data.ailment_entries, built):
				skipped += 1
				file_name = dir.get_next()
				continue

			move_data.ailment_entries = built
			var err := ResourceSaver.save(move_data, path)
			if err == OK:
				updated += 1
				print("  OK: %s (%d entries)" % [file_name, built.size()])
			else:
				push_error("  FAIL: %s (err %s)" % [file_name, err])
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[MigrateMoveAilmentEntries] Actualizados: %d | Sin cambios: %d" % [updated, skipped])


func _build_entries_from_legacy(move_data: MoveData) -> Array[MoveAilmentEntry]:
	var entries: Array[MoveAilmentEntry] = []
	if move_data == null:
		return entries

	var primary: AilmentData = _resolve_ailment(move_data.ailment)
	var primary_is_flinch := _is_flinch_ailment(move_data, primary)

	if primary != null:
		var chance := move_data.meta_ailment_chance
		if chance <= 0 and primary_is_flinch:
			chance = move_data.meta_flinch_chance
		if chance > 0:
			var entry := MoveAilmentEntry.new()
			entry.ailment = primary
			entry.chance = chance
			entries.append(entry)

	if move_data.meta_flinch_chance > 0 and not primary_is_flinch:
		var flinch := _get_flinch_ailment()
		if flinch != null:
			var flinch_entry := MoveAilmentEntry.new()
			flinch_entry.ailment = flinch
			flinch_entry.chance = move_data.meta_flinch_chance
			entries.append(flinch_entry)

	return entries


func _resolve_ailment(ailment: AilmentData) -> AilmentData:
	if ailment == null:
		return null
	var path := ailment.resource_path
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as AilmentData
	return ailment


func _is_flinch_ailment(move_data: MoveData, ailment: AilmentData) -> bool:
	if move_data.ailment_id == AilmentsEnum.Values.FLINCH:
		return true
	if move_data.meta_ailment_id == AilmentsEnum.Values.FLINCH:
		return true
	if ailment != null:
		var path := ailment.resource_path
		if path.ends_with("FLINCH.tres"):
			return true
	return false


func _get_flinch_ailment() -> AilmentData:
	if _flinch_ailment_cache != null:
		return _flinch_ailment_cache
	if ResourceLoader.exists(FLINCH_AILMENT_PATH):
		_flinch_ailment_cache = load(FLINCH_AILMENT_PATH) as AilmentData
	return _flinch_ailment_cache


func _entries_equal(current: Array[MoveAilmentEntry], built: Array[MoveAilmentEntry]) -> bool:
	if current.size() != built.size():
		return false
	for i in current.size():
		var a := current[i]
		var b := built[i]
		if a == null or b == null:
			return false
		if a.chance != b.chance:
			return false
		if a.ailment != b.ailment:
			return false
	return true
