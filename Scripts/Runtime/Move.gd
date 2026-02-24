## Clase Move (runtime)
##
## Representa un movimiento "vivo" durante el juego.
## Se crea a partir de un MoveData y mantiene estado runtime como PP actual.
## Es un Resource para poder exportarlo, guardarlo como .tres y configurarlo desde el inspector.
##
## Uso típico:
##   var move = Move.new(1)  # Crea Pound desde ID
##   var move = Move.new(move_data)  # Crea desde MoveData
extends Resource
class_name Move

# Referencia al dato estático del movimiento
var base: MoveData

# Propiedades runtime del movimiento
var pp: int = 5           # PP máximo (base + modificadores)
var pp_actual: int = 5    # PP restante
var mod_pp: int = 0       # Modificador de PP (PP Ups usados: 0-3)

## Constructor
##
## @param move_data: MoveData, int (move_id), o null (creación desde inspector)
func _init(move_data = null) -> void:
	# Creación desde inspector: sin parámetros
	if move_data == null:
		return

	# Cargar MoveData
	if move_data is int:
		base = DatabaseService.get_move(move_data)
	elif move_data is MoveData:
		base = move_data
	else:
		push_error("Move._init: move_data debe ser MoveData o int (move_id)")
		return

	# Validar que se cargó correctamente
	if base == null:
		push_error("Move._init: No se pudo cargar MoveData para id %s" % str(move_data))
		return

	# Inicializar PP
	pp = base.pp
	pp_actual = pp

## Convierte este Move a un BattleMove para usarlo en combate
func to_battle_move(pokemon: BattlePokemon) -> BattleMove:
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
	# Usar type_id para cargar el TypeData solo cuando sea necesario
	if base.type_id > 0:
		if Engine.has_singleton("DatabaseService"):
			return DatabaseService.get_type(base.type_id) as TypeData
	# Compatibilidad: si type_id es 0 pero existe type (Resource), usarlo
	if base.type != null:
		return base.type as TypeData
	return null

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
	# Por ahora, solo usar compatibilidad con Resource antiguo
	# TODO: Agregar soporte para ailments en DatabaseService
	if base.ailment != null:
		return base.ailment as AilmentData
	return null

func get_ailment_chance() -> int:
	return base.meta_ailment_chance

func get_weather() -> WeatherData:
	# Usar weather_id para cargar el WeatherData solo cuando sea necesario
	if base.weather_id > 0:
		if Engine.has_singleton("DatabaseService"):
			return DatabaseService.get_weather(base.weather_id) as WeatherData
	# Compatibilidad: si weather_id es 0 pero existe weather (Resource), usarlo
	if base.weather != null:
		return base.weather as WeatherData
	return null

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

## Helpers para características del movimiento
func has_contact() -> bool:
	"""Retorna true si el movimiento hace contacto físico"""
	return base.contact_flag

func is_special() -> bool:
	"""Retorna true si el movimiento es de clase especial"""
	return base.damage_class_id == CONST.DAMAGE_CLASS.ESPECIAL

func is_physical() -> bool:
	"""Retorna true si el movimiento es de clase física"""
	return base.damage_class_id == CONST.DAMAGE_CLASS.FISICO

func is_status() -> bool:
	"""Retorna true si el movimiento no hace daño (clase estado)"""
	return base.damage_class_id == CONST.DAMAGE_CLASS.ESTADO

## Gestión de PP
func use_pp(amount: int = 1) -> bool:
	"""
	Usa PP del movimiento.
	Retorna true si se pudo usar, false si no hay suficiente PP.
	"""
	if pp_actual >= amount:
		pp_actual -= amount
		return true
	return false

func restore_pp(amount: int = -1) -> void:
	"""Restaura PP. Si amount = -1, restaura todo el PP"""
	if amount == -1:
		pp_actual = pp
	else:
		pp_actual = min(pp_actual + amount, pp)

func is_depleted() -> bool:
	"""Retorna true si no quedan PP"""
	return pp_actual <= 0

func get_pp_ratio() -> float:
	"""Retorna el ratio de PP actual/máximo (0.0 a 1.0)"""
	return float(pp_actual) / float(pp) if pp > 0 else 0.0

## Debug
func print_move() -> void:
	print(" ------ %s %d/%d PP ------ " % [get_move_name(), pp_actual, pp])

func _to_string() -> String:
	return get_move_name()
