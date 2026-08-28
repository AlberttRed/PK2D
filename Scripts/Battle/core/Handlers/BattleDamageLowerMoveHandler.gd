extends BattleMoveHandler

class_name BattleDamageLowerMoveHandler

## TEMP prueba: ignorar meta_stat_chance (p. ej. Psíquico 10% → siempre).
## Quitar / poner false cuando termines de validar KO vs stat.
const DEBUG_FORCE_STAT_CHANGE := false

var damage: DamageEffect = null
var stat_effect: StatChangeEffect = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func _apply() -> void:
	# 1) Daño al objetivo (HP real se aplica en visualize, igual que DamageAilment).
	if target.get_pokemon() == null:
		return
	damage = move.calculate_damage(target.get_pokemon())
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()
	# 2) Stat lower diferido a _visualize tras KO real.

func _visualize(ui) -> void:
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if show_effectiveness:
			await ui.show_effectiveness_message(damage)

		_finalize_defender_move_resolution(damage)

		# Sin cambio de stat si el golpe dejó al objetivo a 0 PS.
		var defender: BattlePokemon = (
			target.get_pokemon().get_active_battle_pokemon()
			if target.get_pokemon() != null else null
		)
		if (
			defender != null
			and not damage.is_ineffective()
			and not defender.is_fainted()
			and _stat_change_roll_passed()
		):
			var changes: Dictionary = move.get_stat_changes()
			stat_effect = StatChangeEffect.new(defender, changes)
			stat_effect.user = user
			stat_effect.apply()

	if stat_effect != null:
		await stat_effect.visualize(ui)


func _stat_change_roll_passed() -> bool:
	if DEBUG_FORCE_STAT_CHANGE:
		return true
	if move == null:
		return true
	var chance: int = int(move.get_meta_stat_chance())
	if chance <= 0:
		# Sin % definido: aplicar si hay cambios de stat (compat).
		return not move.get_stat_changes().is_empty()
	if chance >= 100:
		return true
	return randi_range(1, 100) <= chance
