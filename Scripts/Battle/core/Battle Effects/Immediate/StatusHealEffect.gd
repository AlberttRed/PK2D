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
	var spot: BattleSpot = (
		target.resolve_battle_spot()
		if target.has_method("resolve_battle_spot")
		else target.battle_spot
	)
	# Misma VFX que curación de PS en campo (overlay + brillos); sin tocar la barra de vida.
	if spot != null and spot.has_method("play_heal_animation"):
		await spot.play_heal_animation()
	target.status_changed.emit()
	if spot != null and spot.hp_bar != null:
		spot.hp_bar.update_status_ui()
