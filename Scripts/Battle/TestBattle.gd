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

@export_group("Debug IA tipada (PBI 705 / 342)")
## 1vs1 fijo para validar TrainerEasy / WildBasic, tipado y fallbacks.
@export var use_battle_ia_typing_test: bool = false
## Escenario del test de IA (ver guía en consola al arrancar).
@export_enum("Type Advantage", "Avoid Immunity", "All Immune Random", "Wild Basic") var battle_ia_test_scenario: int = 0

@export_group("Debug mensajes MOVE_FAIL (PBI 687)")
## Escenario natural Machop vs Gastly (inmunidad, protección, evasión, fallo de precisión).
@export var use_move_fail_message_test: bool = false
## Escenario doble Pikachu+Machop vs Gastly débil + Rattata (sin objetivo al aplicar).
@export var use_move_fail_no_target_test: bool = false

@export_group("Debug animaciones de combate")
## 1vs1 salvaje: Charmander (Ascuas + Arañazo + Placaje) vs Squirtle — animación Ember / Ascuas.
@export var use_ember_animation_test: bool = false
## 1vs1 salvaje: Charmander (Látigo + Placaje) vs Pidgey (Látigo + Tornado) — animación Tail Whip.
@export var use_tail_whip_animation_test: bool = false
## 1vs1 salvaje: Charmander (Ataque Rápido + Placaje) vs Pidgey (Ataque Rápido + Tornado) — animación Quick Attack.
@export var use_quick_attack_animation_test: bool = false
## 1vs1 salvaje: Charmander (Picotazo Veneno) vs Pidgey — animación ailment Poison (aplicar + daño fin de turno).
@export var use_poison_ailment_animation_test: bool = false
## 1vs1 salvaje: Charmander (Canto) vs Pidgey — animación ailment Sleep (aplicar + “sigue dormido”).
@export var use_sleep_ailment_animation_test: bool = false
## 1vs1 salvaje: Charmander (Rayo Hielo) vs Squirtle — animación ailment Freeze.
@export var use_freeze_ailment_animation_test: bool = false
## 1vs1 salvaje: Charmander (Onda Trueno) vs Squirtle — animación ailment Paralysis.
@export var use_paralysis_ailment_animation_test: bool = false
## 1vs1 salvaje: Charmander (Supersónico) vs Squirtle — animación ailment Confusion.
@export var use_confusion_ailment_animation_test: bool = false
## 1vs1 salvaje: Charmander vs Pidgey — fase 1 captura (lanzar ball → abrir/cerrar → rebotes).
@export var use_capture_throw_animation_test: bool = true
## 1vs1 salvaje: Charizard (Gruñido + Placaje) vs Gyarados (Gruñido + Tornado) — animación Growl (sprites grandes).
@export var use_growl_animation_test: bool = false
## 1vs1 entrenador: Charmander vs Squirtle (+ banca) — intro ball throw player/rival y switch-in.
@export var use_pokeball_animation_trainer_test: bool = false
## 1vs1 salvaje: Charmander (+ banca) vs Pidgey — intro party + send-in jugador (sin trainer rival).
@export var use_wild_animation_test: bool = false
## 2vs2 salvaje: Gyarados+Charizard vs Gyarados+Charizard — alineación sombra en doble (sprites grandes).
@export var use_double_wild_animation_test: bool = false
## 2vs2 entrenador: 1 trainer jugador vs 1 trainer rival (Gyarados lead rival + Machamp).
@export var use_double_trainer_vs_trainer_test: bool = false
## 1vs1 salvaje: Charmander (Malicioso + Placaje) vs Pidgey (Malicioso + Tornado) — animación Leer.
@export var use_leer_animation_test: bool = false
## 1vs1 salvaje: Charmander (Destructor + Placaje) vs Pidgey (Destructor + Tornado) — animación Pound.
@export var use_pound_animation_test: bool = false
## 1vs1 salvaje: Charmander (Ataque Arena + Placaje) vs Pidgey (Ataque Arena + Tornado) — animación Sand Attack.
@export var use_sand_attack_animation_test: bool = false
## 1vs1 salvaje: Charmander (Mordisco + Placaje) vs Pidgey (Mordisco + Tornado) — animación Bite.
@export var use_bite_animation_test: bool = false
## 2vs2 multi-entrenador: 2 trainers jugador vs 2 trainers rival — intro doble y send-in por spot.
@export var use_double_trainer_animation_test: bool = false
## Si true, JugadorB también es humano (controlas ambos spots). Si false, JugadorB es aliado IA en tu lado.
@export var double_trainer_ally_controllable: bool = false
## 1vs1 entrenador con BattleIA_TrainerTest (guion SWITCH/MOVE/EASY). Ver trainer_ia_test_scenario.
@export var use_trainer_ia_test: bool = false
## Escenario del guion de BattleIA_TrainerTest.
@export_enum("Switch First Turn") var trainer_ia_test_scenario: int = 0

@export_group("Debug clima")
## 1vs1 salvaje: clima lluvia al inicio — oscurecimiento + gotas (RainFrames).
@export var use_rain_weather_animation_test: bool = false
## 1vs1 salvaje: Squirtle (Granizo + Día Soleado + Pistola Agua + Tormenta Arena) vs Pidgey (Tornado + Placaje).
@export var use_rain_weather_test: bool = false

@export_group("Debug field effects")
## 1vs1 salvaje: Squirtle (Neblina + Danza Espada + Pistola Agua + Placaje) vs Pidgey (Gruñido + Látigo + Tornado + Placaje).
@export var use_mist_test: bool = false
## 1vs1 salvaje: Slowpoke Nv.50 vs Pidgey Nv.24 — Tailwind invierte orden (~40 vs ~39).
@export var use_tailwind_test: bool = false
## 1vs1 entrenador: Squirtle (Púas) vs Rattata + Bulbasaur (+ Pidgey Volador) — capas y daño al entrar.
@export var use_spikes_test: bool = false
## 1vs1 entrenador: Squirtle (Púas Tóxicas) vs Rattata + Sandshrew + Ekans + Diglett — capas, absorción y grounded.
@export var use_toxic_spikes_test: bool = false
## 1vs1 entrenador: Squirtle (Trampa Rocas) vs Rattata + Machop + Charizard — daño × efectividad Roca.
@export var use_stealth_rock_test: bool = false
## 1vs1 entrenador: Reflect + Spikes + Toxic Spikes + Stealth Rock — convivencia PBI 704.
@export var use_field_effects_integration_test: bool = false

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
	if use_battle_ia_typing_test:
		_print_battle_ia_typing_test_guide()
		_run_battle_ia_fallback_probe()
		await battleIaTypingTestBattle()
		return
	if use_ember_animation_test:
		_print_ember_animation_test_guide()
		await wildEmberAnimationTestBattle()
		return
	if use_tail_whip_animation_test:
		_print_tail_whip_animation_test_guide()
		await wildTailWhipAnimationTestBattle()
		return
	if use_quick_attack_animation_test:
		_print_quick_attack_animation_test_guide()
		await wildQuickAttackAnimationTestBattle()
		return
	if use_poison_ailment_animation_test:
		_print_poison_ailment_animation_test_guide()
		await wildPoisonAilmentAnimationTestBattle()
		return
	if use_sleep_ailment_animation_test:
		_print_sleep_ailment_animation_test_guide()
		await wildSleepAilmentAnimationTestBattle()
		return
	if use_freeze_ailment_animation_test:
		_print_freeze_ailment_animation_test_guide()
		await wildFreezeAilmentAnimationTestBattle()
		return
	if use_paralysis_ailment_animation_test:
		_print_paralysis_ailment_animation_test_guide()
		await wildParalysisAilmentAnimationTestBattle()
		return
	if use_confusion_ailment_animation_test:
		_print_confusion_ailment_animation_test_guide()
		await wildConfusionAilmentAnimationTestBattle()
		return
	if use_rain_weather_animation_test:
		_print_rain_weather_animation_test_guide()
		await wildRainWeatherAnimationTestBattle()
		return
	if use_capture_throw_animation_test:
		_print_capture_throw_animation_test_guide()
		await wildCaptureThrowAnimationTestBattle()
		return
	if use_growl_animation_test:
		_print_growl_animation_test_guide()
		await wildGrowlAnimationTestBattle()
		return
	if use_leer_animation_test:
		_print_leer_animation_test_guide()
		await wildLeerAnimationTestBattle()
		return
	if use_pound_animation_test:
		_print_pound_animation_test_guide()
		await wildPoundAnimationTestBattle()
		return
	if use_sand_attack_animation_test:
		_print_sand_attack_animation_test_guide()
		await wildSandAttackAnimationTestBattle()
		return
	if use_bite_animation_test:
		_print_bite_animation_test_guide()
		await wildBiteAnimationTestBattle()
		return
	if use_wild_animation_test:
		_print_wild_animation_test_guide()
		await wildAnimationTestBattle()
		return
	if use_double_wild_animation_test:
		_print_double_wild_animation_test_guide()
		await wildDoubleAnimationTestBattle()
		return
	if use_double_trainer_vs_trainer_test:
		_print_double_trainer_vs_trainer_test_guide()
		await doubleTrainerVsTrainerTestBattle()
		return
	if use_double_trainer_animation_test:
		_print_double_trainer_animation_test_guide()
		await doubleTrainerAnimationTestBattle()
		return
	if use_trainer_ia_test:
		_print_trainer_ia_test_guide()
		await trainerIaTestBattle()
		return
	if use_pokeball_animation_trainer_test:
		_print_pokeball_animation_trainer_test_guide()
		await trainerPokeballAnimationTestBattle()
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
	if use_tailwind_test:
		_seed_test_capture_items()
		_print_tailwind_test_guide()
		await wildTailwindTestBattle()
		return
	if use_spikes_test:
		_seed_test_capture_items()
		_print_spikes_test_guide()
		await spikesTrainerTestBattle()
		return
	if use_toxic_spikes_test:
		_seed_test_capture_items()
		_print_toxic_spikes_test_guide()
		await toxicSpikesTrainerTestBattle()
		return
	if use_stealth_rock_test:
		_seed_test_capture_items()
		_print_stealth_rock_test_guide()
		await stealthRockTrainerTestBattle()
		return
	if use_field_effects_integration_test:
		_seed_test_capture_items()
		BattleDebugEffectSeeder.enable_reflect_only()
		_print_field_effects_integration_test_guide()
		await fieldEffectsIntegrationTrainerTestBattle()
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


