extends BattleHandler

class_name BattleDamageMoveHandler

var user
var target
var move

var damage = null

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	damage = move.calculate_damage(target)
	damage.apply()

func visualize(ui: BattleUI) -> void:
	if damage == null:
		return
	await damage.visualize(ui)
	if damage.is_critical:
		await ui.show_critical_hit_message()
	if damage.show_effectiveness:
		await ui.show_effectiveness_message(damage)


