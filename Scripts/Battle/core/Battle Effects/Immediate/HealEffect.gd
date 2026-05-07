extends ImmediateBattleEffect

class_name HealEffect

var target: BattlePokemon
var amount: int
var show_heal_animation: bool


func _init(_target: BattlePokemon, _amount: int, _show_heal_animation: bool = true) -> void:
	target = _target
	amount = maxi(_amount, 1)
	show_heal_animation = _show_heal_animation


func apply() -> void:
	if amount > 0:
		target.take_heal(self)


func visualize(_ui: BattleUI) -> void:
	if amount <= 0 or target == null or target.battle_spot == null:
		return
	if show_heal_animation:
		await target.battle_spot.apply_heal(amount)
