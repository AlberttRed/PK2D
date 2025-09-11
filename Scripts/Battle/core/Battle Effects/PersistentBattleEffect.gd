class_name PersistentBattleEffect
extends BattleEffect

var source # Ailment/Ability/Weather
var effect_success:bool
var turns_left:int

func _init(_source, _min_turns = null, _max_turns = null) -> void:
	source = _source
	if _min_turns and _max_turns:
		turns_left = randi_range(_min_turns, _max_turns)

func apply_phase(pokemon, phase: Phases) -> void: return
func visualize_phase(pokemon, ui, phase: Phases) -> void: return

func has_finished(): return turns_left!=null and turns_left < 0

func next_turn(): turns_left -= 1

func on_modifier(modifier_type: int, move, user, target, value): return value

func get_priority() -> int:
	return 0
