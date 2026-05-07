extends ImmediateBattleEffect

class_name ReviveEffect

var target: BattlePokemon
var amount: int
var show_heal_animation: bool


func _init(_target: BattlePokemon, _amount: int, _show_heal_animation: bool = true) -> void:
	target = _target
	show_heal_animation = _show_heal_animation
	if _target != null:
		amount = clampi(_amount, 1, _target.total_hp)
	else:
		amount = maxi(_amount, 1)


func apply() -> void:
	if target == null or target.base_data == null:
		return
	target.hp = clampi(amount, 1, target.total_hp)
	target.fainted = false
	target.base_data.hp_actual = target.hp
	target.base_data.major_status = CONST.STATUS.OK
	target.set_status(null)


func visualize(_ui: BattleUI) -> void:
	if target == null or target.battle_spot == null:
		return
	target.status_changed.emit()
	if show_heal_animation and amount > 0:
		await target.battle_spot.apply_heal(amount)
	elif target.battle_spot.hp_bar != null:
		target.battle_spot.hp_bar.sync_health_bar_from_pokemon()
