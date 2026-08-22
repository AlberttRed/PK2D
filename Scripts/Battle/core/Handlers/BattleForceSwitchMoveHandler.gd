extends BattleMoveHandler

class_name BattleForceSwitchMoveHandler

var switch_effect: SwitchEffect = null

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func _apply() -> void:
	# Forzar cambio de Pokémon del lado rival: sacar target actual y meter el siguiente disponible
	if target.get_pokemon() == null:
		return

	var side: BattleSide = target.get_pokemon().side

	# Buscar spot del target
	var spot: BattleSpot = target.get_pokemon().battle_spot

	# Seleccionar siguiente Pokémon disponible del mismo participante (no del compañero en 2vs2).
	var outgoing: BattlePokemon = target.get_pokemon()
	var participant: BattleParticipant = outgoing.participant if outgoing != null else null
	var pool: Array[BattlePokemon] = (
		side.get_participant_battle_party(participant)
		if participant != null
		else side.pokemonParty
	)
	var candidates: Array[BattlePokemon] = []
	for p in pool:
		if p != null and not p.is_fainted() and not p.in_battle:
			candidates.append(p)
	if candidates.is_empty():
		return
	var replacement := candidates[0]
	switch_effect = SwitchEffect.new(side, spot, outgoing, replacement, side.battle_rules)
	switch_effect.apply()

func _visualize(ui) -> void:
	if switch_effect != null:
		await switch_effect.visualize(ui)


