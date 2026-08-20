extends Node2D

const _DISPLAY_MANAGER_SCENE := preload("res://Managers/DisplayManager.tscn")

@export_group("Equipos de prueba")
## Si true, lanza 1vs1 salvaje con party jugador 2+ para probar cambio forzado por KO (AC1).
@export var use_forced_switch_player_test: bool = false
## Si true, lanza 1vs1 entrenador con party 2+ (jugador y rival) para probar cambio forzado por KO.
@export var use_forced_switch_trainer_test: bool = false
## Si true, lanza 1vs1 salvaje: Clefairy (Sustituto + Anulación + Destructor + Látigo) vs Pidgey (solo Bostezo).
@export var use_fixed_substitute_test: bool = false
## Si true, lanza un 1vs1 salvaje fijo: Rattata Nv.20 vs Pidgey Nv.20 (pruebas ailments).
@export var use_fixed_rattata_vs_gastly: bool = false
## Si true, Pidgey solo lleva Látigo (útil para probar fallback si el movimiento bloqueado no es usable).
@export var debug_pidgey_status_only: bool = false
## true = Mordisco (retroceso 30%); false = Picotazo Veneno (veneno 30%).
@export var debug_rattata_test_bite: bool = true
## Si true, Rattata lleva Otra Vez/Mofa/Bostezo/Atracción (♂) y Pidgey Constricción (♀) para probar más volátiles.
@export var debug_rattata_extended_volatiles: bool = true
## Si true, el ailment del movimiento de prueba siempre se aplica (omite el %).
@export var debug_force_ailment_apply: bool = false
## Si true, todos los movimientos del combate fijo empiezan con 0 PP (prueba Forcejeo por PP).
## Desactivar para el escenario Sustituto/Anulación (Forcejeo vía Anulación, no por PP).
@export var debug_zero_pp: bool = false

@export_group("Debug mensajes MOVE_FAIL (PBI 687)")
## Escenario natural Machop vs Gastly (inmunidad, protección, evasión, fallo de precisión).
@export var use_move_fail_message_test: bool = false
## Escenario doble Pikachu+Machop vs Gastly débil + Rattata (sin objetivo al aplicar).
@export var use_move_fail_no_target_test: bool = false

@export_group("Debug clima")
## 1vs1 salvaje: Squirtle (Granizo + Día Soleado + Pistola Agua + Tormenta Arena) vs Pidgey (Tornado + Placaje).
@export var use_rain_weather_test: bool = false

@export_group("Debug field effects")
## 1vs1 salvaje: Squirtle (Neblina + Danza Espada + Pistola Agua + Placaje) vs Pidgey (Gruñido + Látigo + Tornado + Placaje).
@export var use_mist_test: bool = true

@export_group("Debug efectos persistentes")
## Al iniciar combate: lluvia activa, Reflejo en el lado del jugador y veneno en el primer activo.
## Sirve para probar el orden de mensajes al final del turno (Reflejo → Lluvia → Veneno).
@export var debug_seed_persistent_effects: bool = false
## Tamaño del party del jugador (1–6). En doble solo 2 salen al campo; el resto queda en banca para cambios.
@export_range(1, 6) var test_player_party_size: int = 6
## Tamaño del party del entrenador rival (1–6) cuando se use singleTrainerBattle / trainers en escena.
@export_range(1, 6) var test_trainer_party_size: int = 6

const WILD_PARTY_SINGLE: int = 1
const WILD_PARTY_DOUBLE: int = 2

# Instanciado solo al ejecutar esta escena en solitario (F6); en juego normal ya existe vía Main.
var _bootstrapped_display_manager: DisplayManager = null

