extends Resource

class_name PokemonEvolutionRow

## Una posible evolución desde esta especie (misma fila que en PokeAPI `evolution_detail` + especie destino).

@export var method: int = 0
@export var target_species_id: int = 0
@export var trigger_raw: String = ""

@export var min_level: int = 0
@export var min_happiness: int = -1
@export var min_affection: int = -1
@export var min_beauty: int = -1
@export var gender_id: int = 0
@export var relative_physical_stats: int = -999

@export var needs_overworld_rain: bool = false
@export var turn_upside_down: bool = false
@export var time_of_day: String = ""

@export var item_id: int = 0
@export var held_item_id: int = 0
@export var trade_species_id: int = 0
@export var location_id: int = 0
@export var known_move_id: int = 0
@export var known_move_type_id: int = 0
@export var party_species_id: int = 0
@export var party_type_id: int = 0
