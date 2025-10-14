extends BattleMoveHandler

class_name BattleHealMoveHandler

var heal: HealEffect = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func _apply() -> void:
	# Determinar objetivo de curación: algunos moves son self-target
	var target_pokemon = target.get_pokemon() if target != null else null
	if target_pokemon == null:
		return
	
	heal = move.calculate_healing(target_pokemon)
	heal.apply()

func _visualize(ui: BattleUI) -> void:
	if heal == null:
		return
	await heal.visualize(ui)
	# Mostrar mensaje de curación para el destinatario real
	await ui.show_heal_message(heal.target)
