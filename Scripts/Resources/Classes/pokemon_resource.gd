@icon("res://pkmn_icon.png")
extends Resource

class_name Pokemon


@export var id:int = 0
@export var internal_name:String = ""
@export var Name:String = ""

#@export_enum("None, Normal, Fighting, Flying, Poison, Ground, Rock, Bug, Ghost, Steel, Fire, Water, Grass, Electric, Psychic, Ice, Dragon, Dark, Fairy") var type_a
#@export_enum("None, Normal, Fighting, Flying, Poison, Ground, Rock, Bug, Ghost, Steel, Fire, Water, Grass, Electric, Psychic, Ice, Dragon, Dark, Fairy") var type_b

@export var type_a : Resource = null
@export var type_b : Resource = null

@export var base_exprience:int = 0 #experiencia que guanyes al derrotar aquest pkmn
@export var height:float = 0
@export var weight:float = 0
@export var is_default:bool = true # es la forma per defecte o no? Quan et trobis aquest pkmn en estat salvatge tindrà aquesta forma per defecte
@export var abilities: Array = [] #FALTA ENUM
@export var forms = [] # TO DO
@export var held_items_id: Array = [] #llista d objectes q pot portar el pokemon quan l'atrapes
@export var held_items_rarity: Array = [] #probabilitat de que porti aquell objecte

# ------------ MOVES    Només ens interessens els tipus 1,2,3,4, 6, 10
@export var learn_type: Array = []
@export var learn_lvl: Array = []
@export var learn_move_id: Array = []

@export var hp_base:int = 0
@export var attack_base:int = 0
@export var defense_base:int = 0
@export var special_attack_base:int = 0
@export var special_defense_base:int = 0
@export var speed_base:int = 0
@export var total_base:int = 0

@export var hp_effort_EVs:int = 0
@export var attack_effort_EVs:int = 0
@export var defense_effort_EVs:int = 0
@export var special_effort_attack_EVs:int = 0
@export var special_effort_defense_EVs:int = 0
@export var speed_effort_EVs:int = 0

@export var gender_rate = 0  #probabilitat de que un pokemon sigui mascle o femella al trobarte'l. SI no te sexte = -1
@export var capture_rate = 0 #facilitat per atrapar aquest pokemon. El maxim crec q es 255, com més alt sigui el num. mes facil és
@export var base_happiness = 0 #Felicitat base que té el pkmn quan l atrapes amb una pokeball normal. El maxim crec q es 255, com més alt sigui el num. mes feicitat tindrà
@export var is_baby = false # si el pkmn es una cria de pkmn o no (ex: magby, elekid)
@export var hatch_counter = 0 #Son el cicles de passos necessaris per trancar un ou, cada cicle son 250 passos. 250 x hatch_counter

@export var has_gender_differences = false # indica si l sprite te diferencies entre un sexe i l altre
@export var forms_switchable = false # indica si el pkmn pot transformarse d una forma a una altre durant la partida o combat

@export var growth_rate_id:int = 1 #indica la velocitat en la que puja de nivell(quantitat d experiencia q guanya) aquest pokemon. Hi ha 5/6 nivells, de mes lent a mes rapid.

@export var egg_group_a_id = 0 #id del grupo huevo 1
@export var egg_group_b_id = 0 #id del grupo huevo 2

@export var evol_method = [] #TO DO #CONST.EVOL_LVL_UP
@export var evol_lvl = [] #TO DO
@export var evol_pokemon_id = [] #TO DO

@export_multiline var description:String = ""

@export var habitat_id:int = 1

@export var battlerPlayerY: int = 0
@export var battlerEnemyY: int = 0
@export var battlerAltitude: int = 0


@export var icon_sprite : AtlasTexture
@export var footprint_sprite : AtlasTexture

@export var battle_front_sprite : AtlasTexture
@export var battle_back_sprite : AtlasTexture

@export var battle_front_shiny_sprite : AtlasTexture
@export var battle_back_shiny_sprite : AtlasTexture

@export var overworld_spritesheet : AtlasTexture
@export var overworld_shiny_spritesheet : AtlasTexture



#var poke_instance_script = preload("res://Assets/Game_data/pokemon_instance.gd")
var move_instance_script = load("res://Scripts/Resources/Instances/move_instance.gd")

