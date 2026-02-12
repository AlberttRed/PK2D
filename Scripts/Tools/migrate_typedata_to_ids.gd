@tool
extends EditorScript

## Script para migrar TypeData de Array[Resource] a Array[int]
## Convierte los arrays de referencias a TypeData en arrays de IDs
## Uso: abrir en el editor y ejecutar (Script > Run)

const TYPES_DIR := "res://Resources/Data/Types"

func _run() -> void:
	print("========================================")
	print("[MigrateTypeData] Iniciando migración...")
	print("========================================")

	var migrated_count := 0
	var error_count := 0
	var total_subresources_removed := 0

	# Procesar cada archivo TypeData
	for i in range(1, 19):
		var file_path := TYPES_DIR + "/%02d.tres" % i
		if not ResourceLoader.exists(file_path):
			continue

		print("\n[MigrateTypeData] Procesando: %s" % file_path)

		# Cargar el recurso
		var type_data := load(file_path) as TypeData
		if type_data == null:
			push_error("[MigrateTypeData] No se pudo cargar: %s" % file_path)
			error_count += 1
			continue

		# Contar sub-recursos antes
		var subresources_before := _count_subresources_in_file(file_path)

		# Convertir arrays de Resource a Array[int]
		var no_effect_from_array = type_data.get("no_effect_from")
		var resistance_array = type_data.get("resistance")
		var weakness_array = type_data.get("weakness")
		var no_effect_to_array = type_data.get("no_effect_to")
		var ineffective_array = type_data.get("ineffective")
		var super_effective_array = type_data.get("super_effective")

		# Extraer IDs y asignar usando set() para forzar el cambio de tipo
		var no_effect_from_ids: Array[int] = _extract_ids_from_resources(no_effect_from_array if no_effect_from_array != null else [])
		var resistance_ids: Array[int] = _extract_ids_from_resources(resistance_array if resistance_array != null else [])
		var weakness_ids: Array[int] = _extract_ids_from_resources(weakness_array if weakness_array != null else [])
		var no_effect_to_ids: Array[int] = _extract_ids_from_resources(no_effect_to_array if no_effect_to_array != null else [])
		var ineffective_ids: Array[int] = _extract_ids_from_resources(ineffective_array if ineffective_array != null else [])
		var super_effective_ids: Array[int] = _extract_ids_from_resources(super_effective_array if super_effective_array != null else [])

		# Usar set() para forzar el cambio de tipo de la propiedad
		type_data.set("no_effect_from", no_effect_from_ids)
		type_data.set("resistance", resistance_ids)
		type_data.set("weakness", weakness_ids)
		type_data.set("no_effect_to", no_effect_to_ids)
		type_data.set("ineffective", ineffective_ids)
		type_data.set("super_effective", super_effective_ids)

		# Guardar el recurso
		var err := ResourceSaver.save(type_data, file_path)
		if err != OK:
			push_error("[MigrateTypeData] Error guardando %s: %d" % [file_path, err])
			error_count += 1
			continue

		# Contar sub-recursos después
		var subresources_after := _count_subresources_in_file(file_path)
		var removed := subresources_before - subresources_after
		total_subresources_removed += removed

		print("[MigrateTypeData] ✓ Migrado: %s (eliminados %d sub-recursos)" % [file_path.get_file(), removed])
		migrated_count += 1

	# Forzar reescaneo del sistema de archivos del editor
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()

	print("\n========================================")
	print("[MigrateTypeData] Migración completada!")
	print("========================================")
	print("Archivos migrados: %d" % migrated_count)
	print("Errores: %d" % error_count)
	print("Total sub-recursos eliminados: %d" % total_subresources_removed)
	print("========================================")

## Extrae IDs de un array de Resources
func _extract_ids_from_resources(resources: Array) -> Array[int]:
	var ids: Array[int] = []

	if resources == null:
		return ids

	for item in resources:
		if item == null:
			continue

		var id_value: int = 0

		# Intentar diferentes formas de acceder al ID
		if item is Resource:
			var resource := item as Resource

			# Si es TypeData, intentar acceder directamente
			if resource is TypeData:
				var type_data := resource as TypeData
				id_value = type_data.id
			else:
				# Para otros recursos, intentar obtener el ID con get() directamente
				var id_variant = resource.get("id")
				if id_variant != null:
					id_value = int(id_variant)
		elif typeof(item) == TYPE_DICTIONARY:
			# Si es un diccionario, acceder directamente
			var dict := item as Dictionary
			if dict.has("id"):
				id_value = int(dict["id"])

		if id_value > 0:
			ids.append(id_value)

	return ids

## Cuenta sub-recursos en un archivo .tres (aproximado)
func _count_subresources_in_file(file_path: String) -> int:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0

	var count := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("[sub_resource"):
			count += 1

	file.close()
	return count
