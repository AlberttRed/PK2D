class_name ApplyDamageEffect
extends ImmediateBattleEffect

var user: BattlePokemon
var target: BattlePokemon
var move: BattleMove
var damage:DamageEffect
var show_effectiveness:bool = true

func _init(_user: BattlePokemon, _target: BattlePokemon, _move: BattleMove):
	user = _user
	target = _target
	move = _move

func apply():
	damage = move.calculate_damage(target)
	damage.apply()

func visualize(ui: BattleUI):
	await damage.visualize(ui)
	
	if damage.is_critical:
		await ui.show_critical_hit_message()

	if show_effectiveness:
		await ui.show_effectiveness_message(damage)
