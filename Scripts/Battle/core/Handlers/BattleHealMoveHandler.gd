extends BattleMoveHandler

class_name BattleHealMoveHandler

var heal: HealEffect = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func apply() -> void:
	heal = move.calculate_healing(user)
	heal.apply()

func visualize(ui: BattleUI) -> void:
	if heal == null:
		return
	await heal.visualize(ui)
	# Mostrar mensaje específico de curación directa
	await ui.show_heal_message(user)
