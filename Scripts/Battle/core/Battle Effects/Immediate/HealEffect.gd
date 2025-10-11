extends ImmediateBattleEffect

class_name HealEffect

var user: BattlePokemon
var target: BattlePokemon
var move: BattleMove
var amount: int

func _init(_user: BattlePokemon, _target: BattlePokemon, _move: BattleMove, _amount: int):
	user = _user
	target = _target
	move = _move
	amount = _amount

func apply():
	if amount > 0:
		target.take_heal(self)

func visualize(_ui: BattleUI):
	if amount > 0:
		# La animacion de heal solo se muestra en objetos (pociones etc). Aqui solo se aplica la animacion del move.
		#await target.battle_spot.play_heal_animation()
		await target.battle_spot.apply_heal(amount)
		# El mensaje se maneja en el handler específico
