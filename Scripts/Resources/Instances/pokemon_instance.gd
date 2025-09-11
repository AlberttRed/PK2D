@tool
extends Node

class_name PokemonInstance

signal newMoveLearned

@export var randomize_pokemon: bool = false
@export var randomize_stats: bool = false
@export var isWild : bool
var base : Pokemon
#var battleInstance : BattlePokemon

var pkm_id : int = 0 :
	get:
		return base.id
	set(value):
		pkm_id = value 
var Name : String :
	get:
		return base.Name.to_upper()
	set(value):
		Name = value 
@export_enum("None", "Bulbasaur", "Ivysaur", "Venusaur", "Charmander", "Charmeleon", "Charizard", "Squirtle", "Wartortle", "Blastoise", "Caterpie", "Metapod", "Butterfree", "Weedle", "Kakuna", "Beedrill", "Pidgey", "Pidgeotto", "Pidgeot", "Rattata", "Raticate", "Spearow", "Fearow", "Ekans", "Arbok", "Pikachu", "Raichu", "Sandshrew", "Sandslash", "Nidoran♀", "Nidorina", "Nidoqueen", "Nidoran♂", "Nidorino", "Nidoking", "Clefairy", "Clefable", "Vulpix", "Ninetales", "Jigglypuff", "Wigglytuff", "Zubat", "Golbat", "Oddish", "Gloom", "Vileplume", "Paras", "Parasect", "Venonat", "Venomoth", "Diglett", "Dugtrio", "Meowth", "Persian", "Psyduck", "Golduck", "Mankey", "Primeape", "Growlithe", "Arcanine", "Poliwag", "Poliwhirl", "Poliwrath", "Abra", "Kadabra", "Alakazam", "Machop", "Machoke", "Machamp", "Bellsprout", "Weepinbell", "Victreebel", "Tentacool", "Tentacruel", "Geodude", "Graveler", "Golem", "Ponyta", "Rapidash", "Slowpoke", "Slowbro", "Magnemite", "Magneton", "Farfetch’d", "Doduo", "Dodrio", "Seel", "Dewgong", "Grimer", "Muk", "Shellder", "Cloyster", "Gastly", "Haunter", "Gengar", "Onix", "Drowzee", "Hypno", "Krabby", "Kingler", "Voltorb", "Electrode", "Exeggcute", "Exeggutor", "Cubone", "Marowak", "Hitmonlee", "Hitmonchan", "Lickitung", "Koffing", "Weezing", "Rhyhorn", "Rhydon", "Chansey", "Tangela", "Kangaskhan", "Horsea", "Seadra", "Goldeen", "Seaking", "Staryu", "Starmie", "Mr. Mime", "Scyther", "Jynx", "Electabuzz", "Magmar", "Pinsir", "Tauros", "Magikarp", "Gyarados", "Lapras", "Ditto", "Eevee", "Vaporeon", "Jolteon", "Flareon", "Porygon", "Omanyte", "Omastar", "Kabuto", "Kabutops", "Aerodactyl", "Snorlax", "Articuno", "Zapdos", "Moltres", "Dratini", "Dragonair", "Dragonite", "Mewtwo") var pokemon = 0
var nickname:String = ""
@export_range(1, 100) var level: int = 1 
@export_enum("Sin indicar", "Macho", "Hembra", "Sin Genero") var gender = 0:
	set(value):
		print("mec")
		if value == CONST.GENEROS.NON_SELECTED:
			print("mec")
		gender = value
var type_a :
	get:
		return base.type_a
	set(value):
		type_a = value 	
var type_b :
	get:
		return base.type_b
	set(value):
		type_b = value 	
var types : Array[Type] :
	get:
		return [base.type_a as Type, base.type_b as Type]
	set(value):
		types = value 	


var status = CONST.STATUS.OK

var hp_actual: int = 0 
#var hp_total : int = 0:
	#get:
		##return int(10.0 + (float(level) / 100.0 * ((float(base.hp_base) * 2.0) + float(hp_IVs) + float(hp_EVs) ) ) + float(level) ) 
		#print(int(float(hp_EVs) / 4.0))
		#print(str(int( (float(level) * ((float(base.hp_base) * 2.0) + float(hp_IVs) + int(float(hp_EVs) / 4.0) ) ) / 100.0 ) + level + 10 )) 
		##return int( (float(level) * ((float(base.hp_base) * 2.0) + float(hp_IVs) + int(float(hp_EVs) / 4.0) ) ) / 100.0 ) + level + 10
		#return getHPStat(level)
	#set(value):
		#hp_total = value 
#var attack : int: 
	#get:
		##return int(float(int( 5.0 + (( float(level) * ( (float(base.attack_base) * 2.0) + float(attack_IVs) + int(float(attack_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.ATA][nature_id]))
		#return getAttackStat(level)
	#set(value):
		#attack = value 
#var defense : int: 
	#get:
		##return int(float(int(( 5.0 + ( float(level) / 100.0 * ( (float(base.defense_base) * 2.0) + float(defense_IVs) + float(defense_EVs) ) ) ))) * float(CONST.stat_effects_Natures[CONST.STATS.DEF][nature_id]))
		##return int(float(int( 5.0 + (( float(level) * ( (float(base.defense_base) * 2.0) + float(defense_IVs) + int(float(defense_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.DEF][nature_id]))
		#return getDefenseStat(level)
	#set(value):
		#defense = value 