func wildRainWeatherAnimationTestBattle() -> void:
	_setup_rain_animation_test_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildRainWeatherAnimationTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación lluvia terminada. Ganador: %s" % winner)


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


func wildTailwindTestBattle() -> void:
	_setup_tailwind_test_parties()
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	if wildPokemons == null or wildPokemons.party.is_empty():
		push_error("TestBattle: wildTailwindTestBattle sin rival en WildPokemons.")
		return
	var wild_bp: BattlePokemon = wildPokemons.party[0].to_battle_pokemon()
	wild_bp.is_wild = true
	var wild_participant: BattleParticipant = BattleParticipantWild.new([wild_bp])
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Viento Afín terminada. Ganador: %s" % winner)


func spikesTrainerTestBattle() -> void:
	var player_participant := _create_spikes_test_player_participant()
	var trainer_participant := _create_spikes_test_trainer_participant()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Púas terminada. Ganador: %s" % winner)


func toxicSpikesTrainerTestBattle() -> void:
	var player_participant := _create_toxic_spikes_test_player_participant()
	var trainer_participant := _create_toxic_spikes_test_trainer_participant()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Púas Tóxicas terminada. Ganador: %s" % winner)


func stealthRockTrainerTestBattle() -> void:
	var player_participant := _create_stealth_rock_test_player_participant()
	var trainer_participant := _create_stealth_rock_test_trainer_participant()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Trampa Rocas terminada. Ganador: %s" % winner)


func fieldEffectsIntegrationTrainerTestBattle() -> void:
	var player_participant := _create_field_effects_integration_player_participant()
	var trainer_participant := _create_field_effects_integration_trainer_participant()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla integración field effects terminada. Ganador: %s" % winner)


func wildEmberAnimationTestBattle() -> void:
	var player_participant := _create_ember_animation_test_player()
	var wild_participant := _create_ember_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Ascuas terminada. Ganador: %s" % winner)


func wildTailWhipAnimationTestBattle() -> void:
	var player_participant := _create_tail_whip_animation_test_player()
	var wild_participant := _create_tail_whip_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Látigo terminada. Ganador: %s" % winner)


func wildQuickAttackAnimationTestBattle() -> void:
	var player_participant := _create_quick_attack_animation_test_player()
	var wild_participant := _create_quick_attack_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Ataque Rápido terminada. Ganador: %s" % winner)


func wildPoisonAilmentAnimationTestBattle() -> void:
	var prev_force := debug_force_ailment_apply
	debug_force_ailment_apply = true
	var player_participant := _create_poison_ailment_animation_test_player()
	var wild_participant := _create_poison_ailment_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	debug_force_ailment_apply = prev_force
	print(">>> Batalla animación Poison terminada. Ganador: %s" % winner)


func wildSleepAilmentAnimationTestBattle() -> void:
	var prev_force := debug_force_ailment_apply
	debug_force_ailment_apply = true
	var player_participant := _create_sleep_ailment_animation_test_player()
	var wild_participant := _create_sleep_ailment_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	debug_force_ailment_apply = prev_force
	print(">>> Batalla animación Sleep terminada. Ganador: %s" % winner)


func wildFreezeAilmentAnimationTestBattle() -> void:
	var prev_force := debug_force_ailment_apply
	debug_force_ailment_apply = true
	var player_participant := _create_freeze_ailment_animation_test_player()
	var wild_participant := _create_freeze_ailment_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	debug_force_ailment_apply = prev_force
	print(">>> Batalla animación Freeze terminada. Ganador: %s" % winner)


func wildParalysisAilmentAnimationTestBattle() -> void:
	var prev_force := debug_force_ailment_apply
	debug_force_ailment_apply = true
	var player_participant := _create_paralysis_ailment_animation_test_player()
	var wild_participant := _create_paralysis_ailment_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	debug_force_ailment_apply = prev_force
	print(">>> Batalla animación Paralysis terminada. Ganador: %s" % winner)


func wildConfusionAilmentAnimationTestBattle() -> void:
	var prev_force := debug_force_ailment_apply
	debug_force_ailment_apply = true
	var player_participant := _create_confusion_ailment_animation_test_player()
	var wild_participant := _create_confusion_ailment_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	debug_force_ailment_apply = prev_force
	print(">>> Batalla animación Confusion terminada. Ganador: %s" % winner)


func wildCaptureThrowAnimationTestBattle() -> void:
	_seed_test_capture_items()
	var player_participant := _create_capture_throw_animation_test_player()
	var wild_participant := _create_capture_throw_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación captura (fase 1) terminada. Ganador: %s" % winner)


func wildGrowlAnimationTestBattle() -> void:
	var player_participant := _create_growl_animation_test_player()
	var wild_participant := _create_growl_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Gruñido terminada. Ganador: %s" % winner)


func wildLeerAnimationTestBattle() -> void:
	var player_participant := _create_leer_animation_test_player()
	var wild_participant := _create_leer_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Malicioso terminada. Ganador: %s" % winner)


func wildPoundAnimationTestBattle() -> void:
	var player_participant := _create_pound_animation_test_player()
	var wild_participant := _create_pound_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Destructor terminada. Ganador: %s" % winner)


func wildSandAttackAnimationTestBattle() -> void:
	var player_participant := _create_sand_attack_animation_test_player()
	var wild_participant := _create_sand_attack_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Ataque Arena terminada. Ganador: %s" % winner)


