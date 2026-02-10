@tool
extends EditorScript

## Script para actualizar las rutas de los iconos de items después de mover los atlas
## Actualiza las referencias de la ruta antigua a la nueva

const ITEMS_DIR := "res://Resources/Data/Items"
const OLD_ATLAS_PATH := "res://Resources/Data/Items/Icons/Atlases"
const NEW_ATLAS_PATH := "res://Sprites/Iconos/Items"

func _run() -> void:
	print("========================================")
	print("[UpdateItemIconPaths] Iniciando actualización de rutas...")
	print("========================================")

	var updated_count := 0
	var error_count := 0

	# Buscar todos los ItemData
	for i in range(1, 1000):
		var file_path := ITEMS_DIR + "/%03d.tres" % i
		if not ResourceLoader.exists(file_path):
			continue

		var item_resource := load(file_path)
		if item_resource == null:
			continue

		# Verificar si tiene icono
		if not item_resource.has("icon"):
			continue

		var icon := item_resource.get("icon")
		if icon == null:
			continue

		# Verificar si es un AtlasTexture
		if not (icon is AtlasTexture):
			continue

		var atlas_tex := icon as AtlasTexture
		var atlas := atlas_tex.atlas

		if atlas == null:
			continue

		# Obtener la ruta del atlas
		var atlas_path := atlas.resource_path
		if atlas_path == "":
			continue

		# Si la ruta contiene la ruta antigua, actualizarla
		if atlas_path.contains(OLD_ATLAS_PATH):
			var new_atlas_path := atlas_path.replace(OLD_ATLAS_PATH, NEW_ATLAS_PATH)

			# Cargar el nuevo atlas
			var new_atlas := load(new_atlas_path) as Texture2D
			if new_atlas == null:
				push_warning("[UpdateItemIconPaths] No se pudo cargar nuevo atlas: %s" % new_atlas_path)
				error_count += 1
				continue

			# Actualizar la referencia
			atlas_tex.atlas = new_atlas
			item_resource.set("icon", atlas_tex)

			# Guardar
			var save_error := ResourceSaver.save(item_resource, file_path)
			if save_error == OK:
				updated_count += 1
				print("[UpdateItemIconPaths] ✓ Actualizado item %03d: %s" % [i, new_atlas_path])
			else:
				push_error("[UpdateItemIconPaths] Error guardando item %03d: %d" % [i, save_error])
				error_count += 1

	print("========================================")
	print("[UpdateItemIconPaths] RESUMEN")
	print("========================================")
	print("Items actualizados: %d" % updated_count)
	print("Errores: %d" % error_count)
	print("========================================")

	# Refrescar filesystem del editor
	EditorInterface.get_resource_filesystem().scan()

