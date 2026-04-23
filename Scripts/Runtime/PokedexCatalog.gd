extends RefCounted
class_name PokedexCatalog

const _DEX_DISPLAY_NAMES := {
	"kanto": "Pokédex Kanto",
	"original-johto": "Pokédex Johto",
	"updated-johto": "Pokédex Johto",
	"national": "Pokédex Nacional",
}

## Definiciones mínimas de Pokédex (sin datos externos).
## Más adelante, los números/orden por dex se podrán poblar desde PokéAPI.
static func get_all_dex_definitions() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	defs.append(_build_definition_from_pokemon_data("kanto", "Pokédex Kanto", 1, 151))
	# Priorizar updated-johto; fallback a original-johto.
	var johto := _build_definition_from_pokemon_data("updated-johto", "Pokédex Johto", 152, 251)
	if johto.get("entries", []).is_empty():
		johto = _build_definition_from_pokemon_data("original-johto", "Pokédex Johto", 152, 251)
	defs.append(johto)
	defs.append(_build_definition_from_pokemon_data("national", "Pokédex Nacional", 1, 9999))
	return defs


static func get_definition_by_id(dex_id: String) -> Dictionary:
	for dex_def in get_all_dex_definitions():
		if str(dex_def.get("id", "")) == dex_id:
			return dex_def
	return {}


static func _build_definition_from_pokemon_data(
	dex_id: String,
	display_name: String,
	fallback_min_species_id: int,
	fallback_max_species_id: int
) -> Dictionary:
	var all_species: Array[PokemonData] = DatabaseService.get_all_pokemon_sorted()
	var entries: Array[Dictionary] = []
	var from_api: Array[Dictionary] = []
	var from_fallback: Array[Dictionary] = []
	for pd in all_species:
		if pd == null:
			continue
		var species_id := int(pd.id)
		if species_id <= 0:
			continue
		var dex_number := 0
		if typeof(pd.pokedex_numbers) == TYPE_DICTIONARY and pd.pokedex_numbers.has(dex_id):
			dex_number = int(pd.pokedex_numbers.get(dex_id, 0))
		if dex_number > 0:
			from_api.append({"species_id": species_id, "dex_number": dex_number})
			continue
		if species_id >= fallback_min_species_id and species_id <= fallback_max_species_id:
			from_fallback.append({"species_id": species_id, "dex_number": species_id})

	if not from_api.is_empty():
		from_api.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da: int = int(a.get("dex_number", 99999))
			var db: int = int(b.get("dex_number", 99999))
			if da != db:
				return da < db
			return int(a.get("species_id", 99999)) < int(b.get("species_id", 99999))
		)
		entries = from_api
	else:
		from_fallback.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var sa: int = int(a.get("species_id", 99999))
			var sb: int = int(b.get("species_id", 99999))
			return sa < sb
		)
		for i in range(from_fallback.size()):
			var e: Dictionary = from_fallback[i]
			entries.append({
				"species_id": int(e.get("species_id", 0)),
				"dex_number": i + 1,
			})

	return {
		"id": dex_id,
		"display_name": _DEX_DISPLAY_NAMES.get(dex_id, display_name),
		"entries": entries,
	}