func wildBiteAnimationTestBattle() -> void:
	var player_participant := _create_bite_animation_test_player()
	var wild_participant := _create_bite_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Mordisco terminada. Ganador: %s" % winner)


func wildAnimationTestBattle() -> void:
	var player_participant := _create_pokeball_animation_test_player()
	var wild_participant := _create_wild_animation_test_wild()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animaciones salvaje terminada. Ganador: %s" % winner)


func wildDoubleAnimationTestBattle() -> void:
	var player_participant := _create_double_wild_animation_test_player()
	var wild_participant := _create_double_wild_animation_test_wilds()
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.DOUBLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animaciones salvaje 2vs2 terminada. Ganador: %s" % winner)


func doubleTrainerVsTrainerTestBattle() -> void:
	var player_participant := _create_double_trainer_vs_trainer_test_player()
	var trainer_participant := _create_double_trainer_vs_trainer_test_trainer()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.DOUBLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla 2vs2 trainer vs trainer terminada. Ganador: %s" % winner)


func doubleTrainerAnimationTestBattle() -> void:
	# Trainer A: starters básicos. Trainer B: primeras evoluciones. Mismo en ambos lados.
	var party_a: Array = [
		PokemonsEnum.Values.CHARMANDER,
		PokemonsEnum.Values.SQUIRTLE,
		PokemonsEnum.Values.BULBASAUR,
	]
	var party_b: Array = [
		PokemonsEnum.Values.CHARMELEON,
		PokemonsEnum.Values.WARTORTLE,
		PokemonsEnum.Values.IVYSAUR,
	]
	var player_a := _create_double_trainer_test_participant("JugadorA", party_a, 20, true)
	var player_b := _create_double_trainer_test_participant("JugadorB", party_b, 22, false)
	# Aliado IA en el lado jugador (no controlable).
	player_b.joins_player_side = true
	var enemy_a := _create_double_trainer_test_participant("RivalA", party_a, 20, false)
	var enemy_b := _create_double_trainer_test_participant("RivalB", party_b, 22, false)
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.DOUBLE)
	var participants: Array[BattleParticipant] = [player_a, player_b, enemy_a, enemy_b]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla 2vs2 trainers terminada. Ganador: %s" % winner)


func trainerPokeballAnimationTestBattle() -> void:
	var player_participant := _create_pokeball_animation_test_player()
	var trainer_participant := _create_pokeball_animation_test_trainer()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla animación Poké Ball (trainer) terminada. Ganador: %s" % winner)


func trainerIaTestBattle() -> void:
	var player_participant := _create_pokeball_animation_test_player()
	var trainer_participant := _create_trainer_ia_test_trainer()
	var rules := BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla IA TrainerTest terminada. Ganador: %s" % winner)


func _create_trainer_ia_test_trainer() -> BattleParticipant:
	var ia := _build_trainer_ia_test()
	var lead_pkmn := Pokemon.new()
	lead_pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	lead_pkmn.level = 18
	lead_pkmn.is_wild = false
	lead_pkmn.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
	]
	lead_pkmn._post_init()
	var lead: BattlePokemon = lead_pkmn.to_battle_pokemon()
	lead.setIA(ia)
	lead.controllable = false

	var bench_pkmn := Pokemon.new()
	bench_pkmn.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	bench_pkmn.level = 16
	bench_pkmn.is_wild = false
	bench_pkmn.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
	]
	bench_pkmn._post_init()
	var bench: BattlePokemon = bench_pkmn.to_battle_pokemon()
	bench.setIA(ia)
	bench.controllable = false

	var participant := BattleParticipant.new([lead, bench])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "EntrenadorTest"
	var test_trainer_data: TrainerData = load("res://Resources/Trainers/TEST.tres") as TrainerData
	if test_trainer_data != null:
		participant.defeat_message = test_trainer_data.get_defeat_message()
	return participant


func _build_trainer_ia_test() -> BattleIA_TrainerTest:
	match trainer_ia_test_scenario:
		_:
			return BattleIA_TrainerTest.create_switch_first_turn()


func _print_trainer_ia_test_guide() -> void:
	print(">>> Test BattleIA_TrainerTest: Charmander+Squirtle vs Squirtle+Rattata.")
	print(">>> Escenario %d — por defecto: turno 1 el rival CAMBIA (recall + send-in)." % trainer_ia_test_scenario)
	print(">>> Guion ampliable en Scripts/Battle/debug/BattleIA_TrainerTest.gd (MOVE/SWITCH/EASY).")
	print(">>> Desactiva use_field_effects_integration_test y activa use_trainer_ia_test.")


func _create_pokeball_animation_test_player() -> BattleParticipant:
	var lead_pkmn := Pokemon.new()
	lead_pkmn.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	lead_pkmn.level = 20
	lead_pkmn.is_wild = false
	lead_pkmn.custom_move_ids = [
		MovesEnum.Values.SCRATCH,
		MovesEnum.Values.EMBER,
		MovesEnum.Values.TACKLE,
	]
	lead_pkmn._post_init()
	var lead: BattlePokemon = lead_pkmn.to_battle_pokemon()
	lead.controllable = true

	var bench_pkmn := Pokemon.new()
	bench_pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	bench_pkmn.level = 18
	bench_pkmn.is_wild = false
	bench_pkmn.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
	]
	bench_pkmn._post_init()
	var bench: BattlePokemon = bench_pkmn.to_battle_pokemon()
	bench.controllable = true

	var participant := BattleParticipant.new([lead, bench])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_pokeball_animation_test_trainer() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var lead_pkmn := Pokemon.new()
	lead_pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	lead_pkmn.level = 18
	lead_pkmn.is_wild = false
	lead_pkmn.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
	]
	lead_pkmn._post_init()
	var lead: BattlePokemon = lead_pkmn.to_battle_pokemon()
	lead.setIA(ia)
	lead.controllable = false

	var bench_pkmn := Pokemon.new()
	bench_pkmn.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	bench_pkmn.level = 16
	bench_pkmn.is_wild = false
	bench_pkmn.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
	]
	bench_pkmn._post_init()
	var bench: BattlePokemon = bench_pkmn.to_battle_pokemon()
	bench.setIA(ia)
	bench.controllable = false

	var participant := BattleParticipant.new([lead, bench])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador"
	participant.defeat_message = "¡Imposible! ¡Mis Pokémon eran los mejores!"
	return participant


func _print_pokeball_animation_trainer_test_guide() -> void:
	print(">>> Test animación Poké Ball (trainer): Charmander+Squirtle vs Squirtle+Rattata.")
	print(">>> Intro: throw rival (envío entrenador) + throw jugador (¡Adelante!).")
	print(">>> Cambia de Pokémon para ver throw en switch-in.")


func _create_wild_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _create_double_wild_animation_test_player() -> BattleParticipant:
	var gyarados := Pokemon.new()
	gyarados.pokemon_id = PokemonsEnum.Values.GYARADOS as PokemonsEnum.Values
	gyarados.level = 40
	gyarados.is_wild = false
	gyarados.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	gyarados._post_init()
	var lead_a: BattlePokemon = gyarados.to_battle_pokemon()
	lead_a.controllable = true

	var charizard := Pokemon.new()
	charizard.pokemon_id = PokemonsEnum.Values.CHARIZARD as PokemonsEnum.Values
	charizard.level = 40
	charizard.is_wild = false
	charizard.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charizard._post_init()
	var lead_b: BattlePokemon = charizard.to_battle_pokemon()
	lead_b.controllable = true

	var participant := BattleParticipant.new([lead_a, lead_b])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_double_wild_animation_test_wilds() -> BattleParticipant:
	var gyarados := Pokemon.new()
	gyarados.pokemon_id = PokemonsEnum.Values.GYARADOS as PokemonsEnum.Values
	gyarados.level = 40
	gyarados.is_wild = true
	gyarados.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	gyarados._post_init()
	var wild_a: BattlePokemon = gyarados.to_battle_pokemon()
	wild_a.is_wild = true

	var charizard := Pokemon.new()
	charizard.pokemon_id = PokemonsEnum.Values.CHARIZARD as PokemonsEnum.Values
	charizard.level = 40
	charizard.is_wild = true
	charizard.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charizard._post_init()
	var wild_b: BattlePokemon = charizard.to_battle_pokemon()
	wild_b.is_wild = true

	return BattleParticipantWild.new([wild_a, wild_b])


