extends BattleHandler

class_name BattleSwitchHandler

var switch_effect: SwitchEffect

func _init(_side: BattleSide, _spot: BattleSpot, _out: BattlePokemon, _in: BattlePokemon, _rules: BattleRules):
	switch_effect = SwitchEffect.new(_side, _spot, _out, _in, _rules)

func apply() -> void:
	switch_effect.apply()

func visualize(ui: BattleUI) -> void:
	await switch_effect.visualize(ui)
