extends Resource

class_name BattleMoveCategory

## Crea un handler para el movimiento
## move: el BattleMove que se ejecuta
## user: el BattlePokemon que usa el movimiento
## target: el BattleTarget (puede ser Pokémon, Side o Field según el scope)
func create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	var base := _create_handler(move, user, target)
	
	# MultiHitHandler solo se aplica cuando el target es un Pokémon
	if target.is_pokemon():
		var num_hits := move.get_number_of_hits()
		if num_hits > 1:
			return MultiHitHandler.new(self, move, user, target, num_hits)
	
	return base

## Método abstracto que cada subclase debe implementar
## Cada subclase valida el tipo de target y crea el handler correspondiente
func _create_handler(_move: BattleMove, _user: BattlePokemon, _target: BattleTarget) -> BattleHandler:
	push_error("_create_handler not implemented in " + get_script().resource_path)
	return null

# ============================================================================
# Métodos helper para validación y extracción de targets
# ============================================================================

## Valida que el target sea un Pokémon y lo devuelve.
## Si no lo es, muestra una advertencia y devuelve null.
func require_pokemon_target(target: BattleTarget) -> BattlePokemon:
	if not target.is_pokemon():
		push_warning("%s requiere un target de tipo POKEMON" % get_script().get_global_name())
		return null
	return target.get_pokemon()

## Valida que el target sea un Side y lo devuelve.
## Si no lo es, muestra una advertencia y devuelve null.
func require_side_target(target: BattleTarget) -> BattleSide:
	if not target.is_side():
		push_warning("%s requiere un target de tipo SIDE" % get_script().get_global_name())
		return null
	return target.get_side()

## Valida que el target sea de tipo Field.
## Si no lo es, muestra una advertencia y devuelve false.
func require_field_target(target: BattleTarget) -> bool:
	if not target.is_field():
		push_warning("%s requiere un target de tipo FIELD" % get_script().get_global_name())
		return false
	return true

## Obtiene el Pokémon del target sin validación (puede devolver null)
func get_pokemon_or_null(target: BattleTarget) -> BattlePokemon:
	return target.get_pokemon()

## Obtiene el Side del target sin validación (puede devolver null)
func get_side_or_null(target: BattleTarget) -> BattleSide:
	return target.get_side()
