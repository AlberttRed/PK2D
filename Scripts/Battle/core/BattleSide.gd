extends RefCounted
class_name BattleSide

enum Types {
	NONE,
	PLAYER,
	ENEMY
}

const MAX_PARTY_SIZE := 6

var type: Types  # PLAYER / ENEMY / etc.
var participants: Array[BattleParticipant] = []
var battle_spots: Array[BattleSpot]
var opponent_side: BattleSide = null

var isWild: bool = false
var pokemonParty : Array[BattlePokemon]
var escapeAttempts:int #Player attemps to exit the battle. If a Move is selected, the attemps counter will restart
var escapedBattle:bool

func _init(_type: Types) -> void:
	self.type = _type
	self.pokemonParty = []
	self.escapeAttempts = 0
	
func add_participant(participant: BattleParticipant) -> void:
	if participants.has(participant):
		push_warning("Participant ya está en este BattleSide.")
		return

	if participant.side != null and participant.side != self:
		push_error("Participant ya pertenece a otro BattleSide.")
		return

	participant.side = self
	participants.append(participant)
	
func get_active_pokemons() -> Array[BattlePokemon]:
	var actives:Array[BattlePokemon] = []
	for p:BattleParticipant in participants:
		actives += p.get_active_pokemons()
	return actives

func load_party():
	pokemonParty.clear()
	var num_part = participants.size()
	var num_pk_per_participant: int = floor(MAX_PARTY_SIZE / num_part)
	var total_added := 0

	for part:BattleParticipant in participants:
		var added_for_this_participant := 0
		for pk:BattlePokemon in part.pokemon_team:
			if added_for_this_participant < num_pk_per_participant and total_added < 6:
				pk.inBattleParty = true
				self.pokemonParty.append(pk)
				pk.side = self
				added_for_this_participant += 1
				total_added += 1
			if total_added >= 6:
				break

func is_controllable() -> bool:
	return participants.any(func(p): return p.is_player)
	
# Devuelve el número máximo de Pokémon activos por side según el modo
func get_max_active_per_side(rules: BattleRules) -> int:
	match rules.mode:
		BattleRules.BattleModes.SINGLE:
			return 1
		BattleRules.BattleModes.DOUBLE:
			return 2
		BattleRules.BattleModes.TRIPLE:
			return 3
		_:
			return 1
			
# Distribuye los Pokémon activos entre los participantes
func get_max_active_per_participant(rules: BattleRules) -> Dictionary:
	var total_per_side:int = get_max_active_per_side(rules)
	var num_participants:int = participants.size()

	var result := {}
	if num_participants == 0:
		return result

	var base:int = floori(total_per_side / num_participants)
	var remainder:int = total_per_side % num_participants

	for i in participants.size():
		var count = base
		if i < remainder:
			count += 1  # repartir el sobrante equitativamente
		result[participants[i]] = count
	return result
	
# Reparte los Pokémon activos entre los participantes.
# Cada participante puede usar solo sus Pokémon, y solo si están en el pokemonParty.
# Se asigna como 'inBattle' a los seleccionados según el modo (1vs1, 2vs2, etc.)
func assign_active_pokemons(rules: BattleRules) -> void:
	var max_per_participant := get_max_active_per_participant(rules)
	var allowed_pokemon := self.pokemonParty

	# Reset: marcar todos como fuera de combate
	for pk in allowed_pokemon:
		pk.in_battle = false

	# Asignación
	for p in participants:
		var assigned := 0
		var max_allowed:int = max_per_participant.get(p, 0)
		
		for pk in p.pokemon_team:
			if pk in allowed_pokemon and not pk.fainted and assigned < max_allowed:
				pk.controllable = p.is_player
				pk.in_battle = true
				assigned += 1
				
# Prepara el BattleSide para el combate:
# - Carga hasta 6 Pokémon repartidos entre los participantes
# - Asigna cuáles comenzarán el combate en función del modo de batalla (SINGLE, DOUBLE, etc.)
func prepare_for_battle(rules: BattleRules) -> void:
	assert(!participants.is_empty(), "BattleSide sin participantes")
	load_party()
	assign_active_pokemons(rules)

# Devuelve los nombres de los entrenadores del side
func get_trainer_names() -> Array[String]:
	var names: Array[String] = []
	for p in participants:
			names.append(p.name)
	return names

func _to_string() -> String:
	if type == Types.PLAYER:
		return "Player"
	elif type == Types.ENEMY:
		return "Enemy"
	else:
		return "None"
