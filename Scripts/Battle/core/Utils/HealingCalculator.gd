# HealingCalculator.gd
extends RefCounted

class_name HealingCalculator

static func calculate(move: BattleMove, user: BattlePokemon, target: BattlePokemon, damage_taken: int = 0) -> HealEffect:
	var amount := 0

	if move.get_drain_percentage() > 0:
		amount = floor(damage_taken * (move.get_drain_percentage() / 100.0))
	elif move.get_heal_amount() > 0:
		amount = floor(user.get_max_hp() * (move.get_heal_amount() / 100.0))
	else:
		push_error("Movimiento %s no tiene ni drain_percentage ni heal_amount definidos." % move.get_name())

	return HealEffect.new(user, target, move, amount)
