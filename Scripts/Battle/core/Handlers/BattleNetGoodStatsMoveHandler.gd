extends BattleMoveHandler

class_name BattleNetGoodStatsMoveHandler

var stat_effect: StatChangeEffect = null


func _apply() -> void:
	# Aumenta/baja stats netos sobre el target (Pokémon) según la categoría NetGoodStats.
	if target.get_pokemon() == null:
		return
	var changes: Dictionary = move.get_stat_changes()
	stat_effect = StatChangeEffect.new(target.get_pokemon(), changes)
	stat_effect.apply()

func _visualize(ui) -> void:
	if stat_effect != null:
		await stat_effect.visualize(ui)
