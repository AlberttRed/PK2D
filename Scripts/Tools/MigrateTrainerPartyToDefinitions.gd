@tool
extends EditorScript

## Migra TrainerData.party_data de Array[Pokemon] a Array[PokemonDefinition]
##
## Este script convierte los trainers existentes para usar PokemonDefinition
## en lugar de Pokemon runtime directamente.
##
## Uso:
## 1. Abrir este script en el editor
## 2. Script > Run
## 3. Revisar el reporte generado
##
## IMPORTANTE: Hacer backup de los trainers antes de ejecutar

@export var dry_run: bool = true  # Si es true, solo muestra lo que haría sin guardar
@export var trainers_dir: String = "res://Resources/Trainers"

func _run() -> void:
	print("[MigrateTrainerPartyToDefinitions] Inicio")
	print("dry_run = ", dry_run)
	print("trainers_dir = ", trainers_dir)
	print("")

	var dir = DirAccess.open(trainers_dir)
	if dir == null:
		push_error("[MigrateTrainerPartyToDefinitions] No se pudo abrir directorio: " + trainers_dir)
		return

	var trainer_paths: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			trainer_paths.append(trainers_dir + "/" + file_name)
		file_name = dir.get_next()

	print("[MigrateTrainerPartyToDefinitions] Encontrados ", trainer_paths.size(), " trainers")
	print("")

	var migrated_count = 0
	var skipped_count = 0
	var error_count = 0
	var report_lines: Array[String] = []
	report_lines.append("=== Reporte de Migración TrainerData ===")
	report_lines.append("dry_run: " + str(dry_run))
	report_lines.append("trainers_dir: " + trainers_dir)
	report_lines.append("")

	for trainer_path in trainer_paths:
		print("Procesando: ", trainer_path)

		var trainer_data = load(trainer_path) as TrainerData
		if trainer_data == null:
			push_warning("[MigrateTrainerPartyToDefinitions] No se pudo cargar: " + trainer_path)
			error_count += 1
			report_lines.append("ERROR: " + trainer_path + " - No se pudo cargar")
			continue

		# Verificar si ya está migrado (tiene PokemonDefinition)
		var needs_migration = false
		var pokemon_count = 0
		var definition_count = 0
		var null_count = 0

		for item in trainer_data.party_data:
			if item == null:
				null_count += 1
			elif item is Pokemon:
				pokemon_count += 1
				needs_migration = true
			elif item is PokemonDefinition:
				definition_count += 1

		if not needs_migration:
			var reason = "Ya migrado"
			if trainer_data.party_data.is_empty():
				reason = "Sin party_data"
			elif pokemon_count == 0 and definition_count > 0:
				reason = "Ya migrado (tiene " + str(definition_count) + " PokemonDefinition)"
			print("  -> ", reason, ", saltando (Pokemon: ", pokemon_count, ", PokemonDefinition: ", definition_count, ", null: ", null_count, ")")
			skipped_count += 1
			report_lines.append("SKIP: " + trainer_path + " - " + reason + " (Pokemon: " + str(pokemon_count) + ", PokemonDefinition: " + str(definition_count) + ")")
			continue

		# Migrar party_data
		var old_party: Array = trainer_data.party_data.duplicate()
		var new_party: Array[PokemonDefinition] = []

		for pokemon in old_party:
			if pokemon == null:
				continue

			if not (pokemon is Pokemon):
				# Ya es PokemonDefinition o tipo desconocido, mantenerlo
				new_party.append(pokemon)
				continue

			var pokemon_runtime = pokemon as Pokemon

			# Crear PokemonDefinition desde Pokemon
			var definition = PokemonDefinition.new()

			# Copiar campos básicos
			definition.pokemon_id = pokemon_runtime.pokemon_id
			definition.level = pokemon_runtime.level
			definition.nickname = pokemon_runtime.nickname
			definition.gender = pokemon_runtime.gender
			definition.shiny = pokemon_runtime.shiny
			definition.is_wild = pokemon_runtime.is_wild

			# Copiar IVs (no aleatorizar, usar valores existentes)
			definition.randomize_ivs = false
			definition.hp_IVs = pokemon_runtime.hp_IVs
			definition.attack_IVs = pokemon_runtime.attack_IVs
			definition.defense_IVs = pokemon_runtime.defense_IVs
			definition.spAttack_IVs = pokemon_runtime.spAttack_IVs
			definition.spDefense_IVs = pokemon_runtime.spDefense_IVs
			definition.speed_IVs = pokemon_runtime.speed_IVs

			# Copiar EVs (no aleatorizar, usar valores existentes)
			definition.randomize_evs = false
			definition.hp_EVs = pokemon_runtime.hp_EVs
			definition.attack_EVs = pokemon_runtime.attack_EVs
			definition.defense_EVs = pokemon_runtime.defense_EVs
			definition.spAttack_EVs = pokemon_runtime.spAttack_EVs
			definition.spDefense_EVs = pokemon_runtime.spDefense_EVs
			definition.speed_EVs = pokemon_runtime.speed_EVs

			# Copiar naturaleza y habilidad
			definition.nature_id = pokemon_runtime.nature_id
			definition.ability_id = pokemon_runtime.ability_id

			# Copiar movimientos personalizados
			definition.custom_move_ids = pokemon_runtime.custom_move_ids.duplicate()

			# Copiar objeto equipado
			definition.held_item_id = pokemon_runtime.held_item_id

			new_party.append(definition)
			# Mostrar información del Pokemon migrado
			# Usar pokemon_id directamente ya que base puede no estar cargado
			var pokemon_name = PokemonsEnum.get_display_name(pokemon_runtime.pokemon_id)
			if pokemon_name == "":
				pokemon_name = "Pokemon ID " + str(pokemon_runtime.pokemon_id)
			var display_name = pokemon_name
			if not pokemon_runtime.nickname.is_empty():
				display_name = pokemon_runtime.nickname + " (" + pokemon_name + ")"
			display_name += " Lv." + str(pokemon_runtime.level)
			print("  -> Migrado: ", display_name)

		# Actualizar party_data
		trainer_data.party_data = new_party

		if dry_run:
			print("  -> (DRY RUN) Se migrarían ", old_party.size(), " Pokemon a PokemonDefinition")
			report_lines.append("DRY RUN: " + trainer_path + " - " + str(old_party.size()) + " Pokemon migrados")
		else:
			# Guardar trainer actualizado
			var error = ResourceSaver.save(trainer_data, trainer_path)
			if error == OK:
				print("  -> Guardado exitosamente")
				migrated_count += 1
				report_lines.append("OK: " + trainer_path + " - " + str(old_party.size()) + " Pokemon migrados")
			else:
				push_error("[MigrateTrainerPartyToDefinitions] Error guardando " + trainer_path + ": " + str(error))
				error_count += 1
				report_lines.append("ERROR: " + trainer_path + " - Error al guardar: " + str(error))

		print("")

	# Resumen
	print("=== Resumen ===")
	print("Migrados: ", migrated_count)
	print("Saltados: ", skipped_count)
	print("Errores: ", error_count)
	print("")

	report_lines.append("")
	report_lines.append("=== Resumen ===")
	report_lines.append("Migrados: " + str(migrated_count))
	report_lines.append("Saltados: " + str(skipped_count))
	report_lines.append("Errores: " + str(error_count))

	# Guardar reporte
	var report_path = "res://Scripts/Tools/MigrateTrainerParty_report.txt"
	var file = FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(report_lines) + "\n")
		file.close()
		print("Reporte guardado en: ", report_path)
	else:
		push_warning("No se pudo guardar el reporte en " + report_path)

	# Forzar reescaneo del filesystem
	var fs = get_editor_interface().get_resource_filesystem()
	if fs:
		fs.scan()

	print("[MigrateTrainerPartyToDefinitions] Fin")
