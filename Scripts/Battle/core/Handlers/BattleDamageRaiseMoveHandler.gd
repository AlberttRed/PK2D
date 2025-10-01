extends BattleHandler

class_name BattleDamageRaiseMoveHandler

var user
var target
var move

var damage = null

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# Aplicar daño base primero
	damage = move.calculate_damage(target)
	damage.apply()
	# TODO: aplicar subida de stats del usuario si corresponde

func visualize(ui) -> void:
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if damage.show_effectiveness:
			await ui.show_effectiveness_message(damage)
	# TODO: visualizar mensaje/cambio de stats