func _print_wild_animation_test_guide() -> void:
	print(">>> Test animaciones combate salvaje: Charmander+Squirtle vs Pidgey salvaje.")
	print(">>> Intro: slide bases → HP salvaje → «Pidgey salvaje apareció» → send-in jugador (sin party bar).")
	print(">>> El salvaje ya está en campo (sin ball throw rival). Cambia Pokémon para probar switch player.")
	print(">>> Desactiva use_wild_animation_test para volver al bucle aleatorio o activar otro flag.")


func _print_double_wild_animation_test_guide() -> void:
	print(">>> Test 2vs2 salvaje: Gyarados+Charizard (ambos tuyos) vs Gyarados+Charizard salvajes.")
	print(">>> Intro: bases → HP dobles salvajes → mensaje → send-in jugador A/B.")
	print(">>> Comprueba alineación pies/sombra en los 4 spots. Controlas ambos Pokémon.")
	print(">>> Desactiva use_double_wild_animation_test para volver a otro flag.")


func _create_double_trainer_test_participant(
	trainer_name: String,
	pokemon_ids: Array,
	level: int,
	is_player: bool,
	ai: BattleIA = null
) -> BattleParticipant:
	var ia_resolved: BattleIA = ai
	if not is_player and ia_resolved == null:
		ia_resolved = BattleIA_TrainerEasy.new()

	var party: Array[BattlePokemon] = []
	for pokemon_id_variant in pokemon_ids:
		var pokemon_id: PokemonsEnum.Values = pokemon_id_variant as PokemonsEnum.Values
		party.append(_create_double_trainer_battle_pokemon(pokemon_id, level, is_player, ia_resolved))

	var participant := BattleParticipant.new(party)
	participant.is_player = is_player
	participant.is_trainer = not is_player
	participant.name = trainer_name
	if not is_player:
		participant.ai_controller = ia_resolved
		participant.defeat_message = "¡%s ha perdido el combate!" % trainer_name
	return participant


func _create_double_trainer_battle_pokemon(
	pokemon_id: PokemonsEnum.Values,
	level: int,
	is_player: bool,
	ia: BattleIA
) -> BattlePokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = pokemon_id
	pkmn.level = level
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.SURF,
		MovesEnum.Values.FURY_ATTACK,
		MovesEnum.Values.TACKLE,
	]
	pkmn._post_init()
	var bp: BattlePokemon = pkmn.to_battle_pokemon(ia)
	bp.controllable = is_player
	if not is_player:
		bp.setIA(ia)
	return bp


func _create_double_trainer_vs_trainer_test_player() -> BattleParticipant:
	# Activos: Charizard + Venusaur. Banca: Blastoise (cambio / KO en doble).
	var lead_a := _make_double_tvt_battle_pokemon(
		PokemonsEnum.Values.CHARIZARD,
		40,
		[
			MovesEnum.Values.FLAMETHROWER,
			MovesEnum.Values.WING_ATTACK,
			MovesEnum.Values.GROWL,
			MovesEnum.Values.SCRATCH,
		],
		true
	)
	var lead_b := _make_double_tvt_battle_pokemon(
		PokemonsEnum.Values.VENUSAUR,
		40,
		[
			MovesEnum.Values.RAZOR_LEAF,
			MovesEnum.Values.VINE_WHIP,
			MovesEnum.Values.LEECH_SEED,
			MovesEnum.Values.GROWL,
		],
		true
	)
	var bench := _make_double_tvt_battle_pokemon(
		PokemonsEnum.Values.BLASTOISE,
		38,
		[
			MovesEnum.Values.SURF,
			MovesEnum.Values.ICE_BEAM,
			MovesEnum.Values.PROTECT,
			MovesEnum.Values.TACKLE,
		],
		true
	)
	var participant := BattleParticipant.new([lead_a, lead_b, bench])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_double_trainer_vs_trainer_test_trainer() -> BattleParticipant:
	# Lead A = Gyarados (pedido QA). Partner = Machamp. Banca = Pikachu.
	var ia := BattleIA_TrainerEasy.new()
	var gyarados := _make_double_tvt_battle_pokemon(
		PokemonsEnum.Values.GYARADOS,
		40,
		[
			MovesEnum.Values.HYDRO_PUMP,
			MovesEnum.Values.ICE_BEAM,
			MovesEnum.Values.BITE,
			MovesEnum.Values.THUNDERBOLT,
		],
		false,
		ia
	)
	var machamp := _make_double_tvt_battle_pokemon(
		PokemonsEnum.Values.MACHAMP,
		40,
		[
			MovesEnum.Values.EARTHQUAKE,
			MovesEnum.Values.TACKLE,
			MovesEnum.Values.LEER,
			MovesEnum.Values.PROTECT,
		],
		false,
		ia
	)
	var pikachu := _make_double_tvt_battle_pokemon(
		PokemonsEnum.Values.PIKACHU,
		36,
		[
			MovesEnum.Values.THUNDERBOLT,
			MovesEnum.Values.QUICK_ATTACK,
			MovesEnum.Values.GROWL,
			MovesEnum.Values.TACKLE,
		],
		false,
		ia
	)
	var participant := BattleParticipant.new([gyarados, machamp, pikachu])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador"
	participant.intro_message = "¡Prepárate para un combate doble!"
	participant.defeat_message = "¡Imposible! ¡Mi Gyarados era imbatible!"
	return participant


func _make_double_tvt_battle_pokemon(
	pokemon_id: PokemonsEnum.Values,
	level: int,
	move_ids: Array,
	is_player: bool,
	ia: BattleIA = null
) -> BattlePokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = pokemon_id
	pkmn.level = level
	pkmn.is_wild = false
	var typed_moves: Array[MovesEnum.Values] = []
	for move_id in move_ids:
		typed_moves.append(move_id as MovesEnum.Values)
	pkmn.custom_move_ids = typed_moves
	pkmn._post_init()
	var bp: BattlePokemon = pkmn.to_battle_pokemon()
	bp.controllable = is_player
	if not is_player and ia != null:
		bp.setIA(ia)
	return bp


func _print_double_trainer_vs_trainer_test_guide() -> void:
	print(">>> Test DOBLE 1 trainer vs 1 trainer (lógica de combate).")
	print(">>> Jugador: Charizard + Venusaur (activos) + Blastoise (banca).")
	print(">>> Rival: Gyarados + Machamp (activos) + Pikachu (banca). IA: TrainerEasy.")
	print(">>> Moves útiles: Surf/Earthquake (área), Ice Beam/Bite/Flamethrower (elige objetivo), Protect, Leech Seed.")
	print(">>> Revisa: targeting en doble, KO → cambio forzado, orden de turnos, daño a aliado (Earthquake).")
	print(">>> Escena: TestBattle.tscn con use_double_trainer_vs_trainer_test = true.")


func _print_double_trainer_animation_test_guide() -> void:
	print(">>> Test 2vs2 trainers (aliado IA): JugadorA (tú) + JugadorB (IA) vs RivalA + RivalB.")
	print(">>> Trainer A (ambos lados): Charmander + Squirtle + Bulbasaur. Activo: Charmander.")
	print(">>> Trainer B (ambos lados): Charmeleon + Wartortle + Ivysaur. Activo: Charmeleon.")
	print(">>> Solo eliges acciones de JugadorA; aliado y rivales usan TrainerEasy.")
	print(">>> Intro: bases → party → «X y Y quieren luchar» → send-in rival A/B → send-in jugador A/B.")
	print(">>> Escena: TestBattle.tscn con use_double_trainer_animation_test = true.")


