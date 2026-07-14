extends BattleMoveEffect
class_name SafeguardMoveEffect

var already_active := false
var side_key: String
var side_display: String

func apply():
	var side := user.side
	side_key = side._to_string()
	side_display = "tu lado" if side.type == BattleSide.Types.PLAYER else "el lado rival"

	var duration := 5
	var effect_instance: PersistentBattleEffect = SafeguardFieldEffect.new(
		move, duration, side_key, side_display
	)

	if BattleEffectController.has_side_effect(side_key, effect_instance):
		already_active = true
		return

	BattleEffectController.add_side_effect(side_key, effect_instance)

func visualize(ui: BattleUI):
	if already_active:
		await ui.show_already_effect_message(MessageFamily.Values.FIELD_EFFECT, user, move.get_id())
	else:
		await ui.show_start_effect_message(MessageFamily.Values.FIELD_EFFECT, user, move.get_id())
