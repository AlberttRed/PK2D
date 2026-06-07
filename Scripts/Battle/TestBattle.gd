extends Node2D

const _DISPLAY_MANAGER_SCENE := preload("res://Managers/DisplayManager.tscn")

@export_group("Equipos de prueba")
## Si true, lanza un 1vs1 salvaje fijo: Growlithe (Intimidación) + Ekans en banca vs Gastly Nv.20.
@export var use_fixed_rattata_vs_gastly: bool = true

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
	if use_fixed_rattata_vs_gastly:
		_setup_fixed_rattata_gastly_parties()
	else:
		_setup_test_battler_parties()
	_seed_test_capture_items()
	if use_fixed_rattata_vs_gastly:
		print(">>> Combate fijo: Growlithe (Intimidación) + Ekans (Intimidación) vs Gastly Nv.20")
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

func wildFixedRattataGastlyBattle() -> void:
	var player_participant: BattleParticipant = _create_fixed_player_participant()
	var wild_participant: BattleParticipant = _create_fixed_wild_participant(
		PokemonsEnum.Values.GASTLY, 20
	)
	var rules := BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)
	var participants: Array[BattleParticipant] = [player_participant, wild_participant]
	var winner = await _start_test_battle(participants, rules)
	print(">>> Batalla Growlithe/Ekans vs Gastly terminada. Ganador: %s" % winner)


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
	return await DisplayManager.start_battle(participants, rules)


## Party en escena para `player` / `wildPokemons` (combate fijo por battler opcional).
func _setup_fixed_rattata_gastly_parties() -> void:
	if player != null:
		player.party.clear()
		player.add_pokemon_to_party(
			_create_pokemon_instance(PokemonsEnum.Values.GROWLITHE, 20, false, AbilitiesEnum.Values.INTIMIDATE)
		)
		player.add_pokemon_to_party(
			_create_pokemon_instance(PokemonsEnum.Values.EKANS, 20, false, AbilitiesEnum.Values.INTIMIDATE)
		)
		player.add_pokemon_to_party(_create_pokemon_instance(PokemonsEnum.Values.RATTATA, 20, false))
	if wildPokemons != null:
		wildPokemons.party.clear()
		wildPokemons.add_pokemon_to_party(_create_pokemon_instance(PokemonsEnum.Values.GASTLY, 20, true))


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
	bag.add_item(17, 10)  # Poción
	print("TestBattle: ítems de prueba en mochila (bolas x10, Poción x10).")


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
