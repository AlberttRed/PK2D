extends BattleHandler

class_name BattleFieldEffectMoveHandler

var user: BattlePokemon
var side: BattleSide
var move: BattleMove
var effect: BattleMoveEffect

func _init(_move: BattleMove, _user: BattlePokemon, _side: BattleSide):
	move = _move
	user = _user
	side = _side

func apply() -> void:
	# Aplicar efecto de lado (Reflejo, Pantalla de Luz, Púas, etc.)
	effect = move.create_move_effect(null)
	if effect:
		effect.apply()
		# El BattleMoveEffect se encarga internamente de añadir el efecto al lado correcto

func visualize(ui: BattleUI) -> void:
	# Visualizar el efecto del movimiento
	if effect:
		await effect.visualize(ui)