#var special_attack : int:
	#get:
		##return int(float(int(( 5.0 + ( float(level) / 100.0 * ( (float(base.special_attack_base) * 2.0) + float(spAttack_IVs) + float(spAttack_EVs) ) ) ))) * float(CONST.stat_effects_Natures[CONST.STATS.ATAESP][nature_id]))
		##return int(float(int( 5.0 + (( float(level) * ( (float(base.special_attack_base) * 2.0) + float(spAttack_IVs) + int(float(spAttack_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.ATAESP][nature_id]))
		#return getSpAttackStat(level)
	#set(value):
		#special_attack = value 
#var special_defense : int:
	#get:
		##return int(float(int(( 5.0 + ( float(level) / 100.0 * ( (float(base.special_defense_base) * 2.0) + float(spDefense_IVs) + float(spDefense_EVs) ) ) ))) * float(CONST.stat_effects_Natures[CONST.STATS.DEFESP][nature_id]))
		##return int(float(int( 5.0 + (( float(level) * ( (float(base.special_defense_base) * 2.0) + float(spDefense_IVs) + int(float(spDefense_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.DEFESP][nature_id]))
		#return getSpDefenseStat(level)
	#set(value):
		#special_defense = value 
#var speed : int:
	#get:
		##return int(float(int(( 5.0 + ( float(level) / 100.0 * ( (float(base.speed_base) * 2.0) + float(speed_IVs) + float(speed_EVs) ) ) ) )) * float(CONST.stat_effects_Natures[CONST.STATS.VEL][nature_id]))
		##return int(float(int( 5.0 + (( float(level) * ( (float(base.speed_base) * 2.0) + float(speed_IVs) + int(float(speed_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.VEL][nature_id]))
		#return getSpeedStat(level)
	#set(value):
		#speed = value 

var battlerPlayerY: int:
	get:
		return base.battlerPlayerY
var battlerEnemyY: int:
	get:
		return base.battlerEnemyY
var battlerAltitude: int:
	get:
		return base.battlerAltitude
var base_experience: int :
	get:
		return base.base_exprience
var experienceGroup:PokemonExperienceGroup:
	get:
		return PokemonExperienceGroup.new(base.growth_rate_id)
		
var trainer_id:int = 1234
var original_trainer : String = "Red" #De moment posem Red a piñon

var totalExp : int = 0 # Es la quantitat d'experiencia que ha acumulat fins ara el pokemon
var actualLevelExpBase : int: # Es l'experiencia base necessaria per arribar al nivell actual
	get:
		return experienceGroup.calculateExp(level)
var nextLevelExpBase : int: # Es l'experiencia base necessaria per arribar al següent actual
	get:
		if level < 100:
			return experienceGroup.calculateExp(level+1)
		else:
			return totalExp
var inBattle : bool
	#get:
		#return battleInstance != null && battleInstance.inBattle

var activeBattleEffects:Array[BattleEffect]

var inBattleParty : bool

var capture_date: String = "18 de Nov. de 2018" 
var capture_route: String = "Ruta 1" 
var capture_level: int = 5 

var ability_slot: int = 0 #Al crear un pokemon,se li donarà aleatoriament l'slot. Aixo es així perque quan evoluciona, es manté l'slot, pero pot ser que l'evolució tingui un altre hablitat en aquell slot, per tant li canviarà l'habilitat

@export var shiny : bool = false

@export_range(0, 252) var hp_EVs : int = 0
@export_range(0, 252) var attack_EVs : int = 0
@export_range(0, 252) var defense_EVs : int = 0
@export_range(0, 252) var spAttack_EVs : int = 0
@export_range(0, 252) var spDefense_EVs : int = 0
@export_range(0, 252) var speed_EVs : int = 0

