extends BattleMoveHandler

class_name BattleDamageHealMoveHandler

var damage: DamageEffect = null
var heal: HealEffect = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func apply() -> void:
	# 1. Aplicar daño al objetivo
	damage = move.calculate_damage(target)
	damage.apply()
	
	# 2. Calcular y aplicar curación al usuario basada en el daño causado
	heal = move.calculate_healing(user, damage.amount)
	heal.apply()

func visualize(ui: BattleUI) -> void:
	if damage == null or heal == null:
		return
	
	# Visualizar daño primero
	await damage.visualize(ui)
	if damage.is_critical:
		await ui.show_critical_hit_message()
	
	# Mostrar efectividad si no es multi-hit
	if not move.is_multi_hit() and damage.effectiveness != 1.0:
		await ui.show_effectiveness_message(damage)
	
	# Luego visualizar curación
	await heal.visualize(ui)
	# Mostrar mensaje específico de drenaje
	await ui.show_drain_message(user, heal.amount)


