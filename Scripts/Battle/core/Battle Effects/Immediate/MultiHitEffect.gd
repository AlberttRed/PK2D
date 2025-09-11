class_name MultiHitEffect
extends ImmediateBattleEffect

var user: BattlePokemon
var target: BattlePokemon
var move: BattleMove
var num_hits: int

var sub_effects: Array[ImmediateBattleEffect] = []

func _init(_user, _target, _move, _num_hits):
	user = _user
	target = _target
	move = _move
	num_hits = _num_hits

	for i in num_hits:
		if target.is_fainted():
			break

		var logic = move.get_category_logic()
		logic.move = move
		logic.user = user
		logic.target = target
		logic.num_hits = num_hits

		var effects: Array[ImmediateBattleEffect] = logic.execute()

		for e in effects:
			# Evitar que cada golpe muestre el mensaje de efectividad individualmente
			if e is ApplyDamageEffect:
				e.show_effectiveness = false
			sub_effects.append(e)

func apply():
	for effect in sub_effects:
		effect.apply()

func visualize(ui:BattleUI):
	for effect in sub_effects:
		await effect.visualize(ui)

	if num_hits > 1:
		await ui.show_multi_hit_message(num_hits)

	
	await ui.show_effectiveness_message(sub_effects[0].damage)
