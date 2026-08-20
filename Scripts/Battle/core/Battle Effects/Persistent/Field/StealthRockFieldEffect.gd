class_name StealthRockFieldEffect
extends HazardFieldEffect

## Gen 4: daño al entrar = floor(maxHP × efectividad_Roca / 8).
## No usa capas (max_layers = 1). Volador/Levitate NO inmunizan.
## Magic Guard sí bloquea el daño.

var _pending_entry_damage: int = 0
var _pending_entry_target: BattlePokemon = null


func _init(
	_source = null,
	_side_type: BattleSide.Types = BattleSide.Types.NONE,
	_max_layers: int = 1
) -> void:
	super._init(_source, _side_type, _max_layers)


func apply_on_entry(pokemon: BattlePokemon) -> void:
	_pending_entry_damage = 0
	_pending_entry_target = null
	if pokemon == null or pokemon.is_fainted():
		return
	if _is_immune(pokemon):
		return
	var dmg := _damage_for_pokemon(pokemon)
	if dmg <= 0:
		return
	var effect := DamageEffect.new(null, pokemon, null, dmg)
	pokemon.take_damage(effect)
	_pending_entry_damage = dmg
	_pending_entry_target = pokemon


func visualize_on_entry(pokemon: BattlePokemon, ui: BattleUI) -> void:
	if _pending_entry_target == null or _pending_entry_damage <= 0:
		return
	if pokemon != _pending_entry_target:
		return
	if pokemon.battle_spot != null:
		await pokemon.battle_spot.apply_damage()
	if ui != null:
		await ui.show_stealth_rock_damage_message(pokemon)
	_pending_entry_damage = 0
	_pending_entry_target = null


static func find_on_side(lookup_side_type: BattleSide.Types) -> StealthRockFieldEffect:
	if lookup_side_type == BattleSide.Types.NONE:
		return null
	for effect in BattleEffectController.get_all_active_effects():
		if (
			effect is StealthRockFieldEffect
			and (effect as StealthRockFieldEffect).side_type == lookup_side_type
		):
			return effect as StealthRockFieldEffect
	return null


static func _damage_for_pokemon(pokemon: BattlePokemon) -> int:
	if pokemon == null or pokemon.total_hp <= 0:
		return 0
	var rock_type := DatabaseService.get_type(TypesEnum.Values.ROCK) as TypeData
	if rock_type == null:
		push_warning("StealthRockFieldEffect: no se pudo cargar el tipo Roca.")
		return 0
	var mult := rock_type.get_effectiveness_against_pokemon(pokemon)
	if mult <= 0.0:
		return 0
	var dmg := int(floor(float(pokemon.total_hp) * mult / 8.0))
	return maxi(dmg, 1)


func _is_immune(pokemon: BattlePokemon) -> bool:
	if pokemon.ability == null:
		return false
	return int(pokemon.ability.id) == AbilitiesEnum.Values.MAGIC_GUARD