#Battlers
@onready var player: Battler = $Player
@onready var singleTrainer: Battler = $SingleTrainer
@onready var wildPokemons: Battler = $WildPokemons


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not await _ensure_display_manager():
		return
	if use_move_fail_no_target_test:
		_setup_move_fail_no_target_test_parties()
		_print_move_fail_no_target_test_guide()
		await wildMoveFailNoTargetTestBattle()
		return
	if use_move_fail_message_test:
		_setup_move_fail_message_test_parties()
		_print_move_fail_message_test_guide()
		await wildMoveFailMessageTestBattle()
		return
	if use_forced_switch_player_test:
		_setup_forced_switch_player_test_parties()
		_print_forced_switch_player_guide()
		await forcedSwitchPlayerTestBattle()
		return
	if use_forced_switch_trainer_test:
		_print_forced_switch_trainer_guide()
		await forcedSwitchTrainerTestBattle()
		return
	if use_fixed_substitute_test:
		_setup_fixed_substitute_test_parties()
		_print_substitute_test_guide()
		_print_volatile_integration_guide()
		if debug_zero_pp:
			push_warning(
				"TestBattle: debug_zero_pp fuerza Forcejeo al pulsar LUCHAR. "
				+ "Desactívalo para probar Anulación → Forcejeo."
			)
		await wildFixedSubstituteTestBattle()
		return
	if use_mist_test:
		_seed_test_capture_items()
		_print_mist_test_guide()
		await wildMistTestBattle()
		return
	if use_rain_weather_test:
		_seed_test_capture_items()
		_print_rain_weather_test_guide()
		await wildRainWeatherTestBattle()
		return
	if use_fixed_rattata_vs_gastly:
		_setup_fixed_rattata_gastly_parties()
	else:
		_setup_test_battler_parties()
	_seed_test_capture_items()
	if use_fixed_rattata_vs_gastly:
		var chance_note := " (ailment garantizado)" if debug_force_ailment_apply else ""
		if debug_rattata_extended_volatiles:
			print(
				">>> Combate fijo: Rattata♂ (Otra Vez + Mofa + Bostezo + Atracción%s) vs Pidgey♀ (Anulación + Constricción + Bostezo + Tornado/Látigo)"
				% chance_note
			)
		else:
			var move_label := "Mordisco" if debug_rattata_test_bite else "Picotazo Veneno"
			print(
				">>> Combate fijo: Rattata (Otra Vez + Bostezo + %s%s) vs Pidgey (Anulación + Bostezo + Tornado + Látigo)"
				% [move_label, chance_note]
			)
		_print_volatile_integration_guide()
		if debug_pidgey_status_only:
			print(">>> debug_pidgey_status_only: Pidgey solo lleva Anulación + Bostezo + Látigo.")
		if debug_zero_pp:
			print(">>> debug_zero_pp: todos los movimientos a 0 PP — pulsa LUCHAR para Forcejeo.")
		await wildFixedRattataGastlyBattle()
		return
	# Lanzar combates en bucle para testing continuo
	while true:
		if randi() % 2 == 0:
			print(">>> Iniciando Single Wild Battle (Random)")
			await wildRandomSingleBattle()
		else:
			print(">>> Iniciando Double Wild Battle (Random)")
			await wildRandomDoubleBattle()
		await get_tree().create_timer(0.5).timeout


## Al ejecutar TestBattle.tscn directamente no existe Main/DisplayManager; lo creamos aquí.
func _ensure_display_manager() -> bool:
	if DisplayManager.instance != null:
		return true
	_bootstrapped_display_manager = _DISPLAY_MANAGER_SCENE.instantiate() as DisplayManager
	if _bootstrapped_display_manager == null:
		push_error("TestBattle: no se pudo instanciar DisplayManager.tscn")
		return false
	# No se puede add_child() durante _ready() del árbol; diferir y esperar su _ready().
	get_tree().root.add_child.call_deferred(_bootstrapped_display_manager)
	if not _bootstrapped_display_manager.is_node_ready():
		await _bootstrapped_display_manager.ready
	if DisplayManager.instance == null:
		push_error("TestBattle: DisplayManager no registró singleton tras _ready")
		return false
	print("TestBattle: DisplayManager de prueba inicializado (escena ejecutada en solitario).")
	return true


func wildSingleBattle():
	# Usar equipo del jugador (configurado en Player Battler)
	var playerParticipant: BattleParticipant = player.to_battle_participant()

	# Usar el primer Pokémon del equipo WildPokemons (configurado desde inspector)
	if wildPokemons.party.is_empty():
		push_error("wildSingleBattle: No hay Pokémon configurados en WildPokemons")
		return

	var wild_battle_pokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_battle_pokemon.is_wild = true
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wild_battle_pokemon])

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]

	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla terminada. Ganador: %s" % winner)


func wildDoubleBattle():
	# Usar equipo del jugador (configurado en Player Battler)
	var playerParticipant: BattleParticipant = player.to_battle_participant()

	# Usar los primeros 2 Pokémon del equipo WildPokemons (configurado desde inspector)
	if wildPokemons.party.size() < 2:
		push_error("wildDoubleBattle: Se necesitan al menos 2 Pokémon en WildPokemons")
		return

	var wild1 = wildPokemons.party[0].to_battle_pokemon()
	wild1.is_wild = true
	var wild2 = wildPokemons.party[1].to_battle_pokemon()
	wild2.is_wild = true
	var wildParticipant: BattleParticipant = BattleParticipantWild.new([wild1, wild2])

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.DOUBLE
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]

	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla terminada. Ganador: %s" % winner)

