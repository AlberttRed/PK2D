extends TrainerBattleIA

class_name BattleIA_TrainerTest

## IA de entrenador **solo para TestBattle / debug**.
## Ejecuta un guion de acciones (MOVE / SWITCH / EASY) y luego cae a TrainerEasy.
## No es contenido de juego; no asignar a TrainerData.

enum StepKind {
	## Primer movimiento legal (o move_id si se pasa).
	MOVE,
	## Cambio voluntario a banca (party_index opcional; -1 = primer bench vivo).
	SWITCH,
	## Una decisión con BattleIA_TrainerEasy.
	EASY,
}

## Cola de pasos: cada turno consume uno.
## Dicts admitidos:
## - { "kind": StepKind.MOVE } o { "kind": StepKind.MOVE, "move_id": int }
## - { "kind": StepKind.SWITCH } o { "kind": StepKind.SWITCH, "party_index": int }
## - { "kind": StepKind.EASY }
var action_plan: Array[Dictionary] = []
var _step := 0
var _easy: BattleIA_TrainerEasy = null


func _init() -> void:
	difficulty_name = "TrainerTest"
	use_items = false
	can_switch_strategically = true


## Turno 1: cambia al primer bench; luego Easy.
static func create_switch_first_turn() -> BattleIA_TrainerTest:
	var ia := BattleIA_TrainerTest.new()
	ia.action_plan = [
		{"kind": StepKind.SWITCH},
	]
	return ia


## Guion libre (copia defensiva de los dicts).
static func create_with_script(steps: Array[Dictionary]) -> BattleIA_TrainerTest:
	var ia := BattleIA_TrainerTest.new()
	ia.action_plan = steps.duplicate(true)
	return ia


func decide_action(pokemon: BattlePokemon) -> BattleChoice:
	if _step < action_plan.size():
		var step: Dictionary = action_plan[_step]
		_step += 1
		var kind: int = int(step.get("kind", StepKind.EASY))
		match kind:
			StepKind.SWITCH:
				var sw := _try_build_switch(pokemon, int(step.get("party_index", -1)))
				if sw != null:
					print("[IA_TEST] SWITCH → %s" % sw.incoming_pokemon.get_display_name())
					return sw
				push_warning("[IA_TEST] SWITCH pedido sin banca válida; fallback Easy.")
			StepKind.MOVE:
				var move_choice := _try_build_move(pokemon, int(step.get("move_id", -1)))
				if move_choice != null:
					print("[IA_TEST] MOVE")
					return move_choice
				push_warning("[IA_TEST] MOVE pedido sin legal; fallback Easy.")
			StepKind.EASY:
				print("[IA_TEST] EASY (paso de guion)")
				return _decide_easy(pokemon)
			_:
				push_warning("[IA_TEST] kind desconocido %d; fallback Easy." % kind)
	return _decide_easy(pokemon)


func decide_forced_switch(side: BattleSide, spot: BattleSpot, fainted: BattlePokemon) -> BattleSwitchChoice:
	# Tras KO: respeta party_index del siguiente SWITCH del guion si existe.
	if _step < action_plan.size():
		var step: Dictionary = action_plan[_step]
		if int(step.get("kind", -1)) == StepKind.SWITCH:
			_step += 1
			var idx := int(step.get("party_index", -1))
			var owner: BattleParticipant = fainted.participant if fainted != null else null
			var incoming := _resolve_bench(side, idx, owner)
			if incoming != null:
				print("[IA_TEST] forced SWITCH → %s" % incoming.get_display_name())
				return _make_forced_switch_choice(side, spot, fainted, incoming)
	return build_first_available_forced_switch(side, spot, fainted)


func _decide_easy(pokemon: BattlePokemon) -> BattleChoice:
	if _easy == null:
		_easy = BattleIA_TrainerEasy.new()
	return _easy.decide_action(pokemon)


func _try_build_switch(pokemon: BattlePokemon, party_index: int) -> BattleSwitchChoice:
	if pokemon == null or pokemon.side == null:
		return null
	var incoming := _resolve_bench(pokemon.side, party_index, pokemon.participant)
	if incoming == null:
		return null
	var choice := BattleSwitchChoice.new()
	choice.side = pokemon.side
	choice.target_spot = pokemon.battle_spot
	choice.outgoing_pokemon = pokemon
	choice.incoming_pokemon = incoming
	choice.pokemon = pokemon
	choice.forced_by_faint = false
	if pokemon.battle_spot != null:
		choice.origin_spot_index = pokemon.battle_spot.index
	choice.target_index = pokemon.side.pokemonParty.find(incoming)
	return choice


## Banca solo del participante (en 2vs2 no se puede robar el bench del compañero).
func _resolve_bench(
	side: BattleSide,
	party_index: int,
	participant: BattleParticipant = null
) -> BattlePokemon:
	if side == null:
		return null
	var pool: Array[BattlePokemon] = (
		side.get_participant_battle_party(participant)
		if participant != null
		else side.pokemonParty
	)
	if party_index >= 0 and party_index < pool.size():
		var p: BattlePokemon = pool[party_index]
		if p != null and not p.is_fainted() and not p.in_battle:
			return p
		return null
	return find_first_bench_pokemon(side, participant)


func _try_build_move(pokemon: BattlePokemon, move_id: int) -> BattleChoice:
	if pokemon == null:
		return null
	var moves := pokemon.get_available_moves()
	if moves.is_empty():
		return null
	var legal := get_selectable_move_indices(pokemon)
	if legal.is_empty():
		return null

	var move_index := -1
	if move_id >= 0:
		for i in moves.size():
			if moves[i].get_id() == move_id and i in legal:
				move_index = i
				break
	if move_index < 0:
		move_index = legal[0]

	var move: BattleMove = moves[move_index]
	var choice := BattleMoveChoice.new()
	choice.move_index = move_index
	choice.pokemon = pokemon
	var selector := BattleTargetSelector.new()
	choice.targets = selector.resolve_targets(move, pokemon, null)
	return choice
