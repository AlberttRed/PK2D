class_name BattleMoveChoice
extends BattleChoice

var move: BattleMove
var move_index: int = -1

# Array de BattleTarget generados para este movimiento
var targets: Array[BattleTarget] = []
## Los targets serán asignados por BattleUI antes de resolver

func get_move() -> BattleMove:
	if not pokemon or move_index == -1:
		return null
	return pokemon.get_available_moves()[move_index]

func get_priority() -> int:
	return get_move().get_priority() if get_move() != null else 0

## Resuelve el movimiento y genera los handlers correspondientes
func resolve() -> Array[BattleHandler]:
	var handlers: Array[BattleHandler] = []

	var move_instance := get_move()
	if not move_instance:
		return handlers

	if targets.is_empty():
		return handlers

	var category: BattleMoveCategory = move_instance.get_category() if move_instance.has_method("get_category") else null
	if not category:
		print("No category found for move: " + move_instance.get_name())
		return handlers

	if move_instance.get_accuracy() > 0 and not AccuracyUtils.roll_global_accuracy(move_instance, pokemon):
		handlers.append(MissHandler.new(pokemon, move_instance))
		return handlers

	for target in targets:
		var hit_result := AccuracyUtils.check_target_hit(move_instance, pokemon, target)
		if hit_result == HitResult.Values.HIT:
			var handler := category.create_handler(move_instance, pokemon, target)
			if handler:
				handlers.append(handler)
		else:
			var fail_handler := _create_fail_handler(hit_result, move_instance, target)
			if fail_handler:
				handlers.append(fail_handler)

	return handlers


func _create_fail_handler(
	hit_result: HitResult.Values,
	move_instance: BattleMove,
	target: BattleTarget
) -> BattleHandler:
	match hit_result:
		HitResult.Values.EVADED:
			return EvadedHandler.new(pokemon, move_instance, target)
		HitResult.Values.PROTECTED:
			return ProtectedHandler.new(pokemon, move_instance, target)
		HitResult.Values.IMMUNE:
			return ImmuneHandler.new(pokemon, move_instance, target)
		HitResult.Values.NO_TARGET:
			return NoTargetHandler.new(pokemon, move_instance)
		_:
			return NoTargetHandler.new(pokemon, move_instance)


# Retorna el target válido si existe; en caso contrario devuelve null
func _get_valid_single_enemy_target_or_null(original_target: BattleTarget) -> BattleTarget:
	var tp := original_target.get_pokemon()
	if tp != null and tp.in_battle and not tp.is_fainted() and tp.battle_spot != null:
		return original_target
	var candidates := pokemon.get_opponent_side().get_active_pokemons()
	candidates = candidates.filter(func(p): return p != tp and not p.is_fainted() and p.battle_spot != null)
	if candidates.is_empty():
		return null
	return BattleTarget.new(candidates[0].battle_spot, original_target.selection_type)
