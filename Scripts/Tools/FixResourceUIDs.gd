@tool
extends EditorScript

## Repara UIDs inválidos re-guardando .tscn/.tres
## Uso: abrir en el editor y ejecutar (Script > Run)

@export var dry_run: bool = false
@export var root_path: String = "res://"

func _run() -> void:
	print("[FixResourceUIDs] Inicio. dry_run=", dry_run, " root=", root_path)
	var paths := _collect_resource_paths(root_path)
	print("[FixResourceUIDs] Archivos a procesar: ", paths.size())
	var ok := 0
	var fail := 0
	var ok_paths: Array[String] = []
	var fail_paths: Array[String] = []
	for p in paths:
		var res := ResourceLoader.load(p)
		if res == null:
			push_warning("[FixResourceUIDs] No se pudo cargar: " + p)
			fail += 1
			fail_paths.append(p)
			continue
		if dry_run:
			print("[FixResourceUIDs] (dry) Guardaría: ", p, " | tipo=", typeof(res))
			ok += 1
			ok_paths.append(p)
			continue
		var err := ResourceSaver.save(res, p)
		if err == OK:
			print("[FixResourceUIDs] Guardado: ", p)
			ok += 1
			ok_paths.append(p)
		else:
			push_error("[FixResourceUIDs] Error guardando (" + str(err) + "): " + p)
			fail += 1
			fail_paths.append(p)

	# Forzar reescaneo del FS del editor
	var fs := get_editor_interface().get_resource_filesystem()
	if fs:
		fs.scan()
	# Escribir reporte a res:// para inspección en el proyecto
	var lines: Array[String] = []
	lines.append("[FixResourceUIDs] Reporte")
	lines.append("dry_run=" + str(dry_run))
	lines.append("root_path=" + root_path)
	lines.append("OK=" + str(ok) + " FAIL=" + str(fail))
	lines.append("")
	lines.append("-- OK paths --")
	for p_ok in ok_paths:
		lines.append(p_ok)
	lines.append("")
	lines.append("-- FAIL paths --")
	for p_fail in fail_paths:
		lines.append(p_fail)
	var report := "\n".join(lines) + "\n"
	var rpt_path := "res://Tools/FixResourceUIDs_report.txt"
	var f := FileAccess.open(rpt_path, FileAccess.WRITE)
	if f:
		f.store_string(report)
		f.flush()
		f.close()
		print("[FixResourceUIDs] Reporte escrito en: ", rpt_path)
	else:
		push_warning("[FixResourceUIDs] No se pudo escribir reporte en " + rpt_path)

	print("[FixResourceUIDs] Fin. OK=", ok, " FAIL=", fail)

func _collect_resource_paths(base: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(base)
	if dir == null:
		push_error("[FixResourceUIDs] No se puede abrir: " + base)
		return result
	# Archivos en este nivel
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			if f.begins_with("."):
				continue
			if f == ".import":
				continue
			result.append_array(_collect_resource_paths(base.path_join(f)))
		else:
			if f.ends_with(".tscn") or f.ends_with(".tres"):
				result.append(base.path_join(f))
	dir.list_dir_end()
	return result