@export_range(0, 31) var hp_IVs : int = 0
@export_range(0, 31) var attack_IVs : int = 0
@export_range(0, 31) var defense_IVs : int = 0
@export_range(0, 31) var spAttack_IVs : int = 0
@export_range(0, 31) var spDefense_IVs : int = 0
@export_range(0, 31) var speed_IVs : int = 0
#IMPORTANT -- S'ha de sumar 1 l'ability_id ja que comença per 0
@export_enum("NONE", "HEDOR", "LLOVIZNA", "IMPULSO", "ARMADURA_BATALLA", "ROBUSTEZ", "HUMEDAD","FLEXIBILIDAD","VELO_ARENA","ELEC_ESTATICA","ABSORBE_ELEC","ABSORBE_AGUA","DESPISTE","ACLIMATACION","OJO_COMPUESTO","INSOMNIO","CAMBIO_COLOR","INMUNIDAD","ABSORBE_FUEGO","POLVO_ESCUDO","RITMO_PROPIO","VENTOSAS","INTIMIDACION","SOMBRA_TRAMPA","PIEL_TOSCA","SUPERGUARDA","LEVITACION","EFECTO_ESPORA","SINCRONIA","CUERPO_PURO","CURA_NATURAL","PARARRAYOS","DICHA","NADO_RAPIDO","CLOROFILA","ILUMINACION","RASTRO","POTENCIA","PUNTO_TOXICO","FOCO_INTERNO","ESCUDO_MAGMA","VELO_AGUA","IMAN","INSONORIZAR","CURA_LLUVIA","CHORRO_ARENA","PRESION","SEBO","MADRUGAR","CUERPO_LLAMA","FUGA","VISTA_LINCE","CORTE_FUERTE","RECOGIDA","AUSENTE","ENTUSIASMO","GRAN_ENCANTO","MAS","MENOS","PREDICCION","VISCOSIDAD","MUDAR","AGALLAS","ESCAMA_ESPECIAL","LODO_LIQUIDO","ESPESURA","MAR_LLAMAS","TORRENTE","ENJAMBRE","CABEZA_ROCA","SEQUIA","TRAMPA_ARENA","ESPIRITU_VITAL","HUMO_BLANCO","ENERGIA_PURA","CAPARAZON","BUCLE_AIRE","TUMBOS","ELECTROMOTOR","RIVALIDAD","IMPASIBLE","MANTO_NIVEO","GULA","IRASCIBLE","LIVIANO","IGNIFUGO","SIMPLE","PIEL_SECA","DESCARGA","PUNO_FERREO","ANTIDOTO","ADAPTABLE","ENCADENADO","HIDRATACION","PODER_SOLAR","PIES_RAPIDOS","NORMALIDAD","FRANCOTIRADOR","MURO_MAGICO","INDEFENSO","REZAGADO","EXPERTO","DEFENSA_HOJA","ZOQUETE","ROMPEMOLDES","AFORTUNADO","RESQUICIO","ANTICIPACION","ALERTA","IGNORANTE","CROMOLENTE","FILTRO","INICIO_LENTO","INTREPIDO","COLECTOR","GELIDO","ROCA_SOLIDA","NEVADA","RECOGEMIEL","CACHEO","AUDAZ","MULTITIPO","DON_FLORAL","MAL_SUENO","HURTO","POTENCIA_BRUTA","RESPONDON","NERVIOSISMO","COMPETITIVO","FLAQUEZA","CUERPO_MALDITO","ALMA_CURA","COMPIESCOLTA","ARMADURA_FRAGIL","METAL_PESADO","METAL_LIVIANO","COMPENSACION","IMPETU_TOXICO","IMPETU_ARDIENTE","COSECHA","TELEPATIA","VELETA","FUNDA","TOQUE_TOXICO","REGENERACION","SACAPECHO","IMPETU_ARENA","PIEL_MILAGRO","CALCULO_FINAL","ILUSION","IMPOSTOR","ALLANAMIENTO","MOMIA","AUTOESTIMA","JUSTICIERO","COBARDIA","ESPEJO_MAGICO","HERBIVORO","BROMISTA","PODER_ARENA","PUNTA_ACERO","MODO_DARUMA","TINOVICTORIA","TURBOLLAMA","TERRAVOLTAJE","VELO_AROMA","VELO_FLOR","CARRILLO","MUTATIPO","PELAJE_RECIO","PRESTIDIGITADOR","ANTIBALAS","TENACIDAD","MANDIBULA_FUERTE","PIEL_HELADA","VELO_DULCE","CAMBIO_TACTICO","ALAS_VENDAVAL","MEGADISPARADOR","MANTO_FRONDOSO","SIMBIOSIS","GARRA_DURA","PIEL_FEERICA","BABA","PIEL_CELESTE","AMOR_FILIAL","AURA_OSCURA","AURA_FEERICA","ROMPEAURA","MAR_DEL_ALBOR","TIERRA_DEL_OCASO","RAFAGA_DELTA","FIRMEZA","HUIDA","RETIRADA","HIDRORREFUERZO","ENSANAMIENTO","ESCUDO_LIMITADO","VIGILANTE","POMPA","ACERO_TEMPLADO","COLERA","QUITANIEVES","REMOTO","VOZ_FLUIDA","PRIMER_AUXILIO","PIEL_ELECTRICA","COLA_SURF","BANCO","DISFRAZ","FUERTE_AFECTO","AGRUPAMIENTO","CORROSION","LETARGO_PERENNE","REGIA_PRESENCIA","REVES","PAREJA_DE_BAILE","BATERIA","PELUCHE","CUERPO_VIVIDO","CORANIMA","RIZOS_REBELDES","RECEPTOR","REACCION_QUIMICA","ULTRAIMPULSO","SISTEMA_ALFA","ELECTROGENESIS","PSICOGENESIS","NEBULOGENESIS","HERBOGENESIS","GUARDIA_METALICA","GUARDIA_ESPECTRO","ARMADURA_PRISMA") var ability_id : int #setget set_ability,get_ability
#@export_enum("NONE", "HEDOR", "LLOVIZNA", "IMPULSO", "ARMADURA_BATALLA", "ROBUSTEZ", HUMEDAD , FLEXIBILIDAD , VELO_ARENA , ELEC_ESTATICA , ABSORBE_ELEC , ABSORBE_AGUA , DESPISTE , ACLIMATACION , OJO_COMPUESTO , INSOMNIO , CAMBIO_COLOR , INMUNIDAD , ABSORBE_FUEGO , POLVO_ESCUDO , RITMO_PROPIO , VENTOSAS , INTIMIDACION , SOMBRA_TRAMPA , PIEL_TOSCA , SUPERGUARDA , LEVITACION , EFECTO_ESPORA , SINCRONIA , CUERPO_PURO , CURA_NATURAL , PARARRAYOS , DICHA , NADO_RAPIDO , CLOROFILA , ILUMINACION , RASTRO , POTENCIA , PUNTO_TOXICO , FOCO_INTERNO , ESCUDO_MAGMA , VELO_AGUA , IMAN , INSONORIZAR , CURA_LLUVIA , CHORRO_ARENA , PRESION , SEBO , MADRUGAR , CUERPO_LLAMA , FUGA , VISTA_LINCE , CORTE_FUERTE , RECOGIDA , AUSENTE , ENTUSIASMO , GRAN_ENCANTO , MAS , MENOS , PREDICCION , VISCOSIDAD , MUDAR , AGALLAS , ESCAMA_ESPECIAL , LODO_LIQUIDO , ESPESURA , MAR_LLAMAS , TORRENTE , ENJAMBRE , CABEZA_ROCA , SEQUIA , TRAMPA_ARENA , ESPIRITU_VITAL , HUMO_BLANCO , ENERGIA_PURA , CAPARAZON , BUCLE_AIRE , TUMBOS , ELECTROMOTOR , RIVALIDAD , IMPASIBLE , MANTO_NIVEO , GULA , IRASCIBLE , LIVIANO , IGNIFUGO , SIMPLE , PIEL_SECA , DESCARGA , PUNO_FERREO , ANTIDOTO , ADAPTABLE , ENCADENADO , HIDRATACION , PODER_SOLAR , PIES_RAPIDOS , NORMALIDAD , FRANCOTIRADOR , MURO_MAGICO , INDEFENSO , REZAGADO , EXPERTO , DEFENSA_HOJA , ZOQUETE , ROMPEMOLDES , AFORTUNADO , RESQUICIO , ANTICIPACION , ALERTA , IGNORANTE , CROMOLENTE , FILTRO , INICIO_LENTO , INTREPIDO , COLECTOR , GELIDO , ROCA_SOLIDA , NEVADA , RECOGEMIEL , CACHEO , AUDAZ , MULTITIPO , DON_FLORAL , MAL_SUENO , HURTO , POTENCIA_BRUTA , RESPONDON , NERVIOSISMO , COMPETITIVO , FLAQUEZA , CUERPO_MALDITO , ALMA_CURA , COMPIESCOLTA , ARMADURA_FRAGIL , METAL_PESADO , METAL_LIVIANO , COMPENSACION , IMPETU_TOXICO , IMPETU_ARDIENTE , COSECHA , TELEPATIA , VELETA , FUNDA , TOQUE_TOXICO , REGENERACION , SACAPECHO , IMPETU_ARENA , PIEL_MILAGRO , CALCULO_FINAL , ILUSION , IMPOSTOR , ALLANAMIENTO , MOMIA , AUTOESTIMA , JUSTICIERO , COBARDIA , ESPEJO_MAGICO , HERBIVORO , BROMISTA , PODER_ARENA , PUNTA_ACERO , MODO_DARUMA , TINOVICTORIA , TURBOLLAMA , TERRAVOLTAJE , VELO_AROMA , VELO_FLOR , CARRILLO , MUTATIPO , PELAJE_RECIO , PRESTIDIGITADOR , ANTIBALAS , TENACIDAD , MANDIBULA_FUERTE , PIEL_HELADA , VELO_DULCE , CAMBIO_TACTICO , ALAS_VENDAVAL , MEGADISPARADOR , MANTO_FRONDOSO , SIMBIOSIS , GARRA_DURA , PIEL_FEERICA , BABA , PIEL_CELESTE , AMOR_FILIAL , AURA_OSCURA , AURA_FEERICA , ROMPEAURA , MAR_DEL_ALBOR , TIERRA_DEL_OCASO , RAFAGA_DELTA , FIRMEZA , HUIDA , RETIRADA , HIDRORREFUERZO , ENSANAMIENTO , ESCUDO_LIMITADO , VIGILANTE , POMPA , ACERO_TEMPLADO , COLERA , QUITANIEVES , REMOTO , VOZ_FLUIDA , PRIMER_AUXILIO , PIEL_ELECTRICA , COLA_SURF , BANCO , DISFRAZ , FUERTE_AFECTO , AGRUPAMIENTO , CORROSION , LETARGO_PERENNE , REGIA_PRESENCIA , REVES , PAREJA_DE_BAILE , BATERIA , PELUCHE , CUERPO_VIVIDO , CORANIMA , RIZOS_REBELDES , RECEPTOR , REACCION_QUIMICA , ULTRAIMPULSO , SISTEMA_ALFA , ELECTROGENESIS , PSICOGENESIS , NEBULOGENESIS , HERBOGENESIS , GUARDIA_METALICA , GUARDIA_ESPECTRO , ARMADURA_PRISMA ") var ability_id : int #setget set_ability,get_ability
#@export_enum("NONE", "ACTIVA", "AFABLE", "AGITADA", "ALEGRE", "ALOCADA", "AMABLE", "AUDAZ", "CAUTA", "DÓCIL", "FIRME", "FLOJA", "FUERTE", "GROSERA", "HURAÑA", "INGENUA", "MANSA", "MIEDOSA", "MODESTA", "OSADA", "PÍCARA", "PLÁCIDA", "RARA", "SERENA", "SERIA", "TÍMIDA") var nature_id #setget set_naturaleza,get_naturaleza
#@export_enum("HARDY", "LONELY", "BRAVE", "ADAMANT", "NAUGHTY",
			 #"BOLD", "DOCILE", "RELAXED", "IMPISH", "LAX",
			 #"TIMID", "HASTY", "SERIOUS", "JOLLY", "NAIVE",
			 #"MODEST", "MILD", "QUIET", "BASHFUL", "RASH",
			 #"CALM", "GENTLE", "SASSY", "CAREFUL", "QUIRKY")
