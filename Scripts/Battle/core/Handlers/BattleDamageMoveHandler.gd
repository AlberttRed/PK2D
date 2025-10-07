extends BattleMoveHandler

class_name BattleDamageMoveHandler

var damage:DamageEffect = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func apply() -> void:
	damage = move.calculate_damage(target)
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()

func visualize(ui: BattleUI) -> void:
	if damage == null:
		return
	await damage.visualize(ui)
	if damage.is_critical:
		await ui.show_critical_hit_message()
	
	# Evitar mostrar efectividad por golpe en multi-hit (se mostrará al final en MultiHitHandler)
	if not move.is_multi_hit() and show_effectiveness:
		await ui.show_effectiveness_message(damage)