#
#func make_wild(level: int):
#	var p = poke_instance_script.new()
#	p.pkm_id = id
#	p.nickname = Name
#	p.level = level
#	p.hp_actual = p.hp
##	p.hp=hp_base
##	p.attack = attack_base
##	p.defense = defense_base
##	p.speed = speed_base
##	p.special_attack = special_attack_base
##	p.special_defense = special_defense_base
#	print("ou mama")
#	randomize()
#	p.ability_id = get_ability()
#	p.dni = 34456547 #TODO:MARIANOGNU: how to generate unique id?
#	p.original_trainer = GAME_DATA.player_name
#	p.exp_to_next_level = 300 #TODO:MARIANOGNU: how to calculate next level?
#
#	var learnable_indexes = []
#
#	for i in range(learn_move_id.size()):
#		if (learn_type[i] == CONST.LEARN_LVL_UP):
#			if (learn_lvl[i] <= level):
#				learnable_indexes.push_back(i)
#
#	learnable_indexes.sort_custom(self, "move_is_greater")
#
#	if (learnable_indexes.size() > 4):
#		var moves = []
#		var idx = learnable_indexes.size()-4;
#		moves.push_back(70)# FUERZA    learnable_indexes[idx])
#		moves.push_back(15)# CORTE     learnable_indexes[idx+1])
#		moves.push_back(57)# SURF      learnable_indexes[idx+2])
#		moves.push_back(learnable_indexes[idx+3])
#		learnable_indexes = moves
#
#	#if p.movements.size() == 0 or p.movements == []:
#	for idx in learnable_indexes:
#		var move = move_instance_script.new()
#		move.id = idx   #learn_move_id[idx]
#		move.pp = DB.moves[move.id].pp
#		move.pp_actual = move.pp
#		p.movements.push_back(move)
#	return p
#
#
#func new_pokemon(pkm):
#	randomize()
#	pkm.hp_actual = pkm.hp
#	if pkm.ability_id == null or pkm.ability_id == CONST.ABILITIES.NONE:
#		pkm.ability_id = get_ability()
#	if pkm.gender == CONST.GENEROS.NON_SELECTED:
#		pkm.gender = rand_range(1.000000, 2.999999)
#		#print(str(pkm.gender))
#		pkm.gender = int(pkm.gender)
#	if pkm.nature_id == CONST.NATURES.NONE:
#		pkm.nature_id = int(rand_range(1.000000, 25.999999))
##	p.hp=hp_base
##	p.attack = attack_base
##	p.defense = defense_base
##	p.speed = speed_base
##	p.special_attack = special_attack_base
##	p.special_defense = special_defense_base
#	#randomize()
#	pkm.exp_to_next_level = 300 #TODO:MARIANOGNU: how to calculate next level?
#
#	var learnable_indexes = []
#
#	for i in range(learn_move_id.size()):
#		if (learn_type[i] == CONST.LEARN_LVL_UP):
#			if (learn_lvl[i] <= pkm.level):
#				learnable_indexes.push_back(i)#DB.moves[learn_move_id[i]].id)
#				#print("Dins: " + str(DB.moves[learn_move_id[i]].id))
##				print("i: " + str(i) + "pkm level: " + str(pkm.level))
#				#print("learnable_indexes: " + str(DB.moves[learn_move_id[i]].Name) + ", move level: " + str(learn_lvl[i]))
#	learnable_indexes.sort_custom(self, "move_is_greater")
#	#print(Name)
#	var temp_moves = []
#	for e in learnable_indexes:
#		temp_moves.push_back(DB.moves[learn_move_id[e]].id)
#		#print("Fora: " + str(e))
##		print(learn_move_id[e])
#		#print("learnable_indexes: " + str(DB.moves[learn_move_id[e]].Name))
#	learnable_indexes = temp_moves
#
#	if (learnable_indexes.size() > 4):
#		var moves = []
#		var idx = learnable_indexes.size()-4;
#		moves.push_back(70)# FUERZA    learnable_indexes[idx])
#		moves.push_back(15)# CORTE     learnable_indexes[idx+1])
#		moves.push_back(57)# SURF      learnable_indexes[idx+2])
#		moves.push_back(learnable_indexes[idx+3])
#		learnable_indexes = moves
#
#	#if p.movements.size() == 0 or p.movements == []:
#	for idx in learnable_indexes:
#		var move = move_instance_script.new()
#		move.id = idx   #learn_move_id[idx]
#		move.pp = DB.moves[move.id].pp
#		move.pp_actual = move.pp
#		pkm.movements.push_back(move)
#
#	return pkm
#
#
func move_is_greater(a, b):
	return learn_lvl[a]<=learn_lvl[b]

#func get_ability():
#	var a = null
#	#print(str(DB.pokemons[1].abilities[0]) + ", " + str(DB.pokemons[1].abilities[1]) + ", " + str(DB.pokemons[1].abilities[2]))
##	print(abilities[1])
##	print(abilities[2])
#	if abilities[0] != null or abilities[1] != null or abilities[2] != null:
#		while a == null:
#			a = abilities[randi() % abilities.size()]
#		return a
#	return CONST.ABILITIES.NONE
