extends RefCounted

class_name BattleParticipant

var trainer_id: int = -1  # -1 o algún valor especial para salvajes
var is_player: bool = false
var name: String = "":
	get:
		return name if name != null else ""
var ai_controller: BattleIA = null  # null si es jugador
var sprite_path: String = ""  # Opcional, si usás esto para mostrar el entrenador
var is_trainer: bool = true  # Nuevo flag, por compatibilidad futura
var side: BattleSide = null  # Se asigna desde el add_participant()

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
#func _init(trainer_id: int, is_player := false, name := "", team := []):
	#self.trainer_id = trainer_id
	#self.is_player = is_player
	#self.name = name
	#self.pokemon_team = team


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


func get_active_pokemons() -> Array[BattlePokemon]:
	return pokemon_team.filter(func(pk): return pk.in_battle and not pk.fainted)
