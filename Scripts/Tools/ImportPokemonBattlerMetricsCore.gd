class_name ImportPokemonBattlerMetricsCore
extends RefCounted

## Essentials multiplica BattlerAltitude ×2 al aplicar; PK2D calibra en import.
const ALTITUDE_SCALE: int = 2

const SPECIAL_INTERNAL_TO_PBS := {
	"nidoran-f": "NIDORANfE",
	"nidoran-m": "NIDORANmA",
	"farfetchd": "FARFETCHD",
	"mr-mime": "MRMIME",
}


class ImportSummary:
	var updated: int = 0
	var skipped: int = 0
	var errors: int = 0
	var missing_bes: Array[String] = []
	var missing_metrics: Array[String] = []

	func format_report() -> String:
		var lines: PackedStringArray = [
			"========================================",
			"[ImportPokemonBattlerMetrics] Fin",
			"  actualizados=%d omitidos=%d errores=%d" % [updated, skipped, errors],
		]
		if not missing_bes.is_empty():
			lines.append("  sin BES (%d): %s" % [missing_bes.size(), ", ".join(missing_bes)])
		if not missing_metrics.is_empty():
			lines.append("  sin metrics (%d): %s" % [missing_metrics.size(), ", ".join(missing_metrics)])
		lines.append("========================================")
		return "\n".join(lines)


static func run(
	pokemon_txt_path: String,
	metrics_txt_path: String,
	pokemon_dir: String,
	start_id: int,
	end_id: int,
	dry_run: bool = false
) -> ImportSummary:
	var summary := ImportSummary.new()
	var bes := parse_pokemon_txt(pokemon_txt_path)
	var metrics := parse_metrics_txt(metrics_txt_path)
	if bes.is_empty():
		push_error("[ImportPokemonBattlerMetrics] No se pudo leer pokemon.txt: %s" % pokemon_txt_path)
		summary.errors += 1
		return summary
	if metrics.is_empty():
		push_error("[ImportPokemonBattlerMetrics] No se pudo leer pokemon_metrics.txt: %s" % metrics_txt_path)
		summary.errors += 1
		return summary

	print("========================================")
	print(
		"[ImportPokemonBattlerMetrics] Inicio (IDs %d-%d, DRY_RUN=%s)"
		% [start_id, end_id, dry_run]
	)
	print("  BES entries=%d | metrics entries=%d" % [bes.size(), metrics.size()])
	print("========================================")

	for species_id in range(start_id, end_id + 1):
		var tres_path := resolve_pokemon_tres_path(pokemon_dir, species_id)
		if tres_path.is_empty():
			push_warning("[ImportPokemonBattlerMetrics] No hay .tres para id=%d" % species_id)
			summary.skipped += 1
			continue

		var res := load(tres_path)
		if res == null or not (res is PokemonData):
			push_error("[ImportPokemonBattlerMetrics] No es PokemonData: %s" % tres_path)
			summary.errors += 1
			continue

		var pd := res as PokemonData
		var pbs_key := internal_name_to_pbs_key(pd.internal_name)
		if pbs_key.is_empty():
			push_warning("[ImportPokemonBattlerMetrics] internal_name vacío en %s" % tres_path)
			summary.skipped += 1
			continue

		var bes_entry: Dictionary = bes.get(pbs_key, {})
		var metrics_entry: Dictionary = metrics.get(pbs_key, {})
		if bes_entry.is_empty():
			summary.missing_bes.append(pbs_key)
		if metrics_entry.is_empty():
			summary.missing_metrics.append(pbs_key)

		var raw_altitude := int(bes_entry.get("battler_altitude", 0))
		var new_altitude := raw_altitude * ALTITUDE_SCALE
		var new_shadow_size := int(metrics_entry.get("shadow_size", pd.shadow_size))
		var new_shadow_x := int(metrics_entry.get("shadow_x", pd.shadow_x))

		if dry_run:
			print(
				"[DRY] id=%d %s | alt=%d shadow=%d x=%d | %s"
				% [species_id, pbs_key, new_altitude, new_shadow_size, new_shadow_x, tres_path]
			)
			summary.updated += 1
			continue

		pd.battlerAltitude = new_altitude
		pd.shadow_size = new_shadow_size
		pd.shadow_x = new_shadow_x

		var err := ResourceSaver.save(pd, tres_path)
		if err != OK:
			push_error("[ImportPokemonBattlerMetrics] Error guardando %s: %d" % [tres_path, err])
			summary.errors += 1
		else:
			summary.updated += 1
			print(
				"[ImportPokemonBattlerMetrics] OK id=%d %s alt=%d shadow=%d x=%d"
				% [species_id, pbs_key, pd.battlerAltitude, pd.shadow_size, pd.shadow_x]
			)

	return summary


static func internal_name_to_pbs_key(internal_name: String) -> String:
	var key := internal_name.strip_edges().to_lower()
	if key.is_empty():
		return ""
	if SPECIAL_INTERNAL_TO_PBS.has(key):
		return SPECIAL_INTERNAL_TO_PBS[key]
	return key.to_upper().replace("-", "")


static func parse_pokemon_txt(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var out: Dictionary = {}
	var current_key := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("InternalName="):
			current_key = line.substr("InternalName=".length()).strip_edges()
			out[current_key] = {"battler_altitude": 0}
		elif not current_key.is_empty() and line.begins_with("BattlerAltitude="):
			var value := line.substr("BattlerAltitude=".length()).strip_edges()
			out[current_key]["battler_altitude"] = int(value)
	return out


static func parse_metrics_txt(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var out: Dictionary = {}
	var current_key := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current_key = line.substr(1, line.length() - 2).strip_edges()
			out[current_key] = {"shadow_size": 0, "shadow_x": 0}
			continue
		if current_key.is_empty():
			continue
		var parts := line.split("=", false, 1)
		if parts.size() != 2:
			continue
		var field := parts[0].strip_edges()
		var value := parts[1].strip_edges()
		if field == "ShadowSize":
			out[current_key]["shadow_size"] = int(value)
		elif field == "ShadowX":
			out[current_key]["shadow_x"] = int(value)
	return out


static func resolve_pokemon_tres_path(pokemon_dir: String, species_id: int) -> String:
	var prefix := "%03d" % species_id
	var dir := DirAccess.open(pokemon_dir)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			if file_name.begins_with(prefix):
				dir.list_dir_end()
				return pokemon_dir.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return ""