func wildMoveFailMessageTestBattle() -> void:
	_setup_move_fail_message_test_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildMoveFailMessageTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var test_ia := BattleIA_MoveFailTest.create_gastly_scenario()
	wild_bp.setIA(test_ia)
	var wild_participant: BattleParticipantWild = BattleParticipantWild.new([wild_bp])
	wild_participant.ai_controller = test_ia
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla MOVE_FAIL (1v1) terminada. Ganador: %s" % winner)


func wildMoveFailNoTargetTestBattle() -> void:
	_setup_move_fail_no_target_test_parties()
	var player_participant: BattleParticipant = _create_move_fail_no_target_player_participant()
	if wildPokemons == null or wildPokemons.party.size() < 2:
		push_error("TestBattle: wildMoveFailNoTargetTestBattle necesita 2 rivales en WildPokemons.")
		return
	var wild_team: Array[BattlePokemon] = []
	for p: Pokemon in wildPokemons.party:
		var wild_bp: BattlePokemon = p.to_battle_pokemon()
		wild_bp.is_wild = true
		wild_team.append(wild_bp)
	var wild_participant: BattleParticipant = BattleParticipantWild.new(wild_team)
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.DOUBLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla MOVE_FAIL (NO_TARGET) terminada. Ganador: %s" % winner)


func _setup_move_fail_message_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_move_fail_test_player_instance())
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_move_fail_test_enemy_instance())


func _setup_move_fail_no_target_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_move_fail_no_target_pikachu())
		player.add_pokemon_to_party(_create_move_fail_no_target_machop())
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_move_fail_no_target_enemy())
		wildPokemons.add_pokemon_to_party(_create_move_fail_no_target_decoy_enemy())


func _create_move_fail_test_player_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.MACHOP as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.HYPNOSIS,
	]
	pkmn._post_init()
	return pkmn


func _create_move_fail_test_enemy_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.GASTLY as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = true
	pkmn.custom_move_ids = [
		MovesEnum.Values.DOUBLE_TEAM,
		MovesEnum.Values.LICK,
		MovesEnum.Values.TAIL_WHIP,
	]
	pkmn._post_init()
	return pkmn


func _create_move_fail_no_target_pikachu() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIKACHU as PokemonsEnum.Values
	pkmn.level = 50
	pkmn.is_wild = false
	pkmn.custom_move_ids = [MovesEnum.Values.THUNDERBOLT]
	pkmn._post_init()
	return pkmn


func _create_move_fail_no_target_machop() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.MACHOP as PokemonsEnum.Values
	pkmn.level = 10
	pkmn.is_wild = false
	pkmn.custom_move_ids = [MovesEnum.Values.TACKLE]
	pkmn._post_init()
	return pkmn


func _create_move_fail_no_target_enemy() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.GASTLY as PokemonsEnum.Values
	pkmn.level = 5
	pkmn.is_wild = true
	pkmn.custom_move_ids = [MovesEnum.Values.LICK]
	pkmn._post_init()
	return pkmn


func _create_move_fail_no_target_decoy_enemy() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = true
	pkmn.custom_move_ids = [MovesEnum.Values.TAIL_WHIP]
	pkmn._post_init()
	return pkmn


func _create_move_fail_no_target_player_participant() -> BattleParticipant:
	var team: Array[BattlePokemon] = []
	if player == null or player.party.size() < 2:
		push_error("TestBattle: party insuficiente para NO_TARGET doble.")
		return BattleParticipant.new(team)
	for p: Pokemon in player.party:
		team.append(p.to_battle_pokemon())
	var participant := BattleParticipant.new(team)
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _print_move_fail_message_test_guide() -> void:
	print(">>> [MOVE_FAIL 1v1] Machop vs Gastly — casos naturales (IA de prueba en rival)")
	print(">>> Turno 1 — IMMUNE: Machop Placaje / Gastly Lengüetazo → «No afecta a Gastly...»")
	print(">>> Turnos 2-7 — EVADED: Machop Hipnosis / Gastly Doble Equipo (×6) → «¡Gastly esquivó el ataque!»")
	print(">>>        (Hipnosis es estado y sí afecta a Fantasma; Placaje siempre daría inmunidad)")
	print(">>> Turno 8+ — MISS_GLOBAL: Machop Hipnosis → repite hasta «¡El ataque de Machop falló!»")
	print(">>> NO_TARGET: activa use_move_fail_no_target_test y relanza F6.")


func _print_move_fail_no_target_test_guide() -> void:
	print(">>> [MOVE_FAIL doble] Pikachu + Machop vs Gastly Nv.5 + Rattata — NO_TARGET natural")
	print(">>> Turno 1: Pikachu → Rayo / Machop → Placaje (ambos apuntando a Gastly)")
	print(">>> Pikachu actúa primero (más rápido), debilita a Gastly. Rattata sigue en pie.")
	print(">>> Machop intenta Placaje al Gastly debilitado → «¡Pero no hay objetivo al que atacar!»")


