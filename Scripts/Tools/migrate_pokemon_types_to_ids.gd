@tool
extends EditorScript

## Script de migración para convertir referencias Resource a IDs en PokemonData
## Extrae los IDs de type_a y type_b antes de eliminarlos para no perder información
## Ejecutar desde: Editor > Tools > Execute Script

func _run() -> void:
	print("[MigratePokemonTypes] ========================================")
	print("[MigratePokemonTypes] Iniciando migración de tipos a IDs...")
	print("[MigratePokemonTypes] ========================================")

	var pokemon_dir := "res://Resources/Data/Pokemon"
	var dir := DirAccess.open(pokemon_dir)

	if dir == null:
		push_error("[MigratePokemonTypes] No se pudo abrir directorio: %s" % pokemon_dir)
		return

	var migrated_type_a := 0
	var migrated_type_b := 0
	var error_count := 0
	var skipped_count := 0

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue

		var file_path := pokemon_dir + "/" + file_name
		if not ResourceLoader.exists(file_path):
			file_name = dir.get_next()
			continue

		# Cargar el recurso
		var pokemon_data = load(file_path) as PokemonData
		if not pokemon_data:
			print("[MigratePokemonTypes] ⚠️ No se pudo cargar: %s" % file_path)
			error_count += 1
			file_name = dir.get_next()
			continue

		var needs_save := false

		# 1. Migrar type_a (Resource) -> type_a_id (int)
		if pokemon_data.type_a_id == 0:
			var type_resource = pokemon_data.get("type_a") as Resource
			if type_resource and type_resource is TypeData:
				var type_id_value = (type_resource as TypeData).id
				if type_id_value > 0:
					pokemon_data.type_a_id = type_id_value
					needs_save = true
					migrated_type_a += 1
					print("[MigratePokemonTypes] ✓ type_a migrado en %s: %d" % [file_name, type_id_value])

		# 2. Migrar type_b (Resource) -> type_b_id (int)
		if pokemon_data.type_b_id == 0:
			var type_resource = pokemon_data.get("type_b") as Resource
			if type_resource and type_resource is TypeData:
				var type_id_value = (type_resource as TypeData).id
				if type_id_value > 0:
					pokemon_data.type_b_id = type_id_value
					needs_save = true
					migrated_type_b += 1
					print("[MigratePokemonTypes] ✓ type_b migrado en %s: %d" % [file_name, type_id_value])

		# Guardar solo si hubo cambios
		if needs_save:
			var save_error := ResourceSaver.save(pokemon_data, file_path)
			if save_error == OK:
				print("[MigratePokemonTypes] ✓ Guardado: %s" % file_name)
			else:
				print("[MigratePokemonTypes] ✗ Error guardando: %s (error: %d)" % [file_name, save_error])
				error_count += 1
		else:
			skipped_count += 1

		file_name = dir.get_next()

	dir.list_dir_end()

	print("[MigratePokemonTypes] ========================================")
	print("[MigratePokemonTypes] Migración completada:")
	print("[MigratePokemonTypes]   - Types A migrados: %d" % migrated_type_a)
	print("[MigratePokemonTypes]   - Types B migrados: %d" % migrated_type_b)
	print("[MigratePokemonTypes]   - Omitidos: %d" % skipped_count)
	print("[MigratePokemonTypes]   - Errores: %d" % error_count)
	print("[MigratePokemonTypes] ========================================")
	print("[MigratePokemonTypes] NOTA: Las referencias Resource antiguas (type_a, type_b)")
	print("[MigratePokemonTypes] se mantienen para compatibilidad. Se pueden eliminar después")
	print("[MigratePokemonTypes] de verificar que todo funciona correctamente.")
	print("[MigratePokemonTypes] ========================================")