@export var nature_id: NatureTypes.Nature = NatureTypes.Nature.SERIOUS#"SERIOUS"  # valor por defecto


@export var held_item_id: int

var battle_front_sprite:
	get:
		if shiny:
			return base.battle_front_shiny_sprite
		else:
			return base.battle_front_sprite
	set(value):
		battle_front_sprite = value
var battle_back_sprite:
	get:
		if shiny:
			return base.battle_back_shiny_sprite
		else:
			return base.battle_back_sprite

var icon_sprite:
	get:
		return base.icon_sprite
	
	set(value):
		battle_back_sprite = value
		
var fainted : bool = false :
	get:
		return hp_actual == 0
		
#var EVs:Array[int]:
	#get:
		#return [hp_EVs, attack_EVs, defense_EVs, spAttack_EVs, spDefense_EVs, speed_EVs] 
#var IVs:Array[int]:
	#get:
		#return [hp_IVs, attack_IVs, defense_IVs, spAttack_IVs, spDefense_IVs, speed_IVs]
var personality = "" #setget set_personality,get_personality
var trainer:Battler #Indica l'entrenador del pokemon(si en té)
var learningMoves:Array[PokemonLearningMove] #Indicates the list of moves this pokemon is capable to learn

var ally
var enemies = []
#var base
var node
var hp_bar
var front_single_position = CONST.BATTLE.FRONT_SINGLE_SPRITE_POS
var back_single_position =  CONST.BATTLE.BACK_SINGLE_SPRITE_POS
var battle_double_position
var pokeball_node
var battle_position
#class move_instance:
#	var id = 1
#	var pp = 5
#	var max_pp = 5
#	var mod_pp = 0
#	func get_name():
#		return DB.moves[id].Name
#	func get_power():
#		return DB.moves[id].power
#	func get_acuracy():
#		return DB.moves[id].acuracy
#	func get_type():
#		return DB.types[DB.moves[id].type]
#	func get_type_name():
#		return DB.types[DB.moves[id].type].Name
#	func doMove():
#		DB.moves[id].doMove()