func wildFixedRattataGastlyBattle() -> void:
	_setup_fixed_rattata_gastly_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildFixedRattataGastlyBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Rattata vs Pidgey terminada. Ganador: %s" % winner)


func wildRainWeatherTestBattle() -> void:
	_setup_rain_weather_test_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildRainWeatherTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla clima (Granizo) terminada. Ganador: %s" % winner)


func wildMistTestBattle() -> void:
	_setup_mist_test_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildMistTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Neblina terminada. Ganador: %s" % winner)


func wildFixedSubstituteTestBattle() -> void:
	_setup_fixed_substitute_test_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildFixedSubstituteTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Sustituto terminada. Ganador: %s" % winner)


func forcedSwitchTrainerTestBattle() -> void:
	var player_participant := _create_forced_switch_test_strong_player_participant()
	var trainer_participant := _create_forced_switch_test_trainer_participant()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla cambio forzado (trainer) terminada. Ganador: %s" % winner)


func _create_forced_switch_test_strong_player_participant() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 28
	charmander.is_wild = false
	charmander.custom_move_ids = [MovesEnum.Values.EMBER, MovesEnum.Values.SCRATCH, MovesEnum.Values.TAIL_WHIP]
	charmander._post_init()
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 28
	squirtle.is_wild = false
	squirtle.custom_move_ids = [MovesEnum.Values.WATER_GUN, MovesEnum.Values.TACKLE]
	squirtle._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	var bench: BattlePokemon = squirtle.to_battle_pokemon()
	lead.controllable = true
	bench.controllable = true
	var participant := BattleParticipant.new([lead, bench])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_forced_switch_test_trainer_participant() -> BattleParticipant:
	var ia := BattleIA_Easy.new()
	var lead: BattlePokemon = _create_forced_switch_test_player_lead(PokemonsEnum.Values.RATTATA).to_battle_pokemon()
	var bench: BattlePokemon = _create_forced_switch_test_player_lead(PokemonsEnum.Values.BULBASAUR).to_battle_pokemon()
	lead.setIA(ia)
	bench.setIA(ia)
	lead.controllable = false
	bench.controllable = false
	var participant := BattleParticipant.new([lead, bench])
	participant.ai_controller = ia
	participant.is_trainer = true
	participant.name = "Entrenador"
	return participant


func _print_forced_switch_trainer_guide() -> void:
	print(">>> Test cambio forzado (rival): Charmander + Squirtle (Nv.28) vs Rattata + Bulbasaur (Nv.8, entrenador).")
	print(">>> Debilita al Rattata rival → prompt de cambio opcional + envío automático de Bulbasaur.")


func forcedSwitchPlayerTestBattle() -> void:
	var player_participant := _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: forcedSwitchPlayerTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla cambio forzado (jugador) terminada. Ganador: %s" % winner)


func _setup_forced_switch_player_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(
			_create_forced_switch_test_player_lead(PokemonsEnum.Values.RATTATA, 20)
		)
		player.add_pokemon_to_party(
			_create_forced_switch_test_player_lead(PokemonsEnum.Values.BULBASAUR)
		)
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_forced_switch_test_enemy())


func _create_forced_switch_test_player_lead(species_id: int, level: int = 8) -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = species_id as PokemonsEnum.Values
	pkmn.level = level
	pkmn.is_wild = false
	pkmn.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.TAIL_WHIP]
	pkmn._post_init()
	return pkmn


func _create_forced_switch_test_enemy() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 8
	pkmn.is_wild = true
	pkmn.custom_move_ids = [MovesEnum.Values.GUST, MovesEnum.Values.TACKLE]
	pkmn._post_init()
	return pkmn


func _print_forced_switch_player_guide() -> void:
	print(">>> Test cambio forzado (jugador): Rattata (Nv.20) + Bulbasaur (Nv.8) vs Pidgey (Nv.8).")
	print(">>> Deja que el rival debilite al activo → debe abrirse Party obligatoria (sin cancelar).")
	print(">>> Elige Bulbasaur (o el otro vivo) y comprueba mensaje de entrada + ON_SWITCH_IN.")


func _setup_rain_weather_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_rain_weather_test_player_instance())
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_rain_weather_test_enemy_instance())


func _create_rain_weather_test_player_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	pkmn.level = 50
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.REFLECT,
		MovesEnum.Values.LIGHT_SCREEN,
		MovesEnum.Values.SAFEGUARD,
		MovesEnum.Values.HAIL,
	]
	pkmn._post_init()
	return pkmn


func _create_rain_weather_test_enemy_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = true
	pkmn.custom_move_ids = [
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.THUNDER_WAVE,
		MovesEnum.Values.POISON_STING,
	]
	pkmn._post_init()
	return pkmn


