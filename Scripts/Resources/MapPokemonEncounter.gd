extends Resource
class_name MapPokemonEncounter
## Representa un Pokémon que puede aparecer en un encuentro salvaje
## con su rango de niveles y probabilidad de aparición.

## ID del Pokémon (usando PokemonsEnum)
@export var pokemon_id: PokemonsEnum.Values = PokemonsEnum.Values.NONE

## Nivel mínimo del Pokémon al aparecer
@export_range(1, 100, 1) var min_level: int = 5

## Nivel máximo del Pokémon al aparecer
@export_range(1, 100, 1) var max_level: int = 5

## Probabilidad de que aparezca este Pokémon (porcentaje: 0-100)
## Todos los MapPokemonEncounter en un AreaEncounter deben sumar 100%
@export_range(0.0, 100.0, 0.1) var probability: float = 0.0


## Valida que el rango de niveles sea correcto
func is_valid() -> bool:
	if min_level < 1 or max_level < 1:
		push_error("MapPokemonEncounter: Los niveles deben ser al menos 1")
		return false
	
	if min_level > max_level:
		push_error("MapPokemonEncounter: min_level (%d) no puede ser mayor que max_level (%d)" % [min_level, max_level])
		return false
	
	if pokemon_id <= 0:
		push_error("MapPokemonEncounter: pokemon_id debe ser válido")
		return false
	
	return true


## Genera un nivel aleatorio dentro del rango definido
func get_random_level() -> int:
	if min_level == max_level:
		return min_level
	return randi_range(min_level, max_level)


## Obtiene el nombre del Pokémon para debug
func get_pokemon_name() -> String:
	if DatabaseManager and DatabaseManager.has_method("get_pokemon_data"):
		var pkmn_data = DatabaseManager.get_pokemon_data(pokemon_id)
		if pkmn_data:
			return pkmn_data.name
	return "Pokemon #%d" % pokemon_id

