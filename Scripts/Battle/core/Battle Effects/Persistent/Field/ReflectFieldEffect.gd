extends PersistentBattleEffect
class_name ReflectFieldEffect


var side_key: String                  # "Player" | "Enemy"
var side_display_name: String = "tu lado"

func _init(_source = null, _duration: int = 5, _side_key: String = "", _side_display: String = "tu lado") -> void:
	super._init(_source)
	turns_left = _duration
	side_key = _side_key
	side_display_name = _side_display

func apply_phase(_pokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase == Phases.ON_END_BATTLE_TURN:
		next_turn()

func visualize_phase(_pokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase == Phases.ON_BATTLE_START:
		await ui.show_start_effect_message(MessageFamily.Values.FIELD_EFFECT, source.pokemon, source.get_id())
	elif phase == Phases.ON_END_BATTLE_TURN and has_finished():
		await ui.show_end_effect_message(MessageFamily.Values.FIELD_EFFECT, source.pokemon, source.get_id())

func on_damage(effect: DamageEffect) -> void:
	if effect.is_critical:
		return
	var target := effect.target
	if target == null or target.side == null:
		return
	if not effect.move.is_physic_category():
		return
	var target_side_key: String = target.side._to_string()
	if target_side_key != side_key:
		return
	var is_double: bool = target.side.get_active_pokemons().size() > 1
	var mult := 2.0 / 3.0 if is_double else 0.5
	effect.amount = int(floor(effect.amount * mult))

func get_priority() -> int:
	return 5