func _print_rain_weather_test_guide() -> void:
	print(">>> Combate pantallas: Squirtle (Reflejo + Pantalla de Luz + Velo Sagrado + Granizo) vs Pidgey (Tornado + Placaje + Onda Trueno + Picotazo Veneno).")
	print(">>>   1) Reflejo → Placaje rival (físico) hace la mitad de daño.")
	print(">>>   2) Pantalla de Luz → Tornado rival (especial) hace la mitad de daño.")
	print(">>>   3) Velo Sagrado → Onda Trueno / Picotazo Veneno no aplican parálisis/veneno.")
	print(">>>   4) Sin Velo Sagrado: Onda Trueno puede paralizar; Picotazo Veneno puede envenenar (activa debug_force_ailment_apply para 100%).")
	print(">>>   5) Tras 5 turnos: mensajes de fin de cada pantalla.")
	print(">>>   (Opcional) Granizo sigue disponible para probar clima.")


func _setup_mist_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_mist_test_player_instance())
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_mist_test_enemy_instance())


func _create_mist_test_player_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	pkmn.level = 50
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.MIST,
		MovesEnum.Values.SWORDS_DANCE,
		MovesEnum.Values.WATER_GUN,
		MovesEnum.Values.TACKLE,
	]
	pkmn._post_init()
	return pkmn


func _create_mist_test_enemy_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = true
	pkmn.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.TAIL_WHIP,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pkmn._post_init()
	return pkmn


func _print_mist_test_guide() -> void:
	print(">>> Combate Neblina: Squirtle (Neblina + Danza Espada + Pistola Agua + Placaje) vs Pidgey (Gruñido + Látigo + Tornado + Placaje).")
	print(">>>   1) Turno 1 — Neblina: «¡Neblina protege a los Pokémon de tu equipo!»")
	print(">>>   2) Pidgey usa Gruñido o Látigo → «¡La neblina protege las características de Squirtle!» (sin bajar stats)")
	print(">>>   3) Squirtle usa Danza Espada → sube Ataque (Neblina no bloquea subidas propias)")
	print(">>>   4) Repetir Neblina con pantalla activa → «¡Pero falló!»")
	print(">>>   5) Tras 5 turnos de combate: «¡La neblina en tu equipo se disipó!» → Gruñido/Látigo vuelven a bajar stats")


func _setup_fixed_substitute_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_substitute_test_player_instance())
		player.add_pokemon_to_party(
			_create_test_party_pokemon(PokemonsEnum.Values.BULBASAUR, CONST.GENEROS.MACHO, false)
		)
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_substitute_test_enemy_instance())


func _create_substitute_test_player_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.CLEFAIRY as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.SUBSTITUTE,
		MovesEnum.Values.DISABLE,
		MovesEnum.Values.POUND,
		MovesEnum.Values.TAIL_WHIP,
	]
	pkmn._post_init()
	_apply_debug_zero_pp(pkmn)
	return pkmn


func _create_substitute_test_enemy_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 20
	pkmn.is_wild = true
	pkmn.custom_move_ids = [
		MovesEnum.Values.YAWN,
	]
	pkmn._post_init()
	_apply_debug_zero_pp(pkmn)
	return pkmn


func _print_substitute_test_guide() -> void:
	var ailment_note := " (ailments garantizados)" if debug_force_ailment_apply else ""
	print(">>> Combate Sustituto: Clefairy (Sustituto + Anulación + Destructor + Látigo) vs Pidgey (solo Bostezo)%s" % ailment_note)
	if debug_zero_pp:
		print(">>> AVISO: debug_zero_pp=ON → Forcejeo inmediato. Ponlo en false para probar Anulación.")
	else:
		print(">>> Prueba Anulación → Forcejeo (debug_zero_pp desactivado):")
		print(">>>   1) Turno 1 — Pidgey (más rápido) usa Bostezo; Clefairy elige Anulación.")
		print(">>>   2) Turno 2 — Pidgey no puede usar Bostezo → Forcejeo automático (IA).")
	print(">>> Otros (Sustituto):")
	print(">>>   · Clefairy usa Sustituto: pierde ~1/4 PS máx, mensaje «creó un sustituto».")
	print(">>>   · Con sustituto activo — Forcejeo de Pidgey daña al muñeco.")


