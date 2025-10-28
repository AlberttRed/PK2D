extends Resource
class_name EventPage

## Modo de ejecución de la página: en cola (QUEUED) o paralelo (PARALLEL)
enum ExecutionMode { QUEUED, PARALLEL }

@export var execution_mode: ExecutionMode = ExecutionMode.QUEUED

@export var trigger_type: EventTriggers.TriggerType = EventTriggers.TriggerType.ACTION
@export var commands: Array[EventCommand] = []
@export var blocks_player: bool = true
@export var through: bool = false

@export_group("Trainer Detection")
## Si true, activa la detección de trainer cuando esta página está activa
## SOLO funciona si el Event es de tipo Trainer
@export var enable_trainer_detection: bool = false

## Rango de detección en tiles (solo si enable_trainer_detection = true)
@export_range(1, 10) var detection_range: int = 5

@export_group("Conditions")
## Nombre del flag global requerido para activar esta página
## Ejemplo: "route_1_trainer_defeated"
@export var required_flag: String = ""

## Valor que debe tener el flag (true/false)
@export var required_flag_value: bool = true

## Nombre de variable global requerida (futuro)
@export var required_variable: String = ""

## Operador de comparación para la variable (futuro)
@export_enum("==", "!=", ">", "<", ">=", "<=") var variable_operator: int = 0

## Valor que debe tener la variable (futuro)
@export var variable_value: int = 0

## Self-switch requerido (A, B, C, D)
@export_enum("NONE", "A", "B", "C", "D") var required_self_switch: int = 0

## Valor que debe tener el self-switch
@export var required_self_switch_value: bool = true

## Si true, invierte todas las condiciones (NOT)
@export var invert_conditions: bool = false

## Referencia al Event de origen (no exportada, solo runtime)
## Se asigna cuando se duplica la página desde un Event
var source_event: Event = null

# Sistema de sprites: manual o automático
@export var sprite_frames: SpriteFrames = null

@export_group("Auto-generate from Spritesheet")
## Si se asigna, genera automáticamente SpriteFrames desde un spritesheet 4x4
@export var character_spritesheet: Texture2D = null
## Tamaño de cada frame en el spritesheet (ancho x alto en píxeles)
@export var frame_size := Vector2(32, 48)

## Obtiene los SpriteFrames (generados automáticamente o asignados manualmente)
func get_sprite_frames() -> SpriteFrames:
	# Prioridad 1: Si hay spritesheet, generar automáticamente
	if character_spritesheet:
		return SpriteFramesGenerator.generate_from_4x4_spritesheet(character_spritesheet, frame_size)
	# Prioridad 2: Usar el SpriteFrames manual
	elif sprite_frames:
		return sprite_frames
	else:
		return null


## Evalúa si las condiciones de esta página se cumplen
## Retorna true si la página puede activarse
func evaluate_conditions(event_id: String = "") -> bool:
	var result = true
	
	# Evaluar flag global
	if not required_flag.is_empty():
		var flag_value = GameStateManager.get_event_flag(required_flag)
		if flag_value != required_flag_value:
			result = false
	
	# Evaluar variable global (futuro)
	if not required_variable.is_empty():
		var var_value = GameStateManager.get_variable(required_variable)
		var comparison_result = _compare_values(var_value, variable_value, variable_operator)
		if not comparison_result:
			result = false
	
	# Evaluar self-switch
	if required_self_switch > 0:  # 0 = NONE
		var switch_letter = ["A", "B", "C", "D"][required_self_switch - 1]
		var switch_value = GameStateManager.get_self_switch(event_id, switch_letter)
		if switch_value != required_self_switch_value:
			result = false
	
	# Invertir resultado si se configuró
	if invert_conditions:
		result = not result
	
	return result


## Compara dos valores según el operador
func _compare_values(a: int, b: int, operator: int) -> bool:
	match operator:
		0:  # ==
			return a == b
		1:  # !=
			return a != b
		2:  # >
			return a > b
		3:  # <
			return a < b
		4:  # >=
			return a >= b
		5:  # <=
			return a <= b
		_:
			return false


## Busca el primer comando de un tipo específico en esta página
## Retorna el comando o null si no se encuentra
func find_command_of_type(command_type) -> EventCommand:
	for command in commands:
		if command and is_instance_of(command, command_type):
			return command
	return null


## Busca el primer StartBattleEventCommand en esta página
func get_battle_command() -> StartBattleEventCommand:
	return find_command_of_type(StartBattleEventCommand) as StartBattleEventCommand
