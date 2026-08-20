extends BattleMoveEffect
class_name ToxicSpikesMoveEffect

var already_full := false
var layers_added := false
var target_side: BattleSide = null


func apply():
	target_side = user.side.opponent_side
	if target_side == null:
		return

	var side_type := target_side.type
	var existing := ToxicSpikesFieldEffect.find_on_side(side_type)
	if existing != null:
		if not existing.can_add_layers():
			already_full = true
			return
		existing.add_layers(1)
		layers_added = true
		return

	var effect_instance := ToxicSpikesFieldEffect.new(move, side_type, 2)
	effect_instance.add_layers(1)
	BattleEffectController.add_side_effect(side_type, effect_instance)
	layers_added = true


func visualize(ui: BattleUI):
	if already_full:
		await ui.show_already_effect_message(MessageFamily.Values.FIELD_EFFECT, user, move.get_id())
		return
	if layers_added:
		await ui.show_start_effect_message(
			MessageFamily.Values.FIELD_EFFECT, user, move.get_id(), target_side
		)