func _create_ember_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.EMBER,
		MovesEnum.Values.SCRATCH,
		MovesEnum.Values.TACKLE,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_ember_animation_test_wild() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 20
	squirtle.is_wild = true
	squirtle.custom_move_ids = [
		MovesEnum.Values.EMBER,
		MovesEnum.Values.SCRATCH,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
	]
	squirtle._post_init()
	var wild_bp: BattlePokemon = squirtle.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_ember_animation_test_guide() -> void:
	print(">>> Test animación Ascuas (Ember): Charmander Nv.20 (Ascuas + Arañazo + Placaje) vs Squirtle Nv.20 (Ascuas + Arañazo + Placaje + Látigo).")
	print(">>> 4 chispas (BurnFrames f0) vuelan al target, algunas pasan a f1, luego animación de quemado.")
	print(">>> Desactiva use_ember_animation_test para volver a otro flag.")


func _create_tail_whip_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.TAIL_WHIP,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_tail_whip_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.TAIL_WHIP,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_tail_whip_animation_test_guide() -> void:
	print(">>> Test animación Látigo (Tail Whip): Charmander Nv.20 (Látigo + Placaje + Arañazo) vs Pidgey Nv.18 (Látigo + Tornado + Placaje).")
	print(">>> El user da 2 vueltas en círculo (sin frames).")
	print(">>> Desactiva use_tail_whip_animation_test para volver a otro flag.")


func _create_quick_attack_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.QUICK_ATTACK,
		MovesEnum.Values.TAIL_WHIP,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_quick_attack_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.QUICK_ATTACK,
		MovesEnum.Values.TAIL_WHIP,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_quick_attack_animation_test_guide() -> void:
	print(">>> Test animación Ataque Rápido (Quick Attack): Charmander Nv.20 vs Pidgey Nv.18.")
	print(">>> User: 1 vuelta + brillo; target: TackleFrames + 2 shakes.")
	print(">>> Desactiva use_quick_attack_animation_test para volver a otro flag.")


func _create_poison_ailment_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.POISON_STING,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_poison_ailment_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.GUST,
		MovesEnum.Values.SCRATCH,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_poison_ailment_animation_test_guide() -> void:
	print(">>> Test animación ailment Poison: Charmander Nv.20 (Picotazo Veneno) vs Pidgey Nv.18.")
	print(">>> Ailment forzado: al aplicar y al daño de fin de turno → tint morado + 3 shakes.")
	print(">>> Desactiva use_poison_ailment_animation_test para volver a otro flag.")


func _create_sleep_ailment_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.SING,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_sleep_ailment_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.SING,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.GUST,
		MovesEnum.Values.SCRATCH,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_sleep_ailment_animation_test_guide() -> void:
	print(">>> Test animación ailment Sleep: Charmander Nv.20 (Canto) vs Pidgey Nv.18 (Canto + Placaje + Tornado + Arañazo).")
	print(">>> Ailment forzado: al aplicar (y al ‘sigue dormido’) → 2 Z que suben/crecen/rotan.")
	print(">>> Desactiva use_sleep_ailment_animation_test para volver a otro flag.")


func _create_freeze_ailment_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.ICE_BEAM,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_freeze_ailment_animation_test_wild() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 22
	squirtle.is_wild = true
	squirtle.custom_move_ids = [
		MovesEnum.Values.ICE_BEAM,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.WATER_GUN,
	]
	squirtle._post_init()
	var wild_bp: BattlePokemon = squirtle.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_freeze_ailment_animation_test_guide() -> void:
	print(">>> Test animación ailment Freeze: Charmander Nv.20 (Rayo Hielo) vs Squirtle Nv.22 (Rayo Hielo).")
	print(">>> Ailment forzado: overlay de hielo + barrido de brillo (reflejo).")
	print(">>> Desactiva use_freeze_ailment_animation_test para volver a otro flag.")


func _create_paralysis_ailment_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.THUNDER_WAVE,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_paralysis_ailment_animation_test_wild() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 22
	squirtle.is_wild = true
	squirtle.custom_move_ids = [
		MovesEnum.Values.THUNDER_WAVE,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.WATER_GUN,
	]
	squirtle._post_init()
	var wild_bp: BattlePokemon = squirtle.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_paralysis_ailment_animation_test_guide() -> void:
	print(">>> Test animación ailment Paralysis: Charmander Nv.20 (Onda Trueno) vs Squirtle Nv.22 (Onda Trueno).")
	print(">>> Ailment forzado: temblor + chispas (ParalysisFrames) apareciendo/desapareciendo.")
	print(">>> Desactiva use_paralysis_ailment_animation_test para volver a otro flag.")


func _create_confusion_ailment_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.SUPERSONIC,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_confusion_ailment_animation_test_wild() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 22
	squirtle.is_wild = true
	squirtle.custom_move_ids = [
		MovesEnum.Values.SUPERSONIC,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.WATER_GUN,
	]
	squirtle._post_init()
	var wild_bp: BattlePokemon = squirtle.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_confusion_ailment_animation_test_guide() -> void:
	print(">>> Test animación ailment Confusion: Charmander Nv.20 (Supersónico) vs Squirtle Nv.22 (Supersónico).")
	print(">>> Ailment forzado: 5 pájaros orbitando sobre la cabeza + frames girando.")
	print(">>> Desactiva use_confusion_ailment_animation_test para volver a otro flag.")


func _create_capture_throw_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
		MovesEnum.Values.GROWL,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_capture_throw_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 5
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.GROWL,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_capture_throw_animation_test_guide() -> void:
	print(">>> Test animación captura: Charmander Nv.20 vs Pidgey Nv.5 (salvaje).")
	print(">>> Mochila con Poké Balls. Fase 1 (throw) + fase 2 (balanceos 0–3 / escape o oscurecido).")
	print(">>> Estrellas/halos aún no. Desactiva use_capture_throw_animation_test para otro flag.")


