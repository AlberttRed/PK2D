@tool
extends EditorScript

## Script de migración para convertir referencias Resource a IDs en MoveData
## Extrae los IDs antes de eliminar las referencias para no perder información
## Ejecutar desde: Editor > Tools > Execute Script

func _run() -> void:
	print("[MigrateMoveSubresources] ========================================")
	print("[MigrateMoveSubresources] Iniciando migración de subrecursos a IDs...")
	print("[MigrateMoveSubresources] ========================================")

	var moves_dir := "res://Resources/Data/Moves"
	var dir := DirAccess.open(moves_dir)

	if dir == null:
		push_error("[MigrateMoveSubresources] No se pudo abrir directorio: %s" % moves_dir)
		return

	var migrated_type := 0
	var migrated_ailment := 0
	var migrated_weather := 0
	var error_count := 0
	var skipped_count := 0

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue

		var file_path := moves_dir + "/" + file_name
		if not ResourceLoader.exists(file_path):
			file_name = dir.get_next()
			continue

		# Cargar el recurso
		var move_data = load(file_path) as MoveData
		if not move_data:
			print("[MigrateMoveSubresources] ⚠️ No se pudo cargar: %s" % file_path)
			error_count += 1
			file_name = dir.get_next()
			continue

		var needs_save := false

		# 1. Migrar type (Resource) -> type_id (int)
		if move_data.type_id == 0:
			var type_resource = move_data.get("type") as Resource
			if type_resource and type_resource is TypeData:
				var type_id_value = (type_resource as TypeData).id
				if type_id_value > 0:
					move_data.type_id = type_id_value
					needs_save = true
					migrated_type += 1
					print("[MigrateMoveSubresources] ✓ type migrado en %s: %d" % [file_name, type_id_value])

		# 2. Migrar ailment (AilmentData) -> ailment_id (int)
		if move_data.ailment_id == 0:
			var ailment_resource = move_data.get("ailment") as Resource
			if ailment_resource and ailment_resource is AilmentData:
				var ailment_id_value = (ailment_resource as AilmentData).id
				if ailment_id_value > 0:
					move_data.ailment_id = ailment_id_value
					needs_save = true
					migrated_ailment += 1
					print("[MigrateMoveSubresources] ✓ ailment migrado en %s: %d" % [file_name, ailment_id_value])

		# 3. Migrar weather (WeatherData) -> weather_id (int)
		if move_data.weather_id == 0:
			var weather_resource = move_data.get("weather") as Resource
			if weather_resource and weather_resource is WeatherData:
				var weather_id_value = (weather_resource as WeatherData).id
				if weather_id_value > 0:
					move_data.weather_id = weather_id_value
					needs_save = true
					migrated_weather += 1
					print("[MigrateMoveSubresources] ✓ weather migrado en %s: %d" % [file_name, weather_id_value])

		# Guardar solo si hubo cambios
		if needs_save:
			var save_error := ResourceSaver.save(move_data, file_path)
			if save_error == OK:
				print("[MigrateMoveSubresources] ✓ Guardado: %s" % file_name)
			else:
				print("[MigrateMoveSubresources] ✗ Error guardando: %s (error: %d)" % [file_name, save_error])
				error_count += 1
		else:
			skipped_count += 1

		file_name = dir.get_next()

	dir.list_dir_end()

	print("[MigrateMoveSubresources] ========================================")
	print("[MigrateMoveSubresources] Migración completada:")
	print("[MigrateMoveSubresources]   - Types migrados: %d" % migrated_type)
	print("[MigrateMoveSubresources]   - Ailments migrados: %d" % migrated_ailment)
	print("[MigrateMoveSubresources]   - Weathers migrados: %d" % migrated_weather)
	print("[MigrateMoveSubresources]   - Omitidos: %d" % skipped_count)
	print("[MigrateMoveSubresources]   - Errores: %d" % error_count)
	print("[MigrateMoveSubresources] ========================================")
	print("[MigrateMoveSubresources] NOTA: Las referencias Resource antiguas (type, ailment, weather)")
	print("[MigrateMoveSubresources] se mantienen para compatibilidad. Se pueden eliminar después")
	print("[MigrateMoveSubresources] de verificar que todo funciona correctamente.")
	print("[MigrateMoveSubresources] ========================================")
