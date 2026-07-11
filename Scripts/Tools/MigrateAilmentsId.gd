@tool
extends EditorScript

## Migra Ailment.tres al nuevo esquema: id:int (numérico) + internal_name:String
## Opciones:
##  - use_enum_ids: si true, asigna id desde AilmentsEnum.from_string(internal_name)
##  - mapping: diccionario opcional internal_name -> id (prioritario si existe)

@export var dry_run: bool = false
@export var base_dir: String = "res://Resources/Data/Ailments"
@export var use_enum_ids: bool = true
@export var mapping: Dictionary = {
	# PokeAPI ids
	"none": 0,
	"paralysis": 1,
	"sleep": 2,
	"freeze": 3,
	"burn": 4,
	"poison": 5,
	"confusion": 6,
	# Extras (no todos están implementados ingame aún)
	"infatuation": 7,
	"trap": 8,
	"nightmare": 9,
	"torment": 12,
	"disable": 13,
	"yawn": 14,
	"heal-block": 15,
	"no-type-immunity": 17,
	"leech-seed": 18,
	"embargo": 19,
	"perish-song": 20,
	"ingrain": 21,
}

func _run() -> void:
	print("[MigrateAilmentsId] Inicio. dry=", dry_run, " base_dir=", base_dir)
	var paths := _collect_ailment_paths(base_dir)
	print("[MigrateAilmentsId] Archivos Ailment: ", paths.size())
	var updated := 0
	var skipped := 0
	for p in paths:
		var res := ResourceLoader.load(p)
		if res == null:
			push_warning("[MigrateAilmentsId] No se pudo cargar: " + p)
			continue
		if not (res is AilmentData):
			skipped += 1
			continue
		var ail: AilmentData = res

		var old_id_any = ail.id
		var old_internal := ail.internal_name

		# Si el id era string legacy, en Godot 4 puede llegar como 0 por el cambio de tipo.
		# 1) Intento 1: si aún llega como string, migrar a internal_name
		if typeof(old_id_any) == TYPE_STRING:
			if (old_internal == null or old_internal == "") and old_id_any != "":
				ail.internal_name = str(old_id_any)
			ail.id = 0

		# 2) Intento 2 (fallback): si internal_name está vacío, inferirlo del nombre del archivo
		if (ail.internal_name == null or ail.internal_name == ""):
			var inferred := _infer_key_from_path(p)
			if inferred != "":
				ail.internal_name = inferred

		# Si id sigue en 0, intentar completar
		if ail.id == 0 and ail.internal_name != "":
			var key := ail.internal_name
			if mapping.has(key):
				ail.id = int(mapping[key])
			elif use_enum_ids:
				ail.id = AilmentsEnum.from_string(key)

		# Guardar solo si hay cambios y no es dry_run
		if not dry_run:
			var err := ResourceSaver.save(ail, p)
			if err != OK:
				push_error("[MigrateAilmentsId] Error guardando (" + str(err) + "): " + p)
				continue
		updated += 1
		print("[MigrateAilmentsId] ", ("(dry) " if dry_run else ""), p, " -> id=", ail.id, " internal_name=", ail.internal_name)

	print("[MigrateAilmentsId] Fin. updated=", updated, " skipped=", skipped)

func _collect_ailment_paths(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[MigrateAilmentsId] No se pudo abrir dir: " + dir_path)
		return result
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			if f.begins_with(".") or f == ".import":
				continue
			result.append_array(_collect_ailment_paths(dir_path.path_join(f)))
		else:
			if f.ends_with(".tres"):
				result.append(dir_path.path_join(f))
	dir.list_dir_end()
	return result

func _infer_key_from_path(p: String) -> String:
	var file := p.get_file()            # e.g., "paralysis.tres"
	var base := file.get_basename()     # e.g., "paralysis"
	var key := str(base).to_lower()
	key = key.replace("_", "-")       # normalizar a formato pokeapi
	return key