func _print_volatile_integration_guide() -> void:
	print(">>> [PBI 686] Guía integración volátiles — ver Docs/battle/temporary-states-precedence.md")
	if debug_rattata_extended_volatiles:
		print(">>> Escenario extendido Rattata♂ vs Pidgey♀:")
		print(">>>   · Mofa bloquea movimientos de estado; Atracción puede bloquear el ataque (solo un msg pre-move).")
		print(">>>   · Constricción (Pidgey) → trap; intenta cambiar: mensaje «está atrapado».")
		print(">>>   · Otra Vez + Anulación → Forcejeo si el movimiento encadenado queda anulado.")
	else:
		print(">>> Escenario Rattata vs Pidgey (Encore+Disable+Yawn):")
		print(">>>   · Anulación bloquea el último movimiento usado; con Otra Vez activo → Forcejeo si el movimiento encadenado está anulado.")
		print(">>>   · Solo un mensaje de bloqueo pre-move por turno (sueño > parálisis > retroceso > confusión > enamoramiento).")
	print(">>> Escenario Sustituto:")
	print(">>>   · Trap/switch: mensaje «está atrapado» vía ON_VALIDATE_SWITCH (no bypass silencioso).")
	print(">>>   · Fin de turno: veneno/trap/perish/yawn en orden fijo por prioridad; Pokémon más rápidos primero.")


## 1vs1 salvaje: Pikachu♂ vs Clefairy♀ con Atracción; ambos equipos tienen banca para probar cambios.
func wildFixedAttractTestBattle() -> void:
	_setup_fixed_attract_test_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildFixedAttractTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Atracción terminada. Ganador: %s" % winner)


func _setup_fixed_attract_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(
			_create_attract_test_pokemon(PokemonsEnum.Values.PIKACHU, CONST.GENEROS.MACHO, false)
		)
		player.add_pokemon_to_party(
			_create_test_party_pokemon(PokemonsEnum.Values.BULBASAUR, CONST.GENEROS.MACHO, false)
		)
		player.add_pokemon_to_party(
			_create_test_party_pokemon(PokemonsEnum.Values.CHARMANDER, CONST.GENEROS.MACHO, false)
		)
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(
			_create_attract_test_pokemon(PokemonsEnum.Values.CLEFAIRY, CONST.GENEROS.HEMBRA, true)
		)
		wildPokemons.add_pokemon_to_party(
			_create_test_party_pokemon(PokemonsEnum.Values.VULPIX, CONST.GENEROS.HEMBRA, true)
		)
		wildPokemons.add_pokemon_to_party(
			_create_test_party_pokemon(PokemonsEnum.Values.JIGGLYPUFF, CONST.GENEROS.HEMBRA, true)
		)


func _create_attract_test_pokemon(species_id: int, pokemon_gender: int, is_wild: bool) -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = species_id as PokemonsEnum.Values
	pkmn.level = 20
	pkmn.gender = pokemon_gender
	pkmn.is_wild = is_wild
	pkmn.custom_move_ids = [MovesEnum.Values.ATTRACT]
	pkmn._post_init()
	return pkmn


func _create_test_party_pokemon(species_id: int, pokemon_gender: int, is_wild: bool) -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = species_id as PokemonsEnum.Values
	pkmn.level = 20
	pkmn.gender = pokemon_gender
	pkmn.is_wild = is_wild
	pkmn._post_init()
	return pkmn


func wildRandomSingleBattle():
	# Generar equipos completamente aleatorios para jugador y salvaje
	var playerParticipant: BattleParticipant = _create_random_player_participant(test_player_party_size)
	var wildParticipant: BattleParticipant = _create_random_wild_participant(WILD_PARTY_SINGLE)

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]

	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla terminada. Ganador: %s" % winner)

func wildRandomDoubleBattle():
	# Generar equipos aleatorios: en doble salen 2 activos; el party completo permite cambios.
	var playerParticipant: BattleParticipant = _create_random_player_participant(test_player_party_size)
	var wildParticipant: BattleParticipant = _create_random_wild_participant(WILD_PARTY_DOUBLE)

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.DOUBLE
	)

	var participants:Array[BattleParticipant] = [playerParticipant, wildParticipant]

	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla terminada. Ganador: %s" % winner)

func singleTrainerBattle():
	# Usar equipos configurados en ambos Battlers (Player vs SingleTrainer)
	var playerParticipant: BattleParticipant = player.to_battle_participant()
	var trainerParticipant: BattleParticipant = singleTrainer.to_battle_participant()

	var rules = BattleRules.new(
		BattleRules.BattleTypes.TRAINER,
		BattleRules.BattleModes.SINGLE
	)

	var participants:Array[BattleParticipant] = [playerParticipant, trainerParticipant]

	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla terminada. Ganador: %s" % winner)


func _start_test_battle(participants: Array[BattleParticipant], rules: BattleRules) -> String:
	if debug_seed_persistent_effects:
		BattleDebugEffectSeeder.enable()
	if debug_zero_pp:
		_apply_debug_zero_pp_to_participants(participants)
	BattleDebugAilmentTest.force_ailment_apply = debug_force_ailment_apply
	var winner: String = await DisplayManager.start_battle(participants, rules)
	BattleDebugAilmentTest.force_ailment_apply = false
	return winner


