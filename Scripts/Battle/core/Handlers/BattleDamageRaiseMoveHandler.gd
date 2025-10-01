extends BattleMoveHandler

class_name BattleDamageRaiseMoveHandler

var damage: DamageEffect = null
var stat_effect: StatChangeEffect = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func apply() -> void:
	# Aplicar daño base primero
	damage = move.calculate_damage(target)
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()
	# Subir stats del usuario si corresponde
	var changes: Dictionary = move.get_stat_changes()
	stat_effect = StatChangeEffect.new(user, changes)
	stat_effect.apply()

func visualize(ui) -> void:
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if show_effectiveness and not move.is_multi_hit():
			await ui.show_effectiveness_message(damage)
	if stat_effect != null:
		await stat_effect.visualize(ui)
