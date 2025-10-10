extends BattleHandler

class_name BattleWholeFieldEffectMoveHandler

var user: BattlePokemon
var move: BattleMove
var effect: BattleMoveEffect

func _init(_move: BattleMove, _user: BattlePokemon):
	move = _move
	user = _user

func apply() -> void:
	# Los efectos de campo completo siempre se aplican globalmente
	# El BattleMoveEffect se encarga internamente de crear y añadir el PersistentBattleEffect
	effect = move.create_move_effect(null)
	if effect:
		effect.apply()

func visualize(ui: BattleUI) -> void:
	# Visualizar el efecto del movimiento (ej: "¡Comenzó a llover!")
	if effect:
		await effect.visualize(ui)