func _create_growl_animation_test_player() -> BattleParticipant:
	var charizard := Pokemon.new()
	charizard.pokemon_id = PokemonsEnum.Values.CHARIZARD as PokemonsEnum.Values
	charizard.level = 40
	charizard.is_wild = false
	charizard.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charizard._post_init()
	var lead: BattlePokemon = charizard.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_growl_animation_test_wild() -> BattleParticipant:
	var gyarados := Pokemon.new()
	gyarados.pokemon_id = PokemonsEnum.Values.GYARADOS as PokemonsEnum.Values
	gyarados.level = 40
	gyarados.is_wild = true
	gyarados.custom_move_ids = [
		MovesEnum.Values.GROWL,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	gyarados._post_init()
	var wild_bp: BattlePokemon = gyarados.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_growl_animation_test_guide() -> void:
	print(">>> Test animación Gruñido: Charizard Nv.40 (Gruñido + Placaje + Arañazo) vs Gyarados Nv.40 salvaje (Gruñido + Tornado + Placaje).")
	print(">>> Sprites grandes: comprueba Growl + pies centrados sobre la sombra.")
	print(">>> Desactiva use_growl_animation_test para volver a otro flag.")


func _create_leer_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.LEER,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_leer_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.LEER,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_leer_animation_test_guide() -> void:
	print(">>> Test animación Malicioso (Leer): Charmander Nv.20 (Malicioso + Placaje + Arañazo) vs Pidgey Nv.18 salvaje (Malicioso + Tornado + Placaje).")
	print(">>> Destello 5 frames en el user + pulso de escala; al final el target tambalea.")
	print(">>> Desactiva use_leer_animation_test para volver a otro flag.")


func _create_pound_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.POUND,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_pound_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.POUND,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_pound_animation_test_guide() -> void:
	print(">>> Test animación Destructor (Pound): Charmander Nv.20 (Destructor + Placaje + Arañazo) vs Pidgey Nv.18 salvaje (Destructor + Tornado + Placaje).")
	print(">>> Impacto TackleFrames en el target + retroceso; el user no se mueve.")
	print(">>> Desactiva use_pound_animation_test para volver a otro flag.")


func _create_sand_attack_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.SAND_ATTACK,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_sand_attack_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.SAND_ATTACK,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_sand_attack_animation_test_guide() -> void:
	print(">>> Test animación Ataque Arena: Charmander Nv.20 (Ataque Arena + Placaje + Arañazo) vs Pidgey Nv.18 salvaje (Ataque Arena + Tornado + Placaje).")
	print(">>> User retrocede y lanza 6 racimos de arena (salen uno a uno, se agrupan en el target).")
	print(">>> Desactiva use_sand_attack_animation_test para volver a otro flag.")


func _create_bite_animation_test_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 20
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.BITE,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	charmander._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_bite_animation_test_wild() -> BattleParticipant:
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 18
	pidgey.is_wild = true
	pidgey.custom_move_ids = [
		MovesEnum.Values.BITE,
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pidgey._post_init()
	var wild_bp: BattlePokemon = pidgey.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


func _print_bite_animation_test_guide() -> void:
	print(">>> Test animación Mordisco (Bite): Charmander Nv.20 (Mordisco + Placaje + Arañazo) vs Pidgey Nv.18 salvaje (Mordisco + Tornado + Placaje).")
	print(">>> Mandíbulas arriba/abajo del target que se cierran; el target tambalea al morder.")
	print(">>> Desactiva use_bite_animation_test para volver a otro flag.")


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
	var ia := BattleIA_TrainerEasy.new()
	var lead: BattlePokemon = _create_forced_switch_test_player_lead(PokemonsEnum.Values.RATTATA).to_battle_pokemon()
	var bench: BattlePokemon = _create_forced_switch_test_player_lead(PokemonsEnum.Values.BULBASAUR).to_battle_pokemon()
	lead.setIA(ia)
	bench.setIA(ia)
	lead.controllable = false
	bench.controllable = false
	var participant := BattleParticipant.new([lead, bench])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador"
	return participant


func _print_forced_switch_trainer_guide() -> void:
	print(">>> Test cambio forzado (rival): Charmander + Squirtle (Nv.28) vs Rattata + Bulbasaur (Nv.8, entrenador).")
	print(">>> Debilita al Rattata rival → prompt de cambio opcional + envío automático de Bulbasaur.")


# =============================================================================
# Debug IA tipada (PBI 705 / 342)
# =============================================================================

func _print_battle_ia_typing_test_guide() -> void:
	print(">>> === Test IA tipada (PBI 705 / 342) ===")
	print(">>> Desactiva use_field_effects_integration_test y el resto de flags; deja solo use_battle_ia_typing_test=true.")
	match battle_ia_test_scenario:
		0:
			print(">>> Escenario TYPE ADVANTAGE:")
			print(">>>   Jugador: Charmander (Fuego) + Bulbasaur (Planta) — puedes cambiar")
			print(">>>   Rival IA TrainerEasy: Squirtle — Water Gun / Tackle / Tail Whip / Bite")
			print(">>>   vs Charmander: prioriza Pistola Agua (2x).")
			print(">>>   Cambia a Bulbasaur: Agua pasa a 0.5x → debería usar Placaje o Mordisco (1x), no Agua.")
		1:
			print(">>> Escenario AVOID IMMUNITY:")
			print(">>>   Jugador: Pidgey (Volador) — Gust / Tackle")
			print(">>>   Rival IA TrainerEasy: Sandshrew — Earthquake / Dig / Tackle / Scratch")
			print(">>>   Esperado: NO elige Terremoto/Excavar (0x); usa Placaje o Arañazo.")
		2:
			print(">>> Escenario ALL IMMUNE → random helper:")
			print(">>>   Jugador: Gastly (Fantasma) — Lick / Night Shade")
			print(">>>   Rival IA TrainerEasy: Rattata — solo Tackle / Scratch (ambos 0x)")
			print(">>>   Esperado: sigue atacando (random legal), sin crash ni target_handler.")
		3:
			print(">>> Escenario WILD BASIC:")
			print(">>>   Jugador: Squirtle — Water Gun / Tackle")
			print(">>>   Salvaje WildBasic: Pidgey — Gust / Tackle / Quick Attack")
			print(">>>   Esperado: ataques legales al azar (sin lógica de tipos).")
		_:
			print(">>> Escenario desconocido: %d" % battle_ia_test_scenario)
	print(">>> Probe de fallback: al inicio se asigna WildBasic a un trainer → warning + TrainerEasy.")


## Comprueba en consola el fallback tipado trainer←wild (PBI 705).
func _run_battle_ia_fallback_probe() -> void:
	var probe := BattleParticipant.new()
	probe.is_trainer = true
	probe.name = "ProbeTrainer"
	probe.set_ai_controller(BattleIA_WildBasic.new(), "IA_PROBE")
	var resolved := probe.ai_controller
	var label := resolved.difficulty_name if resolved else "<null>"
	print(">>> Probe fallback: IA tras asignar WildBasic a trainer = '%s' (esperado TrainerEasy)" % label)
	if not (resolved is BattleIA_TrainerEasy):
		push_error("TestBattle IA probe: se esperaba BattleIA_TrainerEasy tras fallback, recibido: %s" % label)


func battleIaTypingTestBattle() -> void:
	var player_participant: BattleParticipant
	var enemy_participant: BattleParticipant
	var rules: BattleRules
	match battle_ia_test_scenario:
		0:
			player_participant = _create_battle_ia_type_advantage_player()
			enemy_participant = _create_battle_ia_type_advantage_trainer()
			rules = BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
		1:
			player_participant = _create_battle_ia_avoid_immunity_player()
			enemy_participant = _create_battle_ia_avoid_immunity_trainer()
			rules = BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
		2:
			player_participant = _create_battle_ia_all_immune_player()
			enemy_participant = _create_battle_ia_all_immune_trainer()
			rules = BattleRules.new(BattleRules.BattleTypes.TRAINER, BattleRules.BattleModes.SINGLE)
		3:
			player_participant = _create_battle_ia_wild_basic_player()
			enemy_participant = _create_battle_ia_wild_basic_enemy()
			rules = BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
		_:
			push_error("TestBattle: battle_ia_test_scenario inválido (%d)" % battle_ia_test_scenario)
			return
	var participants: Array[BattleParticipant] = [player_participant, enemy_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla IA tipada (escenario %d) terminada. Ganador: %s" % [battle_ia_test_scenario, winner])


func _create_battle_ia_type_advantage_player() -> BattleParticipant:
	var charmander := Pokemon.new()
	charmander.pokemon_id = PokemonsEnum.Values.CHARMANDER as PokemonsEnum.Values
	charmander.level = 30
	charmander.is_wild = false
	charmander.custom_move_ids = [
		MovesEnum.Values.EMBER,
		MovesEnum.Values.SCRATCH,
		MovesEnum.Values.GROWL,
	]
	charmander._post_init()
	var bulbasaur := Pokemon.new()
	bulbasaur.pokemon_id = PokemonsEnum.Values.BULBASAUR as PokemonsEnum.Values
	bulbasaur.level = 30
	bulbasaur.is_wild = false
	bulbasaur.custom_move_ids = [
		MovesEnum.Values.VINE_WHIP,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.GROWL,
	]
	bulbasaur._post_init()
	var lead: BattlePokemon = charmander.to_battle_pokemon()
	var bench: BattlePokemon = bulbasaur.to_battle_pokemon()
	lead.controllable = true
	bench.controllable = true
	var participant := BattleParticipant.new([lead, bench])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_battle_ia_type_advantage_trainer() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.WATER_GUN,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.TAIL_WHIP,
		MovesEnum.Values.BITE,
	]
	pkmn._post_init()
	var lead: BattlePokemon = pkmn.to_battle_pokemon()
	lead.setIA(ia)
	lead.controllable = false
	var participant := BattleParticipant.new([lead])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador Easy"
	return participant


func _create_battle_ia_avoid_immunity_player() -> BattleParticipant:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = false
	pkmn.custom_move_ids = [MovesEnum.Values.GUST, MovesEnum.Values.TACKLE]
	pkmn._post_init()
	var lead: BattlePokemon = pkmn.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_battle_ia_avoid_immunity_trainer() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.SANDSHREW as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.EARTHQUAKE,
		MovesEnum.Values.DIG,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.SCRATCH,
	]
	pkmn._post_init()
	var lead: BattlePokemon = pkmn.to_battle_pokemon()
	lead.setIA(ia)
	lead.controllable = false
	var participant := BattleParticipant.new([lead])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador Easy"
	return participant


func _create_battle_ia_all_immune_player() -> BattleParticipant:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.GASTLY as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = false
	pkmn.custom_move_ids = [MovesEnum.Values.LICK, MovesEnum.Values.NIGHT_SHADE]
	pkmn._post_init()
	var lead: BattlePokemon = pkmn.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_battle_ia_all_immune_trainer() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = false
	pkmn.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.SCRATCH]
	pkmn._post_init()
	var lead: BattlePokemon = pkmn.to_battle_pokemon()
	lead.setIA(ia)
	lead.controllable = false
	var participant := BattleParticipant.new([lead])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador Easy"
	return participant


