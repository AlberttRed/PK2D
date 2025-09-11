class_name BattleRules

enum BattleTypes {
	NONE,
	WILD,
	TRAINER
}

enum BattleModes {
	NONE,
	SINGLE,
	DOUBLE,
	TRIPLE
}

enum BattleEnvironments {
	FIELD,
	GRASS,
	CAVE,
	WATER
}

enum BattleTime {
	DAY,
	NIGHT,
	MORNING,
	AFTERNOON,
	EVENING
}

enum BattleWeather {
	NONE,
	SOLEADO = 1,
	SOL_ABRASADOR = 2,
	LLUVIOSO = 3,
	DILUVIO = 4,
	TORM_ARENA = 5,
	GRANIZO = 6,
	NIEBLA = 7,
	TURBULENCIAS = 8,
	LLUVIA_DIAMANTES = 9
}

var type : BattleTypes = BattleTypes.NONE # Indica si es un combat contra pokémon Salvatge o un Entrenador
var mode : BattleModes = BattleModes.NONE # Indica si es un combat individual, doble o triple (triple de moment no es tindrà en compte)
var weather : BattleWeather = BattleWeather.NONE
var time : BattleTime = BattleTime.DAY
var environment : BattleEnvironments = BattleEnvironments.GRASS

func _init(_battleType : BattleTypes, _battleMode : BattleModes, _weather : BattleWeather = BattleWeather.NONE, _time : BattleTime = BattleTime.DAY, _environment : BattleEnvironments = BattleEnvironments.GRASS):
	type = _battleType
	mode = _battleMode
	weather = _weather
	time = _time
	environment = _environment

func queue_free():
	free()