var movements : Array[MoveInstance] = []
var newLearningMove : MoveInstance



var base_stats: Dictionary[StatTypes.Stat, int] 

var evs: Dictionary[StatTypes.Stat, int] 

var ivs: Dictionary[StatTypes.Stat, int] 

var nature: Nature
var ability: Ability

func create(_randomize_stats : bool = true, _pkmn_id : int = -1, _level : int = -1, _gender : int = -1, _ability_id : int = -1, _nature_id : NatureTypes.Nature = NatureTypes.Nature.NONE):
	

	if _pkmn_id == -1:
		var pk_num : String = "%03d" % randi_range(1, 151)
		base = load("res://Resources/Pokemon/" + pk_num + ".tres")
	else:
		var pk_num : String = "%03d" % _pkmn_id
		base = load("res://Resources/Pokemon/" + pk_num + ".tres")
		
	if _level == -1:
		randomize()
		level = randi_range(1, 100)
	else:
		level = _level
		
	if _gender == -1 or _gender == 0:
		gender = calculateGender()
	else:
		gender = _gender
		
	if _ability_id == -1:
		ability_id = calculateAbility().to_int()
	else:
		ability_id = _ability_id
	
	ability = get_ability_resource()
		
	if _nature_id == NatureTypes.Nature.NONE:
		randomize()
		nature = load_nature_by_id(NatureTypes.get_random_nature())
	else:
		nature = load_nature_by_id(nature_id)
		
	randomize_stats = _randomize_stats	
	#print(pkm_id.keys()[pkm_id])
	init_pokemon()
	
	return self
	
func _ready():

	add_user_signal("hp_updated")
#	if base != null:
#		init_pokemon()
	if randomize_pokemon || randomize_stats:
		randomize_pkmn()
	else:
		print("res://Resources/Data/Pokemon/"+str(pokemon).pad_zeros(3)+".tres")
		base = load("res://Resources/Data/Pokemon/"+str(pokemon).pad_zeros(3)+".tres")

	nature = load_nature_by_id(nature_id)
	ability = get_ability_resource()

	load_stats()
	totalExp = actualLevelExpBase
	personality = get_personality_text()
#	print("patata")
#	set_info()
	loadLearningMoves()
	load_moves()
	hp_actual = get_final_stat(StatTypes.Stat.HP)
#	hp_total = get_total_hp()
#	hp_actual = int(float(hp_total) / randf_range(1, 6))
#	attack = get_attack()  
#	speed  = get_speed()  
#	defense = get_defense()  
#	special_attack = get_special_attack() #
#	special_defense  = get_special_defense()
#	
#	EVs = [hp_EVs, attack_EVs, defense_EVs, spAttack_EVs, spDefense_EVs, speed_EVs] 
#	IVs = [hp_IVs, attack_IVs, defense_IVs, spAttack_IVs, spDefense_IVs, speed_IVs]
#	personality = get_personality_text()

