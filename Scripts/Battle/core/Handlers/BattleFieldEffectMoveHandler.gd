extends BattleMoveHandler

class_name BattleFieldEffectMoveHandler

var effect: BattleMoveEffect

func _apply() -> void:
	# Aplicar efecto de lado (Reflejo, Pantalla de Luz, Púas, etc.)
	effect = move.create_move_effect(null)
	if effect:
		effect.apply()
		# El BattleMoveEffect se encarga internamente de añadir el efecto al lado correcto

func _visualize(ui: BattleUI) -> void:
	# Visualizar el efecto del movimiento
	if effect:
		await effect.visualize(ui)
