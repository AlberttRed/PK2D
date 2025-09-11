extends Node
class_name Battler

@export var trainer_id : int
@export var type : CONST.BATTLER_TYPES
@export var battleIA : Resource = null
@export var Name: String
@export var battle_front_sprite: Texture
@export var battle_back_sprite: Texture = null
@export_multiline var before_battle_message: String
@export_multiline var init_battle_message: String
@export_multiline var end_battle_message: String
@export var is_defeated: bool = false
@export var double_battle: bool = false
@export var is_playable: bool = false
@export var partner: NodePath = "" #Aqui hi lligarem l'NPC que fagi de parella a lhora del combat. A PARTIR DE L NPC AGAFAREM EL NODO TRAINER I ELS PKMN

var tilesVisibility

@onready var party : Array[PokemonInstance] = [] #: Array = get_children() # setget ,get_party

func create(_type : CONST.BATTLER_TYPES, _party : Array, _IA,  _name : String = "", _battle_front_sprite : Texture = null, _battle_back_sprite : Texture = null, _before_battle_message : String = "", _init_battle_message: String = "", _end_battle_message: String = "", _is_defeated : bool = false, _double_battle: bool = false, _is_playable: bool = false, _partner : NodePath = NodePath("")):
	type = _type
	for p:PokemonInstance in _party:
		addPokemonToParty(p)
	#party = _party
	battleIA = _IA
	Name = _name
	battle_front_sprite = _battle_front_sprite
	battle_back_sprite = _battle_back_sprite
	before_battle_message = _before_battle_message
	init_battle_message = _init_battle_message
	end_battle_message = _end_battle_message
	is_defeated = _is_defeated
	double_battle = _double_battle
	is_playable = _is_playable
	partner = _partner
	
	
	return self
#	for p in get_children():
#		#print("fora: " + p.nickname + str(p.level))
#		party.push_back(DB.pokemons[p.pkm_id].new_pokemon(p))
	#pass
	
func _ready():
	if get_children().size() != 0:
		party = []
		for p:PokemonInstance in get_children():
			addPokemonToParty(p)

func addPokemonToParty(p:PokemonInstance):
	if type == CONST.BATTLER_TYPES.TRAINER:
		p.trainer = self
	party.push_back(p)
	
func is_type(type): return type == "Trainer" or self.is_type(type)
func    get_type(): return "Trainer"

func has_pokemon(pk):
	for p:PokemonInstance in party:
		if p == pk:
			return true
	return false
	
	

	
func print_pokemon_team():
	for p:PokemonInstance in get_children():
		p.print_pokemon()
		print(" ")
		p.print_moves()
		print(" ")


func to_battle_participant() -> BattleParticipant:
	var p := BattleParticipant.new()
	p.trainer_id = trainer_id
	p.name = name if name != null else ""
	p.is_player = is_playable  # o false si es un NPC
	p.ai_controller = battleIA
	#p.sprite_path = null  # si usás sprites por entrenador
	p.is_trainer = (type != CONST.BATTLER_TYPES.WILD_POKEMON)
	p.pokemon_team = []
	
	for pok:PokemonInstance in party:
		var battle_pokemon := pok.to_battle_pokemon() #BattlePokemon_Refactor.new(pok, battleIA)
		battle_pokemon.controllable = is_playable
		battle_pokemon.participant = p
		p.add_pokemon(battle_pokemon)
	return p
	
#func initPokemonTeam():
#	for p in get_children():
#		p.create()

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass
