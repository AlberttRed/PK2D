extends BattleMoveHandler

class_name BattleWholeFieldEffectMoveHandler

var effect: BattleMoveEffect

func _apply() -> void:
	# Los efectos de campo completo siempre se aplican globalmente
	# El BattleMoveEffect se encarga internamente de crear y añadir el PersistentBattleEffect
	effect = move.create_move_effect(null)
	if effect:
		effect.apply()

func _visualize(ui: BattleUI) -> void:
	# Visualizar el efecto del movimiento (ej: "¡Comenzó a llover!")
	if effect:
		await effect.visualize(ui)
