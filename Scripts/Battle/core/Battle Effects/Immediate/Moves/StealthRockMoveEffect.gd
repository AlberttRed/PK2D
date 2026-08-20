extends BattleMoveEffect
class_name StealthRockMoveEffect

var already_active := false
var placed := false
var target_side: BattleSide = null


func apply():
	target_side = user.side.opponent_side
	if target_side == null:
		return

	var side_type := target_side.type
	var existing := StealthRockFieldEffect.find_on_side(side_type)
	if existing != null and existing.is_active():
		already_active = true
		return

	var effect_instance := StealthRockFieldEffect.new(move, side_type, 1)
	effect_instance.add_layers(1)
	BattleEffectController.add_side_effect(side_type, effect_instance)
	placed = true


func visualize(ui: BattleUI):
	if already_active:
		await ui.show_already_effect_message(MessageFamily.Values.FIELD_EFFECT, user, move.get_id())
		return
	if placed:
		await ui.show_start_effect_message(
			MessageFamily.Values.FIELD_EFFECT, user, move.get_id(), target_side
		)
