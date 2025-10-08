class_name StatChangeEffect
extends ImmediateBattleEffect

var target: BattlePokemon

var stats_changes_list: Dictionary[StatsEnum.Values, int]

var _applied: bool = false

func _init(_target:BattlePokemon, _stats_changes_list:Dictionary[StatsEnum.Values, int]):
	target = _target
	stats_changes_list = _stats_changes_list

func apply() -> void:
	for stat in stats_changes_list:
		var amount = stats_changes_list[stat]
		if amount > 0:
			_applied = target.stat_stages.increase(stat, amount)
		else:
			_applied = target.stat_stages.decrease(stat, abs(amount))

func visualize(ui: BattleUI):
	if not _applied:
		return  # Nada que mostrar
	
	for stat in stats_changes_list:
		var amount = stats_changes_list[stat]
		
		# Reproducir animación según si sube o baja
		if amount > 0:
			await target.battle_spot.play_stat_up_animation()
		else:
			await target.battle_spot.play_stat_down_animation()
		
		await ui.show_stat_stage_change_message(target, stat, amount)