func init_pokemon():
	
	if randomize_pokemon || randomize_stats:
		randomize_pkmn()
	print("init " + Name)
	
	loadLearningMoves()
	
	if gender == CONST.GENEROS.NON_SELECTED:
		push_error("No s'ha seleccionat un genere pel pokémon " + Name)
		#set_info()
	load_moves()
	hp_actual = get_final_stat(StatTypes.Stat.HP)
	
	load_stats()
	#ability_id = CONST.ABILITIES.INTIMIDATE

#
#	hp_total = get_total_hp()
#	hp_actual = hp_total
#	attack = get_attack()  
#	speed  = get_speed()  
#	defense = get_defense()  
#	special_attack = get_special_attack() #
#	special_defense  = get_special_defense()

	#EVs = [hp_EVs, attack_EVs, defense_EVs, spAttack_EVs, spDefense_EVs, speed_EVs] 
	#IVs = [hp_IVs, attack_IVs, defense_IVs, spAttack_IVs, spDefense_IVs, speed_IVs]
	personality = get_personality_text()

func randomize_pkmn():
	
	if randomize_pokemon:
		randomize()
		base = load("res://Resources/Data/Pokemon/"+str(randi_range(1, 151)).pad_zeros(3)+".tres")
		#pkm_id = randi_range(1, DB.get_node("Pokemons").get_children().size())
		level = randi_range(1, 100)
		gender = calculateGender()
	
		ability_id = randi_range(1, 232)
		nature_id = randi_range(1, 25)
		totalExp = actualLevelExpBase
	
	if randomize_pokemon || randomize_stats:
		hp_EVs = randi_range(0, 252)
		attack_EVs = randi_range(0, 252)
		defense_EVs = randi_range(0, 252)
		spAttack_EVs = randi_range(0, 252)
		spDefense_EVs = randi_range(0, 252)
		speed_EVs = randi_range(0, 252)
		
		hp_IVs = randi_range(0, 31)
		attack_IVs = randi_range(0, 31)
		defense_IVs = randi_range(0, 31)
		spAttack_IVs = randi_range(0, 31)
		spDefense_IVs = randi_range(0, 31)
		speed_IVs = randi_range(0, 31)

func load_moves():
	var learnable_indexes = []
	#var move_instance_script = load("res://Database/Instances/move_instance.gd")
	#print(learn_move_id)
	#print(Name)
	
	var moves:Array[PokemonLearningMove] = learningMoves.filter(func(move:PokemonLearningMove): return move.learningType==PokemonLearningMove.Type.LVL_UP and move.learningLevel<=level).slice(0, 4)
	
	movements.assign(moves.map(func(m:PokemonLearningMove): return m.getMove()))
	if movements.size() < 4:
		movements.push_back(MoveInstance.new(86))
	if movements.size() < 4:
		movements.push_back(MoveInstance.new(3))
	
func addMove(_move:MoveInstance):
	if movements.size() == 4:
		assert(false, "Pokemon already has 4 moves")
	movements.push_back(_move)

		
	#for i in range(base.learn_move_id.size()):
		#if (base.learn_type[i] == str(CONST.LEARN_LVL_UP)):
			##print("lvl " + str(base.learn_lvl[i]) + " " + str(base.learn_move_id[i]))
			#if (base.learn_lvl[i] <= level):
				#
				#learnable_indexes.push_back(i)
##	print(learnable_indexes)
##	for i in learnable_indexes:
##		print(str(learn_move_id[i]) + " " + str(DB.Moves[learn_move_id[i].to_int()-1].get_name()))
#
	##learnable_indexes.sort_custom(Callable(self, "move_is_greater"))
	##print(Name)
	##for m in learnable_indexes:
		##print(DB.Moves[m+1].name)
	#if (learnable_indexes.size() > 4):
		#var moves = []
		#var idx = learnable_indexes.size()-4;
##		moves.push_back(69)# FUERZA    learnable_indexes[idx])
##		moves.push_back(14)# CORTE     learnable_indexes[idx+1])
##		moves.push_back(56)# SURF      learnable_indexes[idx+2])
		#moves.push_back(learnable_indexes[idx])
		#moves.push_back(learnable_indexes[idx+1])
		#moves.push_back(learnable_indexes[idx+2])
		#moves.push_back(learnable_indexes[idx+3])
		#
		#learnable_indexes = moves
	##print(learnable_indexes)
	#if learnable_indexes.size() == 4:
		#learnable_indexes.remove_at(3)
	##if p.movements.size() == 0 or p.movements == []:
	#for idx in learnable_indexes:
		#var move = MoveInstance.new(base.learn_move_id[idx].to_int())
		##var move = move_instance_script.new().create(base.learn_move_id[idx].to_int())
##		move.id = learn_move_id[idx].to_int()-1
##		move.pp = DB.Moves[move.id].pp
##		move.pp_actual = move.pp
		#movements.push_back(move)
	#Onda Trueno
	#if movements.size() < 4:
		#movements.push_back(move_instance_script.new().create(86))
	#Doble Bofeton
	#movements.push_back(move_instance_script.new().create(3))
	#Polvo veneno
	#if movements.size() < 4:
		#movements.push_back(move_instance_script.new().create(261))
	#Picotazo Ven.
	#movements.push_back(move_instance_script.new().create(40))
	#Hipnosis
	#if movements.size() < 4:
		#movements.push_back(move_instance_script.new().create(240))
	#
	
