class_name PersistentBattleEffect
extends BattleEffect

enum EffectSource { WEATHER, FIELD, AILMENT, ABILITY, ITEM, OTHER }

var source # AilmentData/AbilityData/WeatherData
var effect_source: EffectSource = EffectSource.OTHER
var effect_success:bool
var turns_left:int
var applied:bool = false

func _init(_source, _min_turns = null, _max_turns = null) -> void:
	source = _source
	if _min_turns and _max_turns:
		turns_left = randi_range(_min_turns, _max_turns)

## Llamar solo desde BattleEffectController al registrar el efecto (instancia ya construida).
func detect_effect_source() -> void:
	effect_source = classify_from_class_name(_resolve_effect_class_name())
	if effect_source == EffectSource.OTHER:
		push_warning(
			"PersistentBattleEffect: no se pudo clasificar '%s' (effect_source=OTHER)."
			% _resolve_effect_class_name()
		)

static func classify_from_class_name(class_name_lower: String) -> EffectSource:
	if class_name_lower.contains("weather"):
		return EffectSource.WEATHER
	if class_name_lower.contains("field") or class_name_lower.contains("side"):
		return EffectSource.FIELD
	if class_name_lower.contains("ailment") or class_name_lower.contains("status"):
		return EffectSource.AILMENT
	if class_name_lower.contains("ability"):
		return EffectSource.ABILITY
	if class_name_lower.contains("item"):
		return EffectSource.ITEM
	return EffectSource.OTHER

func _resolve_effect_class_name() -> String:
	var script: Script = get_script()
	if script != null:
		var global_name: String = script.get_global_name()
		if not global_name.is_empty():
			return global_name.to_lower()
		var file_name: String = script.resource_path.get_file().get_basename()
		if not file_name.is_empty():
			return file_name.to_lower()
	return get_class().to_lower()

static func get_visual_order(src: EffectSource) -> int:
	match src:
		EffectSource.FIELD: return 0
		EffectSource.WEATHER: return 1
		EffectSource.AILMENT: return 2
		EffectSource.ABILITY: return 3
		EffectSource.ITEM: return 4
		_: return 5

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
