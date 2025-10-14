extends BattleMoveHandler

class_name BattleUniqueMoveHandler

var effect: BattleMoveEffect

func _apply() -> void:
	# Los movimientos únicos tienen lógica específica
	var effect_target: BattlePokemon = null
	
	if target.is_pokemon():
		effect_target = target.get_pokemon()
	
	effect = move.create_move_effect(effect_target)
	if effect:
		effect.apply()

func _visualize(ui: BattleUI) -> void:
	# Visualizar movimiento único
	if effect:
		await effect.visualize(ui)
