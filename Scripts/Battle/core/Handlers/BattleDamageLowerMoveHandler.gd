extends BattleMoveHandler

class_name BattleDamageLowerMoveHandler

var damage: DamageEffect = null
var stat_effect: StatChangeEffect = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func _apply() -> void:
	# 1) Daño al objetivo
	if target.get_pokemon() == null:
		return
	damage = move.calculate_damage(target.get_pokemon())
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()

	# 2) Bajar stats del objetivo solo si no se ha debilitado
	if not target.get_pokemon().is_fainted():
		var changes: Dictionary = move.get_stat_changes()
		stat_effect = StatChangeEffect.new(target.get_pokemon(), changes)
		stat_effect.user = user
		stat_effect.apply()

func _visualize(ui) -> void:
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if show_effectiveness:
			await ui.show_effectiveness_message(damage)
	if stat_effect != null:
		await stat_effect.visualize(ui)
