class_name SubstituteAilmentEffect
extends PersistentBattleEffect

var _owner: BattlePokemon = null
var _hp: int = 0
var _finished: bool = false
var _pending_removal: bool = false
var _pending_break_visualize: bool = false
var _absorbed_damage_this_hit: bool = false
## True si este golpe absorbió daño enemigo: bloquea ailments secundarios del mismo impacto.
var _blocked_secondary_this_hit: bool = false

static var _ailment_messages := BattleMessageAilment.new()


func _init(_source = null, substitute_hp: int = 0) -> void:
	super._init(_source)
	_hp = maxi(substitute_hp, 0)


func set_owner(owner: BattlePokemon) -> void:
	_owner = owner.get_active_battle_pokemon() if owner != null else null
	target = _owner
	user = _owner


func _affects_owner(pokemon: BattlePokemon) -> bool:
	var resolved: BattlePokemon = pokemon.get_active_battle_pokemon() if pokemon != null else null
	return _owner != null and resolved == _owner


static func set_owner_sprite_visible(owner: BattlePokemon, is_visible: bool) -> void:
	var resolved: BattlePokemon = owner.get_active_battle_pokemon() if owner != null else null
	if resolved == null:
		return
	var spot: BattleSpot = resolved.resolve_battle_spot()
	if spot == null:
		return
	spot.set_pokemon_sprite_visible(is_visible)


static func get_active_effect(pokemon: BattlePokemon) -> SubstituteAilmentEffect:
	if pokemon == null:
		return null
	for effect in BattleEffectController.get_pokemon_effects(pokemon):
		if effect is SubstituteAilmentEffect:
			var substitute := effect as SubstituteAilmentEffect
			if substitute.is_active():
				return substitute
	return null


func is_active() -> bool:
	return not has_finished() and _hp > 0


func is_active_for_blocking() -> bool:
	return is_active() or _blocked_secondary_this_hit


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if not _affects_owner(pokemon):
		return

	if phase == Phases.ON_INCOMING_DAMAGE_CALCULATE:
		_apply_incoming_damage_calculate(ctx)
		return

	if phase == Phases.ON_VALIDATE_AILMENT:
		if is_active_for_blocking():
			if ctx != null and ctx.validation != null:
				ctx.validation.rejected = true
		return

	if phase == Phases.ON_INCOMING_DAMAGE_FINALIZE:
		_blocked_secondary_this_hit = false
		if not _pending_removal:
			return
		_pending_removal = false
		_pending_break_visualize = true


func _apply_incoming_damage_calculate(ctx: BattlePhaseContext) -> void:
	var effect: DamageEffect = ctx.damage.damage if ctx != null and ctx.damage != null else null
	if effect == null:
		return
	if not _affects_owner(effect.target):
		return
	var damage_user: BattlePokemon = effect.user.get_active_battle_pokemon() if effect.user != null else null
	var damage_target: BattlePokemon = effect.target.get_active_battle_pokemon() if effect.target != null else null
	if damage_user == damage_target:
		return
	if effect.amount <= 0 or effect.is_ineffective():
		return
	if _hp <= 0 and not _blocked_secondary_this_hit:
		return

	_blocked_secondary_this_hit = true
	var absorbed := mini(effect.amount, _hp)
	if absorbed > 0:
		_absorbed_damage_this_hit = true
	_hp -= absorbed
	# El muñeco absorbe todo el golpe; al romperse no pasa excedente al Pokémon.
	effect.amount = 0
	if _hp <= 0:
		_pending_removal = true


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if not _affects_owner(pokemon):
		return

	if phase == Phases.ON_INCOMING_DAMAGE_PRE:
		if not _absorbed_damage_this_hit:
			return
		_absorbed_damage_this_hit = false
		var damage_msg := _ailment_messages.get_substitute_damage_message(_owner)
		if not damage_msg.is_empty():
			await ui.show_message_from_dict(damage_msg)
		return

	if phase == Phases.ON_INCOMING_DAMAGE_POST:
		if not _pending_break_visualize:
			return
		_pending_break_visualize = false
		var break_msg := _ailment_messages.get_substitute_break_message(_owner)
		if not break_msg.is_empty():
			await ui.show_message_from_dict(break_msg)
		set_owner_sprite_visible(_owner, true)
		_finished = true
		BattleEffectController.remove_pokemon_effect(_owner, self)


func has_finished() -> bool:
	return _finished


func get_priority() -> int:
	return BattleEffectPriority.INCOMING_SUBSTITUTE
