extends BattleMoveEffect
class_name SafeguardMoveEffect

var already_active := false

func apply():
	var side_type := user.side.type
	var duration := 5
	var effect_instance: PersistentBattleEffect = SafeguardFieldEffect.new(move, duration, side_type)

	if BattleEffectController.has_side_effect(side_type, effect_instance):
		already_active = true
		return

	BattleEffectController.add_side_effect(side_type, effect_instance)

func visualize(ui: BattleUI):
	if already_active:
		await ui.show_already_effect_message(MessageFamily.Values.FIELD_EFFECT, user, move.get_id())
	else:
		await ui.show_start_effect_message(MessageFamily.Values.FIELD_EFFECT, user, move.get_id())
