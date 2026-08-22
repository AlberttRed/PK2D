extends RefCounted

class_name BattleParticipant

var trainer_id: int = -1  # -1 o algún valor especial para salvajes
var trainer_resource_id: String = ""  # Identificador único del trainer (nombre del .res sin extensión)
var is_player: bool = false
## Si true, combate en el lado del jugador aunque no sea humano (aliado con IA).
## `is_player` siempre implica lado jugador.
var joins_player_side: bool = false
var name: String = "":
	get:
		return name if name != null else ""
var _ai_controller: BattleIA = null  # null si es jugador
## Preferir set_ai_controller() para validar compatibilidad trainer/wild.
var ai_controller: BattleIA:
	get:
		return _ai_controller
	set(value):
		set_ai_controller(value)
var sprite_path: String = ""  # Opcional, si usás esto para mostrar el entrenador
var is_trainer: bool = true  # Nuevo flag, por compatibilidad futura
var side: BattleSide = null  # Se asigna desde el add_participant()

## Mensajes del entrenador (para mostrar al final del combate)
var intro_message: String = ""
var defeat_message: String = ""
var victory_message: String = ""

## Mochila de combate. `null` + `is_player` → `GameStateService.get_bag()`.
## Entrenador/aliado con ítems propios: asignar con `set_bag_from_item_ids` o `bag = Bag.new()`.
var bag: Bag = null

# Internal storage for the participant's battle team.
# DO NOT modify this directly. Use add_pokemon or add_pokemon_team.
var _pokemon_team: Array[BattlePokemon] = []

# Public property with validation on assignment.
var pokemon_team: Array[BattlePokemon]:
	get:
		return _pokemon_team
	set(value):
		_pokemon_team.clear()
		for pk in value:
			add_pokemon(pk)

func _init(_pokemon_team: Array[BattlePokemon] = []):
	self.add_pokemon_team(_pokemon_team)


## ¿Pertenece al lado del jugador (humano o aliado IA)?
func belongs_to_player_side() -> bool:
	return is_player or joins_player_side


## Mochila efectiva en combate: propia, o la del save si es jugador humano.
func get_battle_bag() -> Bag:
	if bag != null:
		return bag
	if is_player:
		return GameStateService.get_bag() as Bag
	return null


## Rellena `bag` desde una lista de item_id (p. ej. TrainerData.battle_items).
## IDs repetidos se apilan. Sobrescribe cualquier bag previa.
func set_bag_from_item_ids(item_ids: Array) -> void:
	bag = Bag.new()
	for item_id_variant in item_ids:
		var item_id := int(item_id_variant)
		if item_id > 0:
			bag.add_item(item_id, 1)


## Asigna IA con validación runtime según tipo de participante.
## Trainer NPC → TrainerBattleIA (fallback BattleIA_TrainerEasy).
## Wild → WildBattleIA (fallback BattleIA_WildBasic).
## Jugador → siempre null.
func set_ai_controller(ai: BattleIA, context: String = "") -> void:
	if is_player:
		_ai_controller = null
		return
	var ctx := context
	if ctx.is_empty():
		ctx = name if not name.is_empty() else ("trainer" if is_trainer else "wild")
	if is_trainer:
		_ai_controller = TrainerBattleIA.resolve(ai, ctx)
	else:
		_ai_controller = WildBattleIA.resolve(ai, ctx)


# Adds a single BattlePokemon to the participant's team.
func add_pokemon(pokemon: BattlePokemon) -> void:
	if pokemon.ai_controller == null:
		pokemon.setIA(ai_controller)
	pokemon.participant = self
	_pokemon_team.append(pokemon)

# Adds multiple BattlePokemon at once.
func add_pokemon_team(pokemon_list: Array[BattlePokemon]) -> void:
	for pk in pokemon_list:
		add_pokemon(pk)

func decide_action_for(pokemon: BattlePokemon) -> BattleChoice:
	if ai_controller:
		return await ai_controller.decide_action(pokemon)
	return await pokemon.decide_random_action()  # fallback aleatorio


func decide_forced_switch_for(
	battle_side: BattleSide,
	spot: BattleSpot,
	fainted: BattlePokemon
) -> BattleSwitchChoice:
	if ai_controller:
		return ai_controller.decide_forced_switch(battle_side, spot, fainted)
	return BattleIA.new().build_first_available_forced_switch(battle_side, spot, fainted)


func get_active_pokemons() -> Array[BattlePokemon]:
	return pokemon_team.filter(func(pk): return pk.in_battle and not pk.fainted)
