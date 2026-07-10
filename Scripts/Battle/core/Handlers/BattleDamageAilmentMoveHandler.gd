extends BattleMoveHandler

class_name BattleDamageAilmentMoveHandler

var damage: DamageEffect = null
var _apply_results: Array[Dictionary] = []


func _apply() -> void:
	var defender: BattlePokemon = target.get_pokemon().get_active_battle_pokemon() if target.get_pokemon() != null else null
	if defender == null:
		return

	damage = move.calculate_damage(defender)
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()

	_apply_results.clear()
	if damage != null and not damage.is_ineffective() and not defender.is_fainted():
		for entry in move.get_ailment_entries():
			_apply_results.append(_try_apply_ailment_entry(entry))

	_finalize_defender_move_resolution(damage)


func _visualize(ui) -> void:
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if show_effectiveness:
			await ui.show_effectiveness_message(damage)

	for apply_data in _apply_results:
		await _visualize_ailment_entry_result(ui, apply_data, false)
