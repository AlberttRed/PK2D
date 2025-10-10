@tool
extends EditorScript

## Genera Scripts/Enums/MovesEnum.gd a partir de res://Resources/Data/Moves/*.tres
## Usa id (PokeAPI) y internal_name de cada Move.

const MOVES_DIR := "res://Resources/Data/Moves"
const OUTPUT_PATH := "res://Scripts/Enums/MovesEnum.gd"

@export var dry_run: bool = false

func _run() -> void:
	var entries: Array[Dictionary] = _collect_moves()
	entries.sort_custom(func(a, b): return int(a.id) < int(b.id))
	var code := _render_enum(entries)
	if dry_run:
		print("[GenerateMovesEnum] (dry) Generado enum con ", entries.size(), " movimientos. No se guardará.")
		print(code)
		return
	var err := _write_file(OUTPUT_PATH, code)
	if err == OK:
		print("[GenerateMovesEnum] Escrito: ", OUTPUT_PATH, " (", entries.size(), " movimientos)")
		EditorInterface.get_resource_filesystem().scan()
	else:
		push_error("[GenerateMovesEnum] Error guardando (" + str(err) + ") en " + OUTPUT_PATH)

func _collect_moves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(MOVES_DIR)
	if dir == null:
		push_error("[GenerateMovesEnum] No se pudo abrir: " + MOVES_DIR)
		return result
	_dir_list(dir, MOVES_DIR, result)
	return result

func _dir_list(dir: DirAccess, base: String, acc: Array[Dictionary]) -> void:
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "": break
		if dir.current_is_dir():
			if f.begins_with(".") or f == ".import":
				continue
			var sub := base.path_join(f)
			var subdir := DirAccess.open(sub)
			if subdir: _dir_list(subdir, sub, acc)
			continue
		if not f.ends_with(".tres"): continue
		var path := base.path_join(f)
		var res := load(path)
		if res == null: continue
		if not res.has_method("get_script"): continue
		# Esperamos clase Move
		if not ("id" in res and "internal_name" in res): continue
		var id := int(res.id)
		var name := str(res.internal_name)
		acc.append({ "id": id, "name": name })
	dir.list_dir_end()

func _sanitize_key(name: String, id: int) -> String:
	var key := name.to_upper()
	key = key.replace(" ", "_")
	key = key.replace("-", "_")
	# Quitar caracteres no válidos
	var cleaned := ""
	for c in key:
		var oc := c.unicode_at(0)
		var is_alnum := (oc >= 48 and oc <= 57) or (oc >= 65 and oc <= 90) or (oc == 95)
		cleaned += c if is_alnum else "_"
	# Si empieza por dígito, prefijar
	if cleaned.length() > 0 and cleaned[0].is_valid_int():
		cleaned = "MOVE_" + cleaned
	# Evitar claves vacías
	if cleaned.strip_edges() == "":
		cleaned = "MOVE_" + str(id)
	return cleaned

func _render_enum(entries: Array[Dictionary]) -> String:
	var sb: PackedStringArray = []
	sb.append("class_name MovesEnum")
	sb.append("")
	sb.append("# Generado automáticamente. No editar a mano.")
	sb.append("enum Values {")
	sb.append("\tNONE = 0,")
	var used: Dictionary = {}
	for e in entries:
		var id := int(e.id)
		if id <= 0: continue
		var key := _sanitize_key(str(e.name), id)
		# Garantizar unicidad
		if used.has(key):
			key = key + "_" + str(id)
		used[key] = true
		sb.append("\t" + key + " = " + str(id) + ",")
	sb.append("}")
	return "\n".join(sb) + "\n"

func _write_file(path: String, content: String) -> int:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ERR_CANT_OPEN
	f.store_string(content)
	f.flush()
	f.close()
	return OK
