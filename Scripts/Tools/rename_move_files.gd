@tool
extends EditorScript

## Script para renombrar archivos de Moves a formato "001 - Nombre.tres"
## Ejecutar desde Editor > Run Script

func _run() -> void:
	var moves_dir := "res://Resources/Data/Moves"
	var dir := DirAccess.open(ProjectSettings.globalize_path(moves_dir))

	if dir == null:
		push_error("No se pudo abrir directorio: %s" % moves_dir)
		return

	var renamed_count := 0
	var error_count := 0

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue

		if not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue

		# Verificar si ya tiene el formato nuevo (contiene " - ")
		if " - " in file_name:
			file_name = dir.get_next()
			continue

		# Extraer ID del nombre actual (ej: "001.tres" -> "001")
		var file_base := file_name.get_basename()
		if not file_base.is_valid_int():
			print("Saltando archivo con formato desconocido: %s" % file_name)
			file_name = dir.get_next()
			continue

		var id := int(file_base)

		# Cargar el recurso para obtener el nombre
		var path := moves_dir + "/" + file_name
		if not ResourceLoader.exists(path):
			print("Archivo no existe: %s" % path)
			file_name = dir.get_next()
			continue

		var resource := load(path) as Resource
		if resource == null:
			print("No se pudo cargar recurso: %s" % path)
			error_count += 1
			file_name = dir.get_next()
			continue

		# Obtener nombre del recurso
		var move_name: String = ""
		if resource.has_method("get"):
			# Intentar obtener Name primero
			var name_value: Variant = resource.get("Name")
			if name_value != null and str(name_value) != "":
				move_name = str(name_value)
			# Si no, usar internal_name
			else:
				var internal_name_value: Variant = resource.get("internal_name")
				if internal_name_value != null:
					var internal_name: String = str(internal_name_value)
					if internal_name != "":
						move_name = internal_name.capitalize()

		# Si no hay nombre, usar "Unknown"
		if move_name == "":
			move_name = "Unknown"

		# Limpiar nombre para que sea válido en nombres de archivo
		move_name = _sanitize_filename(move_name)

		# Construir nuevo nombre
		var new_name := "%03d - %s.tres" % [id, move_name]
		var new_path := moves_dir + "/" + new_name

		# Verificar que el nuevo nombre no exista ya
		if ResourceLoader.exists(new_path):
			print("El archivo %s ya existe, saltando %s" % [new_name, file_name])
			file_name = dir.get_next()
			continue

		# Renombrar usando el sistema de archivos
		var old_full_path := ProjectSettings.globalize_path(path)
		var new_full_path := ProjectSettings.globalize_path(new_path)

		var file_access := FileAccess.open(old_full_path, FileAccess.READ)
		if file_access == null:
			print("No se pudo abrir para leer: %s" % old_full_path)
			error_count += 1
			file_name = dir.get_next()
			continue

		var content := file_access.get_as_text()
		file_access.close()

		var write_access := FileAccess.open(new_full_path, FileAccess.WRITE)
		if write_access == null:
			print("No se pudo abrir para escribir: %s" % new_full_path)
			error_count += 1
			file_name = dir.get_next()
			continue

		write_access.store_string(content)
		write_access.close()

		# Eliminar archivo antiguo
		DirAccess.remove_absolute(old_full_path)

		# Actualizar el .import si existe
		var old_import := old_full_path + ".import"
		var new_import := new_full_path + ".import"
		if FileAccess.file_exists(old_import):
			DirAccess.rename_absolute(old_import, new_import)

		print("Renombrado: %s -> %s" % [file_name, new_name])
		renamed_count += 1

		file_name = dir.get_next()

	dir.list_dir_end()

	print("\n=== Resumen ===")
	print("Archivos renombrados: %d" % renamed_count)
	print("Errores: %d" % error_count)
	print("\n¡Recuerda recargar el proyecto en Godot!")

## Limpia un nombre para que sea válido en nombres de archivo
func _sanitize_filename(name: String) -> String:
	# Reemplazar caracteres no válidos
	var invalid_chars := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	var sanitized := name

	for char in invalid_chars:
		sanitized = sanitized.replace(char, "_")

	# Eliminar espacios al inicio y final
	sanitized = sanitized.strip_edges()

	# Si está vacío después de limpiar, usar "Unknown"
	if sanitized == "":
		sanitized = "Unknown"

	return sanitized