func _create_battle_ia_wild_basic_player() -> BattleParticipant:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	pkmn.level = 25
	pkmn.is_wild = false
	pkmn.custom_move_ids = [MovesEnum.Values.WATER_GUN, MovesEnum.Values.TACKLE]
	pkmn._post_init()
	var lead: BattlePokemon = pkmn.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_battle_ia_wild_basic_enemy() -> BattleParticipant:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 25
	pkmn.is_wild = true
	pkmn.custom_move_ids = [
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.QUICK_ATTACK,
	]
	pkmn._post_init()
	var wild_bp: BattlePokemon = pkmn.to_battle_pokemon()
	wild_bp.is_wild = true
	return BattleParticipantWild.new([wild_bp])


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


func _setup_rain_animation_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_rain_animation_test_player_instance())
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_rain_animation_test_enemy_instance())


func _create_rain_animation_test_player_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	pkmn.level = 50
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.RAIN_DANCE,
		MovesEnum.Values.WATER_GUN,
		MovesEnum.Values.TACKLE,
		MovesEnum.Values.WITHDRAW,
	]
	pkmn._post_init()
	return pkmn


func _create_rain_animation_test_enemy_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 30
	pkmn.is_wild = true
	pkmn.custom_move_ids = [
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pkmn._post_init()
	return pkmn


func _print_rain_weather_animation_test_guide() -> void:
	print(">>> Test animación lluvia: Squirtle vs Pidgey salvaje.")
	print(">>> Al iniciar: oscurecimiento + gotas (clima lluvia sembrado). HPBar/MessageBox sin oscurecer.")
	print(">>> También puedes usar Danza Lluvia en combate (misma animación).")
	print(">>> Desactiva use_rain_weather_animation_test para otro flag.")


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


func _setup_tailwind_test_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(_create_tailwind_test_player_instance())
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_tailwind_test_enemy_instance())


func _create_tailwind_test_player_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.SLOWPOKE as PokemonsEnum.Values
	pkmn.level = 50
	pkmn.is_wild = false
	pkmn.custom_move_ids = [
		MovesEnum.Values.TAILWIND,
		MovesEnum.Values.TACKLE,
	]
	pkmn._post_init()
	return pkmn


func _create_tailwind_test_enemy_instance() -> Pokemon:
	var pkmn := Pokemon.new()
	pkmn.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pkmn.level = 24
	pkmn.is_wild = true
	pkmn.custom_move_ids = [
		MovesEnum.Values.GUST,
		MovesEnum.Values.TACKLE,
	]
	pkmn._post_init()
	return pkmn


func _print_tailwind_test_guide() -> void:
	print(">>> Combate Viento Afín: Slowpoke Nv.50 (Viento Afín + Placaje) vs Pidgey Nv.24 (Tornado + Placaje).")
	print(">>>   1) Turno 1 — Pidgey más rápido actúa primero (~39 vs ~20); Slowpoke usa Viento Afín.")
	print(">>>   2) Turnos 2-4 — Slowpoke debería actuar primero (~40 vs ~39 en log de velocidad efectiva).")
	print(">>>   3) Repetir Viento Afín activo → «¡Pero falló!»")
	print(">>>   4) Tras 3 turnos de combate: «¡Viento Afín de tu equipo amainó!» → Pidgey vuelve a ir primero.")


func _create_spikes_test_player_participant() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 40
	squirtle.is_wild = false
	squirtle.custom_move_ids = [
		MovesEnum.Values.SPIKES,
		MovesEnum.Values.WATER_GUN,
		MovesEnum.Values.TACKLE,
	]
	squirtle._post_init()
	var lead: BattlePokemon = squirtle.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_spikes_test_trainer_participant() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var rattata := Pokemon.new()
	rattata.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	rattata.level = 12
	rattata.is_wild = false
	rattata.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.TAIL_WHIP]
	rattata._post_init()
	var bulbasaur := Pokemon.new()
	bulbasaur.pokemon_id = PokemonsEnum.Values.BULBASAUR as PokemonsEnum.Values
	bulbasaur.level = 12
	bulbasaur.is_wild = false
	bulbasaur.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.GROWL]
	bulbasaur._post_init()
	var pidgey := Pokemon.new()
	pidgey.pokemon_id = PokemonsEnum.Values.PIDGEY as PokemonsEnum.Values
	pidgey.level = 12
	pidgey.is_wild = false
	pidgey.custom_move_ids = [MovesEnum.Values.GUST, MovesEnum.Values.TACKLE]
	pidgey._post_init()
	var lead: BattlePokemon = rattata.to_battle_pokemon()
	var mid: BattlePokemon = bulbasaur.to_battle_pokemon()
	var flyer: BattlePokemon = pidgey.to_battle_pokemon()
	lead.setIA(ia)
	mid.setIA(ia)
	flyer.setIA(ia)
	lead.controllable = false
	mid.controllable = false
	flyer.controllable = false
	var participant := BattleParticipant.new([lead, mid, flyer])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador"
	return participant


func _print_spikes_test_guide() -> void:
	print(">>> Combate Púas: Squirtle Nv.40 (Púas + Pistola Agua + Placaje) vs Rattata + Bulbasaur + Pidgey (Nv.12, entrenador).")
	print(">>>   1) Usa Púas 1–3 veces → mensaje de colocación; 4ª vez → «¡Pero falló!»")
	print(">>>   2) Debilita a Rattata → entra Bulbasaur y recibe daño de entrada (1/8 · 1/6 · 1/4 según capas).")
	print(">>>   3) Debilita a Bulbasaur → entra Pidgey (Volador) → NO debe recibir daño de Púas.")
	print(">>>   4) Comprueba en log de efectos activos: SpikesFieldEffect con layers 1–3 en Enemy.")


func _create_toxic_spikes_test_player_participant() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 40
	squirtle.is_wild = false
	squirtle.custom_move_ids = [
		MovesEnum.Values.TOXIC_SPIKES,
		MovesEnum.Values.WATER_GUN,
		MovesEnum.Values.TACKLE,
	]
	squirtle._post_init()
	var lead: BattlePokemon = squirtle.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_toxic_spikes_test_trainer_participant() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var rattata := Pokemon.new()
	rattata.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	rattata.level = 12
	rattata.is_wild = false
	rattata.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.TAIL_WHIP]
	rattata._post_init()
	var sandshrew := Pokemon.new()
	sandshrew.pokemon_id = PokemonsEnum.Values.SANDSHREW as PokemonsEnum.Values
	sandshrew.level = 12
	sandshrew.is_wild = false
	sandshrew.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.SAND_ATTACK]
	sandshrew._post_init()
	var ekans := Pokemon.new()
	ekans.pokemon_id = PokemonsEnum.Values.EKANS as PokemonsEnum.Values
	ekans.level = 12
	ekans.is_wild = false
	ekans.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.WRAP]
	ekans._post_init()
	var diglett := Pokemon.new()
	diglett.pokemon_id = PokemonsEnum.Values.DIGLETT as PokemonsEnum.Values
	diglett.level = 12
	diglett.is_wild = false
	diglett.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.SCRATCH]
	diglett._post_init()
	var lead: BattlePokemon = rattata.to_battle_pokemon()
	var grounded_a: BattlePokemon = sandshrew.to_battle_pokemon()
	var poison: BattlePokemon = ekans.to_battle_pokemon()
	var grounded_b: BattlePokemon = diglett.to_battle_pokemon()
	for bp in [lead, grounded_a, poison, grounded_b]:
		bp.setIA(ia)
		bp.controllable = false
	var participant := BattleParticipant.new([lead, grounded_a, poison, grounded_b])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador"
	return participant