func loadLearningMoves():
	for i in range(base.learn_move_id.size()):
		print(base.learn_move_id[i])
		print(base.learn_type[i])
		print(base.learn_lvl[i])
		learningMoves.push_back(PokemonLearningMove.new(base.learn_move_id[i] as int, base.learn_type[i] as int,base.learn_lvl[i] as int))
		



#Calcula aleatoriament quin genero tindrà aquest pokemon, a partir del seu gender_rate
#a l'hora de generar un pokemon nou
func calculateGender():
	if base.gender_rate == -1:
		return CONST.GENEROS.SIN_GENERO
	else:
		randomize()
		var female_chane : float = float(base.gender_rate) / 8.0
		var rand_num = randf_range(0, 1)

		if rand_num <= female_chane:
			return CONST.GENEROS.HEMBRA
		else:
			return CONST.GENEROS.MACHO

#Normlament sempre retorna l slot 1 o el 2, que shon habilitats nromals. L'slot 3 es l habilitat amagada
# que s'obté en casos especials. Si a l'slot obtingut l'habilitat es null, es retorna l habilitat de l'slot 1
func calculateAbility():
	randomize()
	ability_slot = randi_range(0, 1)
	
	var ability = base.abilities[ability_slot]
	
	if ability == null:
		return base.abilities[0]
	else:
		return ability
	

	
func get_highest_IV() -> StatTypes.Stat:
	var highest_valor = -1
	var highest_IVs:Array[StatTypes.Stat] = []
	for iv in ivs:
		#print(str(iv) + ": " + str(IVs[iv])) 
		if ivs[iv] > highest_valor:
			highest_IVs.clear()
			highest_IVs.push_back(iv)
			highest_valor = ivs[iv]
		elif ivs[iv] == highest_valor:
			highest_IVs.push_back(iv)
	#print("return ivs: " + str(highest_IVs))
	return highest_IVs[randi() % highest_IVs.size()]
	
func get_personality_text():
	var highest_IV = get_highest_IV()
#	for n in range(5*highest_IV):
	#print(get_name() + ": " + str(highest_IV))
	for f in CONST.Personality_Table[highest_IV]:
		if f[0].has(ivs[highest_IV]):
			return f[1]


func log_pokemon_stats() -> void:
	var level = self.level
	var nature = self.nature
	print("===== POKÉMON STATS LOG =====")
	print("Especie: %s | Nivel: %d | Naturaleza: %s" %
		[self.Name, self.level, self.nature.display_name if self.nature else "Desconocida"])

	for stat in [
		StatTypes.Stat.HP,
		StatTypes.Stat.ATTACK,
		StatTypes.Stat.DEFENSE,
		StatTypes.Stat.SP_ATTACK,
		StatTypes.Stat.SP_DEFENSE,
		StatTypes.Stat.SPEED
	]:
		var base = self.get_base_stat(stat)
		var iv = self.get_iv(stat)
		var ev = self.get_ev(stat)
		var final = self.get_final_stat(stat)
		var modifier = nature.get_stat_multiplier(stat) if nature else 1.0
		var icon = "↑" if modifier > 1.0 else "↓" if modifier < 1.0 else "–"
		var stat_name = StatTypes.stat_to_string(stat)

		print("%-17s Base: %3d | IV: %2d | EV: %3d | Total: %3d | %s" %
			[stat_name + ":", base, iv, ev, final, icon])
	print("==============================")

	
func print_moves():
	print("+++++ MOVIMIENTOS +++++")
	for m in movements:
		m.print_move()
	
#func update_HP(damage):
#	hp_bar.update_health(damage)
#	yield(hp_bar, "hp_updated")
#	emit_signal("hp_updated")
#

#func get_type1():
#	if type_a == null:
#		return 0
#	return type_a.to_int()
#
#func get_type2():
#	if type_b == null:
#		return 0
#	return type_b.to_int()

#func get_types():
#	return [DB.pokemons[pkm_id].type_a, DB.pokemons[pkm_id].type_b]

func get_base_stat(stat: StatTypes.Stat) -> int:
	return base_stats.get(stat, 0)

func get_iv(stat: StatTypes.Stat) -> int:
	return ivs.get(stat, 0)

func get_ev(stat: StatTypes.Stat) -> int:
	return evs.get(stat, 0)
	
func get_final_stat(stat: StatTypes.Stat, _level: int = self.level) -> int:
	var base = get_base_stat(stat)
	var iv = get_iv(stat)
	var ev = get_ev(stat)

	var total = ((2 * base + iv + int(ev / 4)) * _level) / 100

	if stat == StatTypes.Stat.HP:
		return int(total) + _level + 10
	else:
		var multiplier = 1.0
		if nature:
			multiplier = nature.get_stat_multiplier(stat)
		return int((total + 5) * multiplier)

