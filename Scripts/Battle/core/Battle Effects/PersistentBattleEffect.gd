class_name PersistentBattleEffect
extends BattleEffect

var source # AilmentData/AbilityData/WeatherData
var effect_success:bool
var turns_left:int
var applied:bool = false

func _init(_source, _min_turns = null, _max_turns = null) -> void:
	source = _source
	if _min_turns and _max_turns:
		turns_left = randi_range(_min_turns, _max_turns)

func apply_phase(_pokemon, _phase: Phases) -> void: return
func visualize_phase(_pokemon, _ui, _phase: Phases) -> void: return

func has_finished(): return turns_left != null and turns_left < 0

func next_turn(): turns_left -= 1

func on_modifier(_modifier_type: int, _move, _user, _target, value): return value # legacy (no usar)

# --- Nuevos hooks específicos por fase ---
func on_power(_move, _user, _target, value): return value
func on_accuracy(_move, _user, _target, value): return value
func on_crit_chance(_move, _user, _target, value): return value
func on_damage(_effect: DamageEffect) -> void: pass

func get_priority() -> int:
	return 0