func _create_rattata_ailment_test_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	pkmn.level = 20
	pkmn.is_wild = false
	if debug_rattata_extended_volatiles:
		pkmn.gender = CONST.GENEROS.MACHO
		pkmn.custom_move_ids = [
			MovesEnum.Values.ENCORE,
			MovesEnum.Values.TAUNT,
			MovesEnum.Values.YAWN,
			MovesEnum.Values.ATTRACT,
		]
	else:
		var move_id: MovesEnum.Values = (
			MovesEnum.Values.BITE if debug_rattata_test_bite
			else MovesEnum.Values.POISON_STING
		)
		pkmn.custom_move_ids = [
			MovesEnum.Values.ENCORE,
			MovesEnum.Values.YAWN,
			move_id,
			MovesEnum.Values.TAIL_WHIP,
		]
	pkmn._post_init()
	_apply_debug_zero_pp(pkmn)
	return pkmn


func _create_pidgey_trap_test_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 20
	pkmn.is_wild = true
	if debug_rattata_extended_volatiles:
		pkmn.gender = CONST.GENEROS.HEMBRA
		if debug_pidgey_status_only:
			pkmn.custom_move_ids = [
				MovesEnum.Values.DISABLE,
				MovesEnum.Values.WRAP,
				MovesEnum.Values.YAWN,
				MovesEnum.Values.TAIL_WHIP,
			]
		else:
			pkmn.custom_move_ids = [
				MovesEnum.Values.DISABLE,
				MovesEnum.Values.WRAP,
				MovesEnum.Values.YAWN,
				MovesEnum.Values.GUST,
			]
	elif debug_pidgey_status_only:
		pkmn.custom_move_ids = [
			MovesEnum.Values.DISABLE,
			MovesEnum.Values.YAWN,
			MovesEnum.Values.TAIL_WHIP,
		]
	else:
		pkmn.custom_move_ids = [
			MovesEnum.Values.DISABLE,
			MovesEnum.Values.YAWN,
			MovesEnum.Values.GUST,
			MovesEnum.Values.TAIL_WHIP,
		]
	pkmn._post_init()
	_apply_debug_zero_pp(pkmn)
	return pkmn


func _apply_debug_zero_pp(pkmn: Pokemon) -> void:
	if not debug_zero_pp or pkmn == null:
		return
	for mv in pkmn.movements:
		if mv != null:
			mv.pp_actual = 0


func _apply_debug_zero_pp_to_participants(participants: Array[BattleParticipant]) -> void:
	for participant in participants:
		if participant == null:
			continue
		for bp in participant.pokemon_team:
			if bp == null:
				continue
			for mv in bp.get_available_moves():
				if mv != null and mv.base_data != null:
					mv.base_data.pp_actual = 0
	print(">>> debug_zero_pp: PP a 0 en todos los movimientos de combate activos.")


## Party en escena para `player` / `wildPokemons` (combate fijo por battler opcional).
func _setup_fixed_rattata_gastly_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_rattata_ailment_test_instance())
		player.add_pokemon_to_party(
			_create_test_party_pokemon(PokemonsEnum.Values.BULBASAUR, CONST.GENEROS.MACHO, false)
		)
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_pidgey_trap_test_instance())


## Rellena los Battler de escena para pruebas con party configurado en inspector.
func _setup_test_battler_parties() -> void:
	_fill_battler_random_party(player, test_player_party_size, false)
	# Salvajes: máx. 2 (single usa el primero; doble los dos). Sin banca rival.
	_trim_battler_party(wildPokemons, WILD_PARTY_DOUBLE)
	_fill_battler_random_party(wildPokemons, WILD_PARTY_DOUBLE, true)
	if singleTrainer != null and singleTrainer.party.is_empty():
		_fill_battler_random_party(singleTrainer, test_trainer_party_size, false)


func _fill_battler_random_party(battler: Battler, target_size: int, as_wild: bool) -> void:
	if battler == null or target_size <= 0:
		return
	while battler.party.size() < target_size:
		battler.add_pokemon_to_party(_create_random_pokemon_instance(as_wild))


func _trim_battler_party(battler: Battler, max_size: int) -> void:
	if battler == null or max_size < 0:
		return
	while battler.party.size() > max_size:
		battler.party.pop_back()


