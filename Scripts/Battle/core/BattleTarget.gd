class_name BattleTarget
extends RefCounted

## Representa un único objetivo en combate (Pokémon, Side o Field)
## El scope se detecta automáticamente según el tipo de objeto recibido

## Scope: Tipo de objetivo (Pokémon individual, Side o Field completo)
enum Scope {
	POKEMON,  # Target es un BattlePokemon
	SIDE,     # Target es un BattleSide
	FIELD     # Target es el campo completo (sin objeto específico)
}

## TYPE: Tipo de targeting del movimiento (a quién va dirigido)
enum TYPE {
	NONE, ESPECIFICO, YO_PRIMERO, ALIADO,
	BASE_PLAYER, USER_OR_ALLY, BASE_ENEMY,
	USER, RANDOM_ENEMY, ALL_OTHER, SELECCIONAR,
	ENEMIES, ALL_FIELD, PLAYERS, ALL_POKEMON
}

var scope: Scope
var _target_object  # BattlePokemon, BattleSide o null (para FIELD)
## Nuevo: tipo de targeting con el que se generó este target
var selection_type: TYPE = TYPE.NONE

## Constructor que detecta automáticamente el scope según el tipo de target
func _init(target = null, _selection_type: TYPE = TYPE.NONE):
	if target is BattlePokemon:
		scope = Scope.POKEMON
		_target_object = target
	elif target is BattleSide:
		scope = Scope.SIDE
		_target_object = target
	else:
		# Si target es null o cualquier otro tipo, se considera FIELD
		scope = Scope.FIELD
		_target_object = null
	selection_type = _selection_type

## Devuelve el objeto target (BattlePokemon, BattleSide o null)
func get_target():
	return _target_object

## Devuelve un nombre representativo del target para debugging/UI
func get_name() -> String:
	match scope:
		Scope.POKEMON:
			if _target_object:
				return _target_object.get_name()
			return "Unknown Pokémon"
		Scope.SIDE:
			if _target_object:
				return _target_object.to_string()
			return "Unknown Side"
		Scope.FIELD:
			return "Field"
		_:
			return "Unknown Target"

## Verifica si este target es de tipo Pokémon
func is_pokemon() -> bool:
	return scope == Scope.POKEMON

## Verifica si este target es de tipo Side
func is_side() -> bool:
	return scope == Scope.SIDE

## Verifica si este target es de tipo Field
func is_field() -> bool:
	return scope == Scope.FIELD

## Helper: indica si el selection_type representa objetivo único enemigo
func is_single_enemy_selection_type() -> bool:
	return selection_type == TYPE.SELECCIONAR or selection_type == TYPE.RANDOM_ENEMY or selection_type == TYPE.ESPECIFICO

## Obtiene el Pokémon si el scope es POKEMON, sino null
func get_pokemon() -> BattlePokemon:
	if scope == Scope.POKEMON:
		return _target_object as BattlePokemon
	return null

## Obtiene el Side si el scope es SIDE, sino null
func get_side() -> BattleSide:
	if scope == Scope.SIDE:
		return _target_object as BattleSide
	return null

func is_valid_pokemon() -> bool:
	return get_pokemon() and !get_pokemon().is_fainted()

func is_valid_side() -> bool:
	return get_side() != null

func is_valid_field() -> bool:
	return is_field() and _target_object == null

func is_valid() -> bool:
	return is_valid_pokemon() or is_valid_side() or is_valid_field()
