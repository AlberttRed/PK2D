extends BattleHandler

class_name BattleUniqueMoveHandler

var user: BattlePokemon
var target: BattleTarget
var move: BattleMove
var effect: BattleMoveEffect

func _init(_move: BattleMove, _user: BattlePokemon, _target: BattleTarget):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# Los movimientos únicos tienen lógica específica
	var effect_target: BattlePokemon = null
	
	if target.is_pokemon():
		effect_target = target.get_pokemon()
	
	effect = move.create_move_effect(effect_target)
	if effect:
		effect.apply()

func visualize(ui: BattleUI) -> void:
	# Visualizar movimiento único
	if effect:
		await effect.visualize(ui)