func load_stats():
	self.base_stats = {
	StatTypes.Stat.ATTACK: base.attack_base,
	StatTypes.Stat.DEFENSE: base.defense_base,
	StatTypes.Stat.SP_ATTACK: base.special_attack_base,
	StatTypes.Stat.SP_DEFENSE: base.special_defense_base,
	StatTypes.Stat.SPEED: base.speed_base,
	StatTypes.Stat.HP: base.hp_base,
	StatTypes.Stat.ACCURACY: 100,  # precisión base por defecto
	StatTypes.Stat.EVASION: 100    # evasión base por defecto
	}

	self.evs = {
	StatTypes.Stat.ATTACK: attack_EVs,
	StatTypes.Stat.DEFENSE: defense_EVs,
	StatTypes.Stat.SP_ATTACK: spAttack_EVs,
	StatTypes.Stat.SP_DEFENSE: spDefense_EVs,
	StatTypes.Stat.SPEED: speed_EVs,
	StatTypes.Stat.HP: hp_EVs 
}

# Si necesitas EVs distintos (aunque normalmente son fijos por especie)
	self.ivs = {
	StatTypes.Stat.ATTACK: attack_IVs,
	StatTypes.Stat.DEFENSE: defense_IVs,
	StatTypes.Stat.SP_ATTACK: spAttack_IVs,
	StatTypes.Stat.SP_DEFENSE: spDefense_IVs,
	StatTypes.Stat.SPEED: speed_IVs,
	StatTypes.Stat.HP: hp_IVs 
}


func is_status(s):
	return status == s
	
func hasWorkingAbility(a):
	return ability_id == a
	
func hasAlly():
	return ally != null
	
func hasFullHealth():
	return hp_actual == get_final_stat(StatTypes.Stat.HP)
	
func updateStats():
	pass
	
func checkNewLevelMoveLearned():
	newLearningMove = null
	var newMove:PokemonLearningMove = learningMoves.filter(func(move:PokemonLearningMove): return move.learningType == PokemonLearningMove.Type.LVL_UP and move.learningLevel == level).pop_front()
	if newMove!=null:
		newLearningMove = newMove.getMove()
	
func levelUP():
	var previousHP:float = get_final_stat(StatTypes.Stat.HP)
	level += 1
	updateStats()
	var newHP:float = get_final_stat(StatTypes.Stat.HP)
	var incrHP:float = (newHP - previousHP) / previousHP * 100.0
	var hpAdd = ceil(hp_actual * (incrHP/100.0))
	hp_actual =  hp_actual + hpAdd
#
#func getHPStat(_level:int = level):
	#return int( (float(_level) * ((float(base.hp_base) * 2.0) + float(hp_IVs) + int(float(hp_EVs) / 4.0) ) ) / 100.0 ) + _level + 10
#
#func getAttackStat(_level:int = level):
	#return int(float(int( 5.0 + (( float(_level) * ( (float(base.attack_base) * 2.0) + float(attack_IVs) + int(float(attack_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.ATA][nature_id]))
#
	#
#func getDefenseStat(_level:int = level):
	#return int(float(int( 5.0 + (( float(_level) * ( (float(base.defense_base) * 2.0) + float(defense_IVs) + int(float(defense_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.DEF][nature_id]))
#
#
#func getSpAttackStat(_level:int = level):
	#return int(float(int( 5.0 + (( float(_level) * ( (float(base.special_attack_base) * 2.0) + float(spAttack_IVs) + int(float(spAttack_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.ATAESP][nature_id]))
#
#
#func getSpDefenseStat(_level:int = level):
	#return int(float(int( 5.0 + (( float(_level) * ( (float(base.special_defense_base) * 2.0) + float(spDefense_IVs) + int(float(spDefense_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.DEFESP][nature_id]))
#
#
#func getSpeedStat(_level:int = level):
	#return int(float(int( 5.0 + (( float(_level) * ( (float(base.speed_base) * 2.0) + float(speed_IVs) + int(float(speed_EVs) / 4.0) ) ) / 100.0 ))) * float(CONST.stat_effects_Natures[CONST.STATS.VEL][nature_id]))


func to_battle_pokemon(ai: BattleIA = null) -> BattlePokemon:
	var battle_pokemon = BattlePokemon.new(self, ai)
	battle_pokemon.is_wild = self.isWild
	battle_pokemon.prepare_battle_moves()
	return battle_pokemon

func get_ability_resource() -> Ability:
	var prefix = "%03d-" % ability_id
	var dir = DirAccess.open("res://Resources/Abilities")
	if dir:
		for file in dir.get_files():
			if file.begins_with(prefix) and file.ends_with(".tres"):
				return load("res://Resources/Abilities/" + file)
	return null

func load_nature_by_id(_nature_id: NatureTypes.Nature) -> Nature:
	var path = "res://Resources/Natures/%s.tres" % NatureTypes.get_id(_nature_id).to_upper()
	if ResourceLoader.exists(path):
		return load(path)
		#push_error("Nature not found: %s" % _nature_id)
	return null



#func hasMove(move_id):
#	for m in movements:
#		if m.id == move_id:
#			return true
#	print("has move " + DB.moves[move_id].Name + "?")
#	return false
##
#func is_type(type): return type == "Pokemon" or .is_type(type)
#func    get_type(): return "Pokemon"

func _get_property_list():
	var properties = []
	# Same as "export(int) var my_property"
	properties.append({
		name = "EVs",
		type = TYPE_NIL,
		usage = PROPERTY_USAGE_GROUP,
		hint_string = "rotate_"
	})
	
	properties.append({
		name = "rotate_hp_EVs",
		type = TYPE_INT
	})
	
	return properties

func hasItemEquipped(item_id:int):
	return held_item_id==item_id

func _to_string():
	return Name
