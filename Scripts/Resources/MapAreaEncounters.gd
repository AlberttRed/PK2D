extends Node
class_name MapAreaEncounters
## Contiene todos los grupos de encuentros salvajes de un mapa específico.
## Cada mapa puede tener múltiples tipos de áreas (hierba, agua, cueva, etc.)
## Este nodo gestiona todos los encuentros posibles y debe tener como hijos
## nodos de tipo AreaEncounter.


## Valida todos los AreaEncounter del mapa (nodos hijos)
func validate() -> bool:
	var area_encounters := _get_area_encounter_nodes()
	
	if area_encounters.is_empty():
		push_warning("MapAreaEncounters: No hay áreas de encuentro definidas (sin nodos AreaEncounter hijos)")
		return true  # No es un error, solo un mapa sin encuentros
	
	var area_types_seen := {}
	
	for area in area_encounters:
		# Verificar que no haya áreas duplicadas
		var type_key: EncounterAreaTypeEnum.Values = area.area_type
		if type_key in area_types_seen:
			push_error("MapAreaEncounters: Tipo de área duplicado: %s" % EncounterAreaTypeEnum.get_type_name(area.area_type))
			return false
		area_types_seen[type_key] = true
		
		# Validar el área
		if not area.validate():
			return false
	
	return true


## Obtiene todos los nodos hijos de tipo AreaEncounter
func _get_area_encounter_nodes() -> Array[AreaEncounter]:
	var encounters: Array[AreaEncounter] = []
	for child in get_children():
		if child is AreaEncounter:
			encounters.append(child as AreaEncounter)
	return encounters


## Obtiene el AreaEncounter para un tipo de área específico
func get_area_encounter(area_type: EncounterAreaTypeEnum.Values) -> AreaEncounter:
	for child in get_children():
		if child is AreaEncounter:
			var area := child as AreaEncounter
			if area.area_type == area_type:
				return area
	return null


## Intenta generar un encuentro salvaje para el tipo de área dado
## Retorna un diccionario con los datos del encuentro si tiene éxito, o null si no
## Formato: { "pokemon_id": int, "level": int, "area_type": EncounterAreaTypeEnum.Values }
func try_wild_encounter(area_type: EncounterAreaTypeEnum.Values) -> Dictionary:
	var area: AreaEncounter = get_area_encounter(area_type)
	if area == null:
		return {}
	
	# Verificar si debe ocurrir un encuentro
	if not area.should_trigger_encounter():
		return {}
	
	# Seleccionar un Pokémon aleatorio
	var pokemon_encounter: MapPokemonEncounter = area.get_random_pokemon()
	if pokemon_encounter == null:
		return {}
	
	# Generar el nivel aleatorio
	var level: int = pokemon_encounter.get_random_level()
	
	return {
		"pokemon_id": pokemon_encounter.pokemon_id,
		"level": level,
		"area_type": area_type
	}


## Comprueba si un tipo de área tiene encuentros definidos
func has_encounters_for_area(area_type: EncounterAreaTypeEnum.Values) -> bool:
	return get_area_encounter(area_type) != null


## Obtiene información de debug de todas las áreas
func get_debug_info() -> String:
	var area_encounters := _get_area_encounter_nodes()
	
	if area_encounters.is_empty():
		return "MapAreaEncounters: Sin encuentros definidos"
	
	var info := "MapAreaEncounters:\n"
	for area in area_encounters:
		info += area.get_debug_info() + "\n"
	return info