func _print_toxic_spikes_test_guide() -> void:
	print(">>> Combate Púas Tóxicas: Squirtle Nv.40 vs Rattata + Sandshrew + Ekans + Diglett (Nv.12, todos grounded).")
	print(">>>   1) Usa Púas Tóxicas 1–2 veces → colocación; 3ª → «¡Pero falló!»")
	print(">>>   2) Con 1 capa: KO Rattata → «fue envenenado!» + residual 1/8 al fin de turno.")
	print(">>>      Con 2 capas: KO Rattata → «fue gravemente envenenado!» + residual N/16 creciente.")
	print(">>>   3) Sandshrew (Ground) entra → recibe veneno/tóxico según capas.")
	print(">>>   4) Ekans (Veneno grounded) → absorbe («púas tóxicas desaparecieron…»).")
	print(">>>   5) Vuelve a colocar; Diglett (Ground) entra → recibe veneno otra vez.")


func _create_stealth_rock_test_player_participant() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 40
	squirtle.is_wild = false
	squirtle.custom_move_ids = [
		MovesEnum.Values.STEALTH_ROCK,
		MovesEnum.Values.WATER_GUN,
		MovesEnum.Values.TACKLE,
	]
	squirtle._post_init()
	var lead: BattlePokemon = squirtle.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_stealth_rock_test_trainer_participant() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var rattata := Pokemon.new()
	rattata.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	rattata.level = 12
	rattata.is_wild = false
	rattata.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.TAIL_WHIP]
	rattata._post_init()
	var machop := Pokemon.new()
	machop.pokemon_id = PokemonsEnum.Values.MACHOP as PokemonsEnum.Values
	machop.level = 12
	machop.is_wild = false
	machop.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.LOW_KICK]
	machop._post_init()
	var charizard := Pokemon.new()
	charizard.pokemon_id = PokemonsEnum.Values.CHARIZARD as PokemonsEnum.Values
	charizard.level = 12
	charizard.is_wild = false
	charizard.custom_move_ids = [MovesEnum.Values.SCRATCH, MovesEnum.Values.EMBER]
	charizard._post_init()
	var lead: BattlePokemon = rattata.to_battle_pokemon()
	var resist: BattlePokemon = machop.to_battle_pokemon()
	var weak: BattlePokemon = charizard.to_battle_pokemon()
	for bp in [lead, resist, weak]:
		bp.setIA(ia)
		bp.controllable = false
	var participant := BattleParticipant.new([lead, resist, weak])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador"
	return participant


func _print_stealth_rock_test_guide() -> void:
	print(">>> Combate Trampa Rocas: Squirtle Nv.40 vs Rattata + Machop + Charizard (Nv.12).")
	print(">>>   1) Usa Trampa Rocas → «¡Trampa Rocas rodea al equipo rival!»; 2ª vez → «¡Pero falló!»")
	print(">>>   2) KO Rattata (Normal, ×1) → daño ~1/8 + «piedras puntiagudas hirieron…»")
	print(">>>   3) Machop (Lucha, ×0.5) → daño ~1/16")
	print(">>>   4) Charizard (Fuego/Volador, ×4) → daño ~1/2 (Volador NO inmuniza)")


func _create_field_effects_integration_player_participant() -> BattleParticipant:
	var squirtle := Pokemon.new()
	squirtle.pokemon_id = PokemonsEnum.Values.SQUIRTLE as PokemonsEnum.Values
	squirtle.level = 40
	squirtle.is_wild = false
	squirtle.custom_move_ids = [
		MovesEnum.Values.SPIKES,
		MovesEnum.Values.TOXIC_SPIKES,
		MovesEnum.Values.STEALTH_ROCK,
		MovesEnum.Values.WATER_GUN,
	]
	squirtle._post_init()
	var lead: BattlePokemon = squirtle.to_battle_pokemon()
	lead.controllable = true
	var participant := BattleParticipant.new([lead])
	participant.is_player = true
	participant.name = "Jugador"
	return participant


func _create_field_effects_integration_trainer_participant() -> BattleParticipant:
	var ia := BattleIA_TrainerEasy.new()
	var rattata := Pokemon.new()
	rattata.pokemon_id = PokemonsEnum.Values.RATTATA as PokemonsEnum.Values
	rattata.level = 12
	rattata.is_wild = false
	rattata.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.TAIL_WHIP]
	rattata._post_init()
	var bulbasaur := Pokemon.new()
	bulbasaur.pokemon_id = PokemonsEnum.Values.BULBASAUR as PokemonsEnum.Values
	bulbasaur.level = 12
	bulbasaur.is_wild = false
	bulbasaur.custom_move_ids = [MovesEnum.Values.TACKLE, MovesEnum.Values.GROWL]
	bulbasaur._post_init()
	var charizard := Pokemon.new()
	charizard.pokemon_id = PokemonsEnum.Values.CHARIZARD as PokemonsEnum.Values
	charizard.level = 12
	charizard.is_wild = false
	charizard.custom_move_ids = [MovesEnum.Values.SCRATCH, MovesEnum.Values.EMBER]
	charizard._post_init()
	var lead: BattlePokemon = rattata.to_battle_pokemon()
	var grounded: BattlePokemon = bulbasaur.to_battle_pokemon()
	var flyer: BattlePokemon = charizard.to_battle_pokemon()
	for bp in [lead, grounded, flyer]:
		bp.setIA(ia)
		bp.controllable = false
	var participant := BattleParticipant.new([lead, grounded, flyer])
	participant.is_trainer = true
	participant.ai_controller = ia
	participant.name = "Entrenador"
	return participant


func _print_field_effects_integration_test_guide() -> void:
	print(">>> Integración field effects (PBI 704): Squirtle Nv.40 vs Rattata + Bulbasaur + Charizard (Nv.12).")
	print(">>>   Movimientos: Púas + Púas Tóxicas + Trampa Rocas + Pistola Agua.")
	print(">>>   Reflejo se siembra al inicio en tu lado (5 turnos) para coexistir con hazards.")
	print(">>>   1) Coloca los 3 hazards (orden libre de colocación).")
	print(">>>   2) Reaplica Trampa Rocas → fail; Púas/Púas Tóxicas → +capa hasta tope.")
	print(">>>   3) KO Rattata → Bulbasaur: mensajes Stealth Rock → Spikes → Toxic Spikes.")
	print(">>>   4) KO Bulbasaur → Charizard: Spikes/Toxic NO; Stealth Rock sí (×4); faint limpio si KO.")
	print(">>>   5) Reflejo no rompe el turno; caduca con mensaje end a los 5 turnos.")
	print(">>>   Doc: Docs/battle/field-effects.md")


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
	var ia := BattleIA_TrainerEasy.new()
	for i in num_pokemon:
		var bp := _create_random_pokemon(false)
		bp.setIA(ia)
		trainer_team.append(bp)
	var participant := BattleParticipant.new(trainer_team)
	participant.is_trainer = true
	participant.ai_controller = ia
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
	#var enemyBattler : Battler = Battler.new().create(CONST.BATTLER_TYPES.WILD_POKEMON, [pkmn], BattleIA_WildBasic.new())
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
