extends BattleHandler

class_name BattleRunHandler

var run_effect: RunEffect

func _init(_pokemon: BattlePokemon, _rules: BattleRules):
	var can_escape = _can_escape_from_battle(_rules)
	run_effect = RunEffect.new(_pokemon, can_escape)

func _can_escape_from_battle(rules: BattleRules) -> bool:
	# Se puede huir en combates contra Pokémon salvajes (individuales o dobles)
	return rules.type == BattleRules.BattleTypes.WILD

func apply() -> void:
	run_effect.apply()

func visualize(ui: BattleUI) -> void:
	await run_effect.visualize(ui)
