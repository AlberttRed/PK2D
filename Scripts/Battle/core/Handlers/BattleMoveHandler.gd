extends BattleHandler

class_name BattleMoveHandler

var user
var target: BattleTarget
var move
var category = null

# Marcador genérico que los Multi-Hit pueden consultar al final
var show_effectiveness: bool = false

# Control de ejecución: si apply() falla, no se ejecuta visualize()
var _should_visualize: bool = true

func _init(_move, _user, _target, _category = null):
	move = _move
	user = _user
	target = _target
	category = _category


# Template method: valida target y ejecuta _apply() de los hijos
func apply() -> void:
	if not target.is_valid():
		_should_visualize = false
		return
	_apply()
	_should_visualize = true

# Template method: solo visualiza si apply() tuvo éxito
func visualize(ui: BattleUI) -> void:
	if not _should_visualize:
		return
	await _visualize(ui)

# Métodos abstractos que cada hijo debe implementar
func _apply() -> void:
	pass

func _visualize(_ui: BattleUI) -> void:
	pass

# Valida/retarget en runtime si el movimiento es de objetivo único enemigo.
# Devuelve true si hay target válido (posiblemente retargeteado); false si no hay objetivos.
func ensure_valid_single_enemy_target_or_null() -> bool:
	if move == null or target == null:
		return true
	
	var is_single: bool = target.is_pokemon() and target.is_single_enemy_selection_type()
	if not is_single:
		return true

	var tp: BattlePokemon = target.get_pokemon()
	if tp != null and tp.in_battle and not tp.is_fainted() and tp.battle_spot != null:
		return true
	
	var candidates: Array[BattlePokemon] = user.get_opponent_side().get_active_pokemons()
	candidates = candidates.filter(func(p): return p != tp and not p.is_fainted() and p.battle_spot != null)
	if candidates.is_empty():
		return false
	target = BattleTarget.new(candidates[0].battle_spot, target.selection_type)
	return true


func _bind_effect_context(effect: PersistentBattleEffect) -> void:
	if effect == null:
		return
	effect.user = user
	effect.target = target.get_pokemon() if target != null else null


func _validate_ailment_apply(ailment: AilmentData, effect_instance: PersistentBattleEffect) -> int:
	var pokemon: BattlePokemon = target.get_pokemon() if target != null else null
	if ailment == null or pokemon == null:
		return ApplyFailReason.Values.OK

	if ailment.is_persistent:
		var current_status := _get_current_major_ailment(pokemon)
		if current_status != null:
			if _ailments_match(current_status, ailment):
				return ApplyFailReason.Values.ALREADY_ACTIVE
			return ApplyFailReason.Values.GENERIC_FAIL

	if effect_instance != null:
		return effect_instance.can_apply()
	return ApplyFailReason.Values.OK


func _get_current_major_ailment(pokemon: BattlePokemon) -> AilmentData:
	if pokemon.status != null:
		return pokemon.status
	if pokemon.base_data != null:
		return AilmentData.from_major_status(pokemon.base_data.major_status)
	return null


func _ailments_match(current: AilmentData, incoming: AilmentData) -> bool:
	if current == null or incoming == null:
		return false
	var current_enum := current.get_enum_value()
	var incoming_enum := incoming.get_enum_value()
	if current_enum != AilmentsEnum.Values.NONE and current_enum == incoming_enum:
		return true
	if not current.internal_name.is_empty() and current.internal_name == incoming.internal_name:
		return true
	var current_major := AilmentData.to_major_status(current)
	var incoming_major := AilmentData.to_major_status(incoming)
	return current_major != CONST.STATUS.OK and current_major == incoming_major
