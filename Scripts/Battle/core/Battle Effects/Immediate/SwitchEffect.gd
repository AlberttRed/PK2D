class_name SwitchEffect
extends ImmediateBattleEffect

var side: BattleSide
var spot: BattleSpot
var out_pokemon: BattlePokemon
var in_pokemon: BattlePokemon
var rules: BattleRules

func _init(_side: BattleSide, _spot: BattleSpot, _out: BattlePokemon, _in: BattlePokemon, _rules: BattleRules):
    side = _side
    spot = _spot
    out_pokemon = _out
    in_pokemon = _in
    rules = _rules

func apply():
    if out_pokemon:
        out_pokemon.in_battle = false
    if spot and in_pokemon:
        spot.load_active_pokemon(in_pokemon, rules)

func visualize(_ui):
    # Placeholder: de momento, solo logs.
    var out_name = out_pokemon.get_name() if out_pokemon else "(ninguno)"
    var in_name = in_pokemon.get_name() if in_pokemon else "(ninguno)"
    print("[SWITCH] Sale %s, entra %s" % [out_name, in_name])

