extends ImmediateBattleEffect

class_name StatusHealEffect

## Major status (`CONST.STATUS`) que tenía el objetivo antes de limpiar (mensajes en capas superiores).
var cured_major_status: int


func _init(_target: BattlePokemon, _cured_major_status: int) -> void:
	target = _target
	cured_major_status = _cured_major_status


func apply() -> void:
	if target == null or target.base_data == null:
		return
	target.base_data.major_status = CONST.STATUS.OK
	target.set_status(null)


func visualize(_ui: BattleUI) -> void:
	if target == null:
		return
	target.status_changed.emit()
	var spot: BattleSpot = target.battle_spot
	if spot != null and spot.hp_bar != null:
		spot.hp_bar.update_status_ui()
