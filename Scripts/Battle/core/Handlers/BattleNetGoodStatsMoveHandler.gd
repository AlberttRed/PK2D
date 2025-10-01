extends BattleHandler

class_name BattleNetGoodStatsMoveHandler

var user
var target
var move

var stat_effect: StatChangeEffect = null

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target


func apply() -> void:
	# Aumenta/baja stats netos sobre el target según la categoría NetGoodStats.
	var changes: Dictionary = move.get_stat_changes()
	stat_effect = StatChangeEffect.new(target, changes)
	stat_effect.apply()

func visualize(ui) -> void:
	if stat_effect != null:
		await stat_effect.visualize(ui)
