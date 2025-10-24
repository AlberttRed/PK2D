## Clase TrainerData
## 
## Resource que define los datos completos de un entrenador.
## Se guarda como .tres en Resources/Trainers/ para reutilización.
##
## Uso:
##   var trainer_data = preload("res://Resources/Trainers/brock.tres")
##   battler.trainer_data = trainer_data
extends Resource
class_name TrainerData

## === IDENTIFICACIÓN ===

## ID único del entrenador (para tracking de derrotas, rematches, etc.)
@export var trainer_id: int = 0

## Clase del entrenador (usa el enum, se cargará el TrainerClassData automáticamente)
@export var trainer_class_id: TrainerClassEnum.Values = TrainerClassEnum.Values.POKEMON_TRAINER

## Nombre para mostrar en combate y diálogos
@export var display_name: String = "Entrenador"

# Propiedades calculadas (se cargan automáticamente)
var trainer_class: TrainerClassData  # Se carga desde trainer_class_id

## === SPRITES Y VISUAL ===

## Sprite del entrenador para combate (vista frontal - enemigo)
@export var battle_front_sprite: Texture2D = null

## Sprite del entrenador para combate (vista trasera - jugador/aliado)
@export var battle_back_sprite: Texture2D = null

## === INTELIGENCIA ARTIFICIAL ===

## Perfil de IA para el combate (null = IA por defecto)
@export var ai_profile: BattleIA = null

## === TEXTOS DE COMBATE ===

## Texto de introducción antes del combate
@export_multiline var intro_text: String = "¡Vamos a combatir!"

## Texto al perder el combate
@export_multiline var defeat_text: String = "He perdido..."

## Texto al ganar el combate (usado para rival/eventos especiales)
@export_multiline var victory_text: String = "¡Gané!"

## === EQUIPO POKÉMON ===

## Equipo del entrenador como Array de Pokemon
## Configura Pokemon directamente desde el inspector con nivel, IVs, movimientos, etc.
@export var party_data: Array[Pokemon] = []


## === CONFIGURACIÓN DE COMBATE ===

## Si true, el entrenador puede hacer combates dobles
@export var double_battle: bool = false

## Cantidad de dinero que da al ganar
@export var reward_money: int = 1000

## === OTROS ===

## Items que puede usar en combate (futuro)
@export var battle_items: Array[int] = []

## Si true, el entrenador ya fue derrotado (para tracking)
var is_defeated: bool = false

## Si true, este entrenador puede hacer rematches
@export var can_rematch: bool = false

## Nivel de rematch (si aumentan los niveles en rematch)
@export var rematch_level_bonus: int = 0

## === MÉTODOS ÚTILES ===

## Inicializa el TrainerData (carga el TrainerClassData desde el enum)
## Llamar esto después de crear/cargar el TrainerData
func initialize() -> void:
	# Cargar TrainerClassData desde el enum (DatabaseManager o directorio)
	# Por ahora, creamos uno temporal hasta que existan los .tres
	_load_trainer_class()

## Carga el TrainerClassData desde el enum ID
func _load_trainer_class() -> void:
	# Intentar cargar desde DatabaseManager
	trainer_class = DatabaseManager.get_trainer_class(trainer_class_id)


## Retorna el equipo (ya están configurados como Pokemon desde el inspector)
func create_party() -> Array[Pokemon]:
	# Los Pokemon ya están listos, solo aseguramos que tengan los datos del entrenador
	for pokemon in party_data:
		if pokemon:
			pokemon.trainer_id = trainer_id
			pokemon.original_trainer = display_name
	
	return party_data

## Retorna el nombre completo (clase + nombre)
func get_full_name() -> String:
	if trainer_class:
		return "%s %s" % [trainer_class.display_name, display_name]
	else:
		return display_name

## Retorna el sprite frontal (prioridad: trainer → clase → null)
func get_battle_front_sprite() -> Texture2D:
	if battle_front_sprite != null:
		return battle_front_sprite
	if trainer_class and trainer_class.default_battle_front_sprite != null:
		return trainer_class.default_battle_front_sprite
	return null

## Retorna el sprite trasero (prioridad: trainer → clase → null)
func get_battle_back_sprite() -> Texture2D:
	if battle_back_sprite != null:
		return battle_back_sprite
	if trainer_class and trainer_class.default_battle_back_sprite != null:
		return trainer_class.default_battle_back_sprite
	return null

## Retorna el texto de intro formateado
func get_intro_message() -> String:
	return intro_text.replace("{player}", "Jugador")  # Placeholder para nombre del jugador

## Retorna el texto de derrota formateado
func get_defeat_message() -> String:
	return defeat_text

## Retorna el texto de victoria formateado
func get_victory_message() -> String:
	return victory_text

## Calcula la recompensa de dinero según el equipo y la clase
func calculate_reward() -> int:
	# Si hay reward_money específico, usarlo
	if reward_money > 0:
		return reward_money
	
	# Si no, calcular según clase y nivel promedio del equipo
	if trainer_class and not party_data.is_empty():
		var total_level = 0
		for pokemon in party_data:
			if pokemon:
				total_level += pokemon.level
		var avg_level = int(float(total_level) / float(party_data.size()))
		return trainer_class.calculate_base_reward(avg_level)
	
	return 1000  # Recompensa por defecto

## Verifica si el entrenador tiene un equipo válido
func has_valid_party() -> bool:
	return not party_data.is_empty() and party_data[0] != null

## Debug: imprime información del entrenador
func print_trainer_info() -> void:
	print("=== Entrenador: %s ===" % get_full_name())
	print("ID: %d" % trainer_id)
	print("Equipo: %d Pokémon" % party_data.size())
	print("Dinero: $%d" % reward_money)
	print("Combate doble: %s" % ("Sí" if double_battle else "No"))
	print("========================")
