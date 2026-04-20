extends RefCounted

class_name PokemonLevelGrowth

const EvolutionCheckResult := preload("res://Scripts/Runtime/EvolutionCheckResult.gd")

## Resultado de evaluar subidas de nivel según EXP total (`totalExp`).
class LevelUpResult extends RefCounted:
	var old_level: int = 0
	var new_level: int = 0
	var levels_gained: int = 0
	## Si `new_level` < 100, EXP restante hasta el siguiente umbral; si no, 0.
	var exp_to_next_level: int = 0
	## Recalculo de stats (HP + resto); null si no hubo subida. Ver `LevelUpStatResult.gd`.
	var stat_changes: RefCounted = null
	## int(level alcanzado) -> MoveLearnResult (ver `MoveLearnResult.gd`).
	var move_learning_by_level: Dictionary = {}
	## Evolución por nivel pendiente tras la subida (solo detección). Ver `EvolutionCheckResult.gd`.
	var evolution_check: EvolutionCheckResult = null


## Sube `pokemon.level` en bucle mientras `totalExp` alcance los umbrales siguientes (máx. 100).
## Recalcula stats de runtime y PS actuales vía `Pokemon.apply_stats_after_level_up`.
static func check_and_apply_level_up(pokemon: Pokemon) -> LevelUpResult:
	var res := LevelUpResult.new()
	if pokemon == null or pokemon.base == null:
		return res

	res.old_level = pokemon.level
	res.new_level = pokemon.level

	var grp := PokemonExperienceGroup.new(pokemon.base.growth_rate_id)

	while pokemon.level < 100:
		var need: int = grp.get_total_exp_for_level(pokemon.level + 1)
		if pokemon.totalExp < need:
			break
		pokemon.level += 1
		res.levels_gained += 1
		var move_res: RefCounted = pokemon.resolve_level_up_move_learning_for_level(pokemon.level)
		res.move_learning_by_level[pokemon.level] = move_res

	res.new_level = pokemon.level

	if pokemon.level < 100:
		var next_need: int = grp.get_total_exp_for_level(pokemon.level + 1)
		res.exp_to_next_level = maxi(0, next_need - pokemon.totalExp)
	else:
		res.exp_to_next_level = 0

	if res.levels_gained > 0:
		res.stat_changes = pokemon.apply_stats_after_level_up(res.old_level)
		res.evolution_check = pokemon.check_level_evolution()
		print("PokemonLevelGrowth: %s sube %d nivel(es): %d → %d | EXP siguiente umbral: %d" % [
			pokemon.get_display_name(), res.levels_gained, res.old_level, res.new_level, res.exp_to_next_level
		])

	return res
