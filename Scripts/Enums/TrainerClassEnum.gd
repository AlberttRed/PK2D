## Enum de clases/tipos de entrenador
class_name TrainerClassEnum

enum Values {
	# === CLASES BÁSICAS ===
	YOUNGSTER = 0,
	LASS = 1,
	BUG_CATCHER = 2,
	SCHOOL_KID = 3,
	RICH_BOY = 4,
	LADY = 5,
	BEAUTY = 6,
	GENTLEMAN = 7,
	CAMPER = 8,
	PICNICKER = 9,
	HIKER = 10,
	BIKER = 11,
	BLACKBELT = 12,
	BIRD_KEEPER = 13,
	SWIMMER_M = 14,
	SWIMMER_F = 15,
	FISHERMAN = 16,
	SAILOR = 17,
	TUBER = 18,
	TWINS = 19,
	
	# === CLASES AVANZADAS ===
	COOLTRAINER_M = 20,
	COOLTRAINER_F = 21,
	ACE_TRAINER_M = 22,
	ACE_TRAINER_F = 23,
	POKEFAN_M = 24,
	POKEFAN_F = 25,
	COLLECTOR = 26,
	POKEMANIAC = 27,
	PSYCHIC_M = 28,
	PSYCHIC_F = 29,
	HEX_MANIAC = 30,
	CHANNELER = 31,
	MEDIUM = 32,
	SCIENTIST = 33,
	ENGINEER = 34,
	ROCKET_GRUNT_M = 35,
	ROCKET_GRUNT_F = 36,
	
	# === ESPECIALISTAS ===
	DRAGON_TAMER = 40,
	JUGGLER = 41,
	TAMER = 42,
	PAINTER = 43,
	GUITARIST = 44,
	TRIATHLETE_BIKE = 45,
	TRIATHLETE_RUN = 46,
	TRIATHLETE_SWIM = 47,
	BATTLE_GIRL = 48,
	AROMA_LADY = 49,
	RUIN_MANIAC = 50,
	NINJA_BOY = 51,
	
	# === LÍDERES DE GIMNASIO (Gen 1) ===
	GYM_LEADER_BROCK = 100,
	GYM_LEADER_MISTY = 101,
	GYM_LEADER_LT_SURGE = 102,
	GYM_LEADER_ERIKA = 103,
	GYM_LEADER_KOGA = 104,
	GYM_LEADER_SABRINA = 105,
	GYM_LEADER_BLAINE = 106,
	GYM_LEADER_GIOVANNI = 107,
	
	# === ALTO MANDO (Gen 1) ===
	ELITE_FOUR_LORELEI = 110,
	ELITE_FOUR_BRUNO = 111,
	ELITE_FOUR_AGATHA = 112,
	ELITE_FOUR_LANCE = 113,
	CHAMPION_BLUE = 114,
	
	# === ESPECIALES ===
	RIVAL = 200,
	TEAM_ROCKET_BOSS = 201,
	POKEMON_TRAINER = 202,
	
	# === PERSONALIZADO ===
	CUSTOM = 999
}

## Retorna el nombre legible de la clase de entrenador
static func get_display_name(trainer_class: Values) -> String:
	match trainer_class:
		# Básicas
		Values.YOUNGSTER: return "Joven"
		Values.LASS: return "Chica"
		Values.BUG_CATCHER: return "Cazabichos"
		Values.SCHOOL_KID: return "Colegial"
		Values.RICH_BOY: return "Niño Pijo"
		Values.LADY: return "Dama"
		Values.BEAUTY: return "Belleza"
		Values.GENTLEMAN: return "Caballero"
		Values.CAMPER: return "Campista"
		Values.PICNICKER: return "Pícnic"
		Values.HIKER: return "Montañero"
		Values.BIKER: return "Motorista"
		Values.BLACKBELT: return "Karateka"
		Values.BIRD_KEEPER: return "Ornitólogo"
		Values.SWIMMER_M: return "Nadador"
		Values.SWIMMER_F: return "Nadadora"
		Values.FISHERMAN: return "Pescador"
		Values.SAILOR: return "Marinero"
		Values.TUBER: return "Flotador"
		Values.TWINS: return "Gemelas"
		
		# Avanzadas
		Values.COOLTRAINER_M: return "Entrenador Guay"
		Values.COOLTRAINER_F: return "Entrenadora Guay"
		Values.ACE_TRAINER_M: return "Entrenador As"
		Values.ACE_TRAINER_F: return "Entrenadora As"
		Values.POKEFAN_M: return "Pokéfan"
		Values.POKEFAN_F: return "Pokéfan"
		Values.COLLECTOR: return "Coleccionista"
		Values.POKEMANIAC: return "Pokemaníaco"
		Values.PSYCHIC_M: return "Médium"
		Values.PSYCHIC_F: return "Médium"
		Values.HEX_MANIAC: return "Bruja"
		Values.CHANNELER: return "Medium"
		Values.MEDIUM: return "Vidente"
		Values.SCIENTIST: return "Científico"
		Values.ENGINEER: return "Ingeniero"
		Values.ROCKET_GRUNT_M: return "Soldado Rocket"
		Values.ROCKET_GRUNT_F: return "Soldado Rocket"
		
		# Especialistas
		Values.DRAGON_TAMER: return "Domador"
		Values.JUGGLER: return "Malabarista"
		Values.TAMER: return "Domador"
		Values.PAINTER: return "Pintor"
		Values.GUITARIST: return "Guitarrista"
		Values.TRIATHLETE_BIKE: return "Triatleta"
		Values.TRIATHLETE_RUN: return "Triatleta"
		Values.TRIATHLETE_SWIM: return "Triatleta"
		Values.BATTLE_GIRL: return "Luchadora"
		Values.AROMA_LADY: return "Aristócrata"
		Values.RUIN_MANIAC: return "Ruinamaníaco"
		Values.NINJA_BOY: return "Ninja"
		
		# Líderes
		Values.GYM_LEADER_BROCK: return "Líder de Gimnasio"
		Values.GYM_LEADER_MISTY: return "Líder de Gimnasio"
		Values.GYM_LEADER_LT_SURGE: return "Líder de Gimnasio"
		Values.GYM_LEADER_ERIKA: return "Líder de Gimnasio"
		Values.GYM_LEADER_KOGA: return "Líder de Gimnasio"
		Values.GYM_LEADER_SABRINA: return "Líder de Gimnasio"
		Values.GYM_LEADER_BLAINE: return "Líder de Gimnasio"
		Values.GYM_LEADER_GIOVANNI: return "Líder de Gimnasio"
		
		# Alto Mando
		Values.ELITE_FOUR_LORELEI: return "Alto Mando"
		Values.ELITE_FOUR_BRUNO: return "Alto Mando"
		Values.ELITE_FOUR_AGATHA: return "Alto Mando"
		Values.ELITE_FOUR_LANCE: return "Alto Mando"
		Values.CHAMPION_BLUE: return "Campeón"
		
		# Especiales
		Values.RIVAL: return "Rival"
		Values.TEAM_ROCKET_BOSS: return "Jefe Rocket"
		Values.POKEMON_TRAINER: return "Entrenador Pokémon"
		
		# Custom
		Values.CUSTOM: return "Entrenador"
		
		_: return "Entrenador"
