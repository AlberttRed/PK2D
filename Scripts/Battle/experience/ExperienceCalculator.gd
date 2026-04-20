extends RefCounted

class_name ExperienceCalculator

## PROVISIONAL — pruebas rápidas: si no es 0, cada receptor gana esta EXP por cada rival KO (ignora la fórmula).
const DEBUG_FIXED_EXP_PER_KO_PER_RECIPIENT: int = 0

## Resultado por Pokémon tras aplicar EXP (antes de la subida de nivel en otro paso).
class ParticipantOutcome extends RefCounted:
	var battle_pokemon: BattlePokemon
	var pokemon: Pokemon
	var gained_exp: int = 0
	var new_total_exp: int = 0
	## Cantidad de EXP que falta para alcanzar el umbral del nivel actual+1 (progreso a “siguiente nivel”).
	var exp_for_next_level: int = 0


## Resultado agregado del reparto por un combate (uno o más rivales KO).
class GrantResult extends RefCounted:
	var outcomes: Array[ParticipantOutcome] = []
	## Truncado entero final de la fórmula base (por KO, sin repartir); útil para depuración.
	var last_raw_yield_per_participant: int = 0


## Fórmula basada en franquicia (simil. gen reciente): floor((base * L_enemigo) / (7 * S)) · mult.
## S = nº de Pokémon aliados que reciben EXP. `mult` = 1,5 en combate vs entrenador, 1 vs salvaje.
static func _raw_exp_per_participant(base_experience: int, defeated_level: int, participant_count: int, is_trainer_battle: bool) -> int:
	if participant_count <= 0:
		return 0
	var trainer_mult: float = 1.5 if is_trainer_battle else 1.0
	var raw: float = float(base_experience * defeated_level) / float(7 * participant_count) * trainer_mult
	var v := int(floor(raw))
	return maxi(1, v)


static func _resolve_base_experience(defeated: BattlePokemon) -> int:
	var mon: Pokemon = defeated.base_data
	if mon == null or mon.base == null:
		push_warning("ExperienceCalculator: Pokémon derrotado sin PokemonData; usando base EXP 40.")
		return 40
	var v: int = mon.base.base_exprience
	if v <= 0:
		push_warning("ExperienceCalculator: base_exprience ≤ 0 para especie id=%d; usando fallback 40." % mon.base.id)
		return 40
	return v


static func _exp_remaining_to_next_threshold(pokemon: Pokemon) -> int:
	var grp := PokemonExperienceGroup.new(pokemon.base.growth_rate_id)
	if pokemon.level >= 100:
		return 0
	var need_total: int = grp.get_total_exp_for_level(pokemon.level + 1)
	return maxi(0, need_total - pokemon.totalExp)


## Suma EXP a cada destinatario por cada rival KO y rellena `GrantResult`.
static func grant_for_defeated_enemies(
	defeated: Array[BattlePokemon],
	recipients: Array[BattlePokemon],
	is_trainer_battle: bool
) -> GrantResult:
	var result := GrantResult.new()
	if defeated.is_empty() or recipients.is_empty():
		return result

	var gains: Dictionary = {}  # BattlePokemon -> int
	for rec_bp: BattlePokemon in recipients:
		if rec_bp != null:
			gains[rec_bp] = 0

	for bp in defeated:
		if bp == null:
			continue
		var base_y := _resolve_base_experience(bp)
		var lv: int = bp.get_level()
		var per := _raw_exp_per_participant(base_y, lv, recipients.size(), is_trainer_battle)
		if DEBUG_FIXED_EXP_PER_KO_PER_RECIPIENT > 0:
			per = DEBUG_FIXED_EXP_PER_KO_PER_RECIPIENT
		result.last_raw_yield_per_participant = per
		for rec_bp: BattlePokemon in recipients:
			if rec_bp == null:
				continue
			gains[rec_bp] = int(gains.get(rec_bp, 0)) + per

	if DEBUG_FIXED_EXP_PER_KO_PER_RECIPIENT > 0:
		print("ExperienceCalculator: MODO PROVISIONAL — %d EXP por KO y receptor (DEBUG_FIXED_EXP_PER_KO_PER_RECIPIENT)" % DEBUG_FIXED_EXP_PER_KO_PER_RECIPIENT)
	print("ExperienceCalculator: repartiendo EXP — KOs=%d, participantes=%d, último trozo/part=%d (trainer=%s)" % [
		defeated.size(), recipients.size(), result.last_raw_yield_per_participant, str(is_trainer_battle)
	])

	for rec_bp: BattlePokemon in recipients:
		if rec_bp == null or rec_bp.base_data == null:
			continue
		var rec: Pokemon = rec_bp.base_data
		var g: int = int(gains.get(rec_bp, 0))
		if g <= 0:
			continue
		rec.totalExp += g
		var po := ParticipantOutcome.new()
		po.battle_pokemon = rec_bp
		po.pokemon = rec
		po.gained_exp = g
		po.new_total_exp = rec.totalExp
		po.exp_for_next_level = _exp_remaining_to_next_threshold(rec)
		result.outcomes.append(po)
		print("  → %s +%d EXP → total %d (faltan %d para Nv.%d)" % [
			rec.get_display_name(), g, rec.totalExp, po.exp_for_next_level, mini(rec.level + 1, 100)
		])

	return result
