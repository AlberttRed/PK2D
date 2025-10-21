extends Node
class_name AreaEncounter
## Define un grupo de encuentros salvajes para un tipo de área específica
## (por ejemplo, hierba alta, agua, cueva).
## Incluye la probabilidad base de encuentro y la lista de Pokémon que pueden aparecer.
## 
## Este nodo debe ser hijo de un MapAreaEncounters.
## Los MapPokemonEncounter se definen como Resources en el array pokemon_encounters.
##
## IMPORTANTE: Si hay Pokémon definidos, sus probabilidades DEBEN sumar exactamente 100%

## Tipo de área donde ocurren estos encuentros
@export var area_type: EncounterAreaTypeEnum.Values = EncounterAreaTypeEnum.Values.LAND

## Probabilidad base de que ocurra un encuentro al pisar el tile (0-100%)
## Ejemplo: 10 = 10% de probabilidad por paso
@export_range(0.0, 100.0, 0.1) var base_encounter_rate: float = 10.0

## Lista de Pokémon que pueden aparecer en esta área
## Las probabilidades de todos los elementos deben sumar 100%
@export var pokemon_encounters: Array[MapPokemonEncounter] = []

## (Opcional) Filtro por hora del día
## Si está vacío, los encuentros ocurren a cualquier hora
## Valores posibles: "morning", "day", "evening", "night"
@export var time_of_day_filter: Array[String] = []


func _ready() -> void:
	# Validar automáticamente al cargar el mapa
	if not validate():
		push_error("AreaEncounter '%s' tiene errores de configuración. Revisa el output." % name)


## Valida que los datos del AreaEncounter sean correctos
func validate() -> bool:
	var area_name := EncounterAreaTypeEnum.get_type_name(area_type)
	
	# Si no hay Pokémon definidos, este AreaEncounter está vacío (warning, no error fatal)
	if pokemon_encounters.is_empty():
		push_warning("AreaEncounter [%s]: No hay Pokémon definidos. Este área no generará encuentros." % area_name)
		return true  # Válido pero vacío
	
	# Si hay al menos un Pokémon, validar todo estrictamente
	var has_valid_encounters := false
	
	# Validar que todos los MapPokemonEncounter sean válidos y no nulos
	for i in pokemon_encounters.size():
		var encounter: MapPokemonEncounter = pokemon_encounters[i]
		if encounter == null:
			push_error("AreaEncounter [%s]: El Pokémon en la posición %d es nulo. Elimínalo del array." % [area_name, i])
			return false
		if not encounter.is_valid():
			push_error("AreaEncounter [%s]: El Pokémon en la posición %d no es válido." % [area_name, i])
			return false
		has_valid_encounters = true
	
	# CRÍTICO: Si hay Pokémon definidos, las probabilidades DEBEN sumar exactamente 100%
	if has_valid_encounters:
		var total_probability := 0.0
		for encounter in pokemon_encounters:
			total_probability += encounter.probability
		
		# Permitir un pequeño margen de error por redondeo de floats (0.01%)
		var difference: float = abs(total_probability - 100.0)
		if difference > 0.01:
			push_error("AreaEncounter [%s]: ERROR CRÍTICO - Las probabilidades suman %.2f%% pero DEBEN sumar exactamente 100.0%% (diferencia: %.2f%%)" % [area_name, total_probability, difference])
			push_error("  → Revisa los valores de 'probability' en cada MapPokemonEncounter")
			return false
	
	return true


## Intenta generar un encuentro basado en la probabilidad base
## Retorna true si debe ocurrir un encuentro
func should_trigger_encounter() -> bool:
	if base_encounter_rate <= 0.0:
		return false
	
	# TODO: En el futuro, aquí se puede considerar la hora del día
	if not time_of_day_filter.is_empty():
		# Por ahora, si hay filtro de tiempo, siempre permitimos el encuentro
		# Esto se implementará cuando haya un sistema de tiempo del día
		pass
	
	var roll := randf_range(0.0, 100.0)
	return roll < base_encounter_rate


## Selecciona un Pokémon aleatorio de la lista basado en las probabilidades
## Retorna el MapPokemonEncounter seleccionado, o null si hay error
func get_random_pokemon() -> MapPokemonEncounter:
	if pokemon_encounters.is_empty():
		push_error("AreaEncounter [%s]: No hay Pokémon disponibles" % EncounterAreaTypeEnum.get_type_name(area_type))
		return null
	
	var roll := randf_range(0.0, 100.0)
	var accumulated := 0.0
	
	for encounter in pokemon_encounters:
		accumulated += encounter.probability
		if roll < accumulated:
			return encounter
	
	# Si llegamos aquí, algo salió mal con las probabilidades
	# Devolvemos el último por seguridad
	push_warning("AreaEncounter [%s]: Probabilidades incorrectas, devolviendo último Pokémon" % EncounterAreaTypeEnum.get_type_name(area_type))
	return pokemon_encounters[-1]


## Obtiene información de debug del área de encuentro
func get_debug_info() -> String:
	var area_name := EncounterAreaTypeEnum.get_type_name(area_type)
	var info := "AreaEncounter [%s]\n" % area_name
	info += "  Base Rate: %.1f%%\n" % base_encounter_rate
	
	if pokemon_encounters.is_empty():
		info += "  ⚠️ No hay Pokémon definidos\n"
		return info
	
	# Calcular total de probabilidades
	var total_probability := 0.0
	for encounter in pokemon_encounters:
		if encounter != null:
			total_probability += encounter.probability
	
	info += "  Pokémon (%d):\n" % pokemon_encounters.size()
	for encounter in pokemon_encounters:
		if encounter == null:
			info += "    ❌ NULL\n"
		else:
			info += "    - %s (Lv.%d-%d): %.1f%%\n" % [
				encounter.get_pokemon_name(),
				encounter.min_level,
				encounter.max_level,
				encounter.probability
			]
	
	# Mostrar validación de probabilidades
	var difference: float = abs(total_probability - 100.0)
	if difference > 0.01:
		info += "  ❌ TOTAL: %.2f%% (¡Debe ser 100.0%%! Diferencia: %.2f%%)\n" % [total_probability, difference]
	else:
		info += "  ✅ TOTAL: %.2f%% (OK)\n" % total_probability
	
	return info


## Muestra la validación en el output del editor (útil para debugging)
func print_validation() -> void:
	print("═══════════════════════════════════════")
	print(get_debug_info())
	if validate():
		print("✅ Validación: OK")
	else:
		print("❌ Validación: FALLÓ")
	print("═══════════════════════════════════════")
