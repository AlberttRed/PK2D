## Clase Move (runtime)
## Representa un movimiento "vivo" durante el juego
## Se crea a partir de un MoveData y contiene propiedades runtime como PP actual
## Es un Resource para poder exportarlo, guardarlo como .tres y configurarlo desde el inspector
extends Resource
class_name Move

# Referencia al dato base (Resource estático)
var base: MoveData

# Propiedades runtime
var pp: int = 5
var pp_actual: int = 5
var mod_pp: int = 0

## Constructor
## @param _move_data: MoveData o int (id del movimiento)
func _init(_move_data) -> void:
	if _move_data is int:
		# Si se pasa un ID, cargar el MoveData desde DatabaseManager
		base = DatabaseManager.get_move(_move_data)
	elif _move_data is MoveData:
		# Si se pasa directamente un MoveData
		base = _move_data
	else:
		push_error("Move._init: Parámetro inválido. Debe ser MoveData o int")
		return
	
	if base:
		pp = base.pp
		pp_actual = pp

## Convierte a BattleMove para combate
func to_battle_move(pokemon):  # pokemon: BattlePokemon - evitamos referencia circular
	return BattleMove.new(self, pokemon)

## Getters para acceso a propiedades base
func get_id() -> int:
	return base.id

func get_move_name() -> String:
	return base.Name

func get_internal_name() -> String:
	return base.internal_name

func get_description() -> String:
	return base.description

func get_type() -> TypeData:
	return base.type as TypeData

func get_power() -> int:
	return base.power

func get_accuracy() -> int:
	return base.accuracy

func get_priority() -> int:
	return base.priority

func get_damage_class() -> int:
	return base.damage_class_id

func get_target_id() -> int:
	return base.target_id

func get_category() -> BattleMoveCategory:
	return base.category

func get_category_id() -> int:
	return base.meta_category_id

func get_ailment() -> AilmentData:
	return base.ailment

func get_ailment_chance() -> int:
	return base.meta_ailment_chance

func get_weather() -> WeatherData:
	return base.weather

func get_stat_changes() -> Dictionary[StatsEnum.Values, int]:
	return base.stat_changes

func get_min_hits() -> int:
	return base.meta_min_hits

func get_max_hits() -> int:
	return base.meta_max_hits

func get_min_turns() -> int:
	return base.meta_min_turns

func get_max_turns() -> int:
	return base.meta_max_turns

func get_critical_rate() -> int:
	return base.meta_crit_rate

func get_drain_percentage() -> int:
	return base.meta_drain

func get_heal_amount() -> int:
	return base.meta_healing

func get_move_effect_script() -> Script:
	return base.move_effect

## Helpers
func has_contact() -> bool:
	return base.contact_flag

func is_special() -> bool:
	return base.damage_class_id == CONST.DAMAGE_CLASS.ESPECIAL

func print_move() -> void:
	print(" ------ %s %d/%d PP ------ " % [get_move_name(), pp_actual, pp])

func _to_string() -> String:
	return get_move_name()