## Poké Balls para probar captura desde la mochila de combate (usa `GameStateService.bag`).
func _seed_test_capture_items() -> void:
	if GameStateService == null:
		return
	var bag = GameStateService.get_bag()
	if bag == null:
		return
	bag.add_item(4, 10)  # Poké Ball
	bag.add_item(3, 10)  # Super Ball
	bag.add_item(2, 10)  # Ultra Ball
	bag.add_item(17, 20)  # Poción
	bag.add_item(26, 10)  # Superpoción
	bag.add_item(25, 10)  # Hiperpoción
	bag.add_item(24, 5)   # Poción Máxima
	bag.add_item(18, 10)  # Antídoto
	print("TestBattle: ítems de prueba en mochila (bolas x10, pociones, Antídoto x10).")


func _create_pokemon_instance(
	species_id: int, level: int, is_wild: bool, forced_ability = null
) -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = species_id as PokemonsEnum.Values
	pkmn.level = level
	pkmn.is_wild = is_wild
	if forced_ability != null:
		pkmn.ability_id = int(forced_ability) as AbilitiesEnum.Values
	pkmn._post_init()
	return pkmn


func _create_fixed_player_participant() -> BattleParticipant:
	var team: Array[BattlePokemon] = []
	if player == null or player.party.is_empty():
		push_error("TestBattle: el Battler Player no tiene party configurado.")
		return BattleParticipant.new(team)
	for p: Pokemon in player.party:
		team.append(p.to_battle_pokemon())
	var participant := BattleParticipant.new(team)
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_fixed_wild_participant(species_id: int, level: int) -> BattleParticipant:
	var bp: BattlePokemon = _create_pokemon_instance(species_id, level, true).to_battle_pokemon()
	bp.is_wild = true
	return BattleParticipantWild.new([bp])


# Helper: genera un Pokémon aleatorio (instancia persistente / party)
func _create_random_pokemon_instance(is_wild: bool = false) -> Pokemon:
	return _create_pokemon_instance(randi_range(1, 151), randi_range(1, 100), is_wild)


# Helper: genera un BattlePokemon aleatorio
func _create_random_pokemon(is_wild: bool = false) -> BattlePokemon:
	return _create_random_pokemon_instance(is_wild).to_battle_pokemon()

# Helper: genera participante salvaje con N Pokémon aleatorios
func _create_random_wild_participant(num_pokemon: int = 1) -> BattleParticipant:
	var wild_team: Array[BattlePokemon] = []
	for i in num_pokemon:
		wild_team.append(_create_random_pokemon(true))
	return BattleParticipantWild.new(wild_team)

# Helper: genera participante de jugador con N Pokémon aleatorios
func _create_random_player_participant(num_pokemon: int = 1) -> BattleParticipant:
	var player_team: Array[BattlePokemon] = []
	for i in num_pokemon:
		player_team.append(_create_random_pokemon(false))
	var participant := BattleParticipant.new(player_team)
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_random_trainer_participant(num_pokemon: int = 1) -> BattleParticipant:
	var trainer_team: Array[BattlePokemon] = []
	var ia := BattleIA_Easy.new()
	for i in num_pokemon:
		var bp := _create_random_pokemon(false)
		bp.setIA(ia)
		trainer_team.append(bp)
	var participant := BattleParticipant.new(trainer_team)
	participant.ai_controller = ia
	participant.is_trainer = true
	participant.name = "Entrenador"
	return participant

#
#func singleTrainerBattle_OLD():
	#var selected_pokemon = null#getPokemon()
	#var selected_level:int = 5#getLevel()
	#
	#var br : BattleRules = BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	#var bc : BattleController = BattleController.new(br)
#
	#bc.playerSide.addParticipant($Player, true)
	#bc.enemySide.addParticipant($SingleTrainer, false)
	#
	#bc.playerSide.initSide(br)
	#bc.enemySide.initSide(br)
	#await bc.initBattle()
	#
	#
#func wildBattle_OLD():
	#var selected_pokemon = null#getPokemon()
	#var selected_level:int = 5#getLevel()
#
	#var pkmn = PokemonInstance.new().create(true)#, 5, selected_level)
	#pkmn.isWild = true
	#print("A wild " + str(pkmn.Name) + " Lvl. " + str(pkmn.level) + " appeared!")
	#
	#var enemyBattler : Battler = Battler.new().create(CONST.BATTLER_TYPES.WILD_POKEMON, [pkmn], BattleIA_Wild.new())
	#
	#var br : BattleRules = BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	#var bc : BattleController = BattleController.new(br)
	##var bs_player : BattleSide = BattleSide.new(CONST.BATTLE_SIDES.PLAYER)
	##var bs_enemy : BattleSide = BattleSide.new(CONST.BATTLE_SIDES.ENEMY)
	#bc.playerSide.addParticipant($Player, true)
	#bc.enemySide.addParticipant(enemyBattler, false)
	#bc.enemySide.isWild = true
	#
	#bc.playerSide.initSide(br)
	#bc.enemySide.initSide(br)
	#await bc.initBattle()
	#
