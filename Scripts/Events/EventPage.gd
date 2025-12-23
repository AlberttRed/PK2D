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
## Condición raíz del árbol de condiciones (opcional)
## Si está definida, se usa en lugar del sistema legacy (conditions array)
## Permite expresiones lógicas anidadas complejas (AND/OR/NOT)
@export var root_condition: EventCondition = null

## [LEGACY] Array de condiciones basadas en Resources (EventCondition)
## Se usa solo si root_condition es null
## Cada condición se evalúa en tiempo de ejecución para determinar si la página está activa
@export var conditions: Array[EventCondition] = []

## [LEGACY] Modo de evaluación de condiciones: ALL (todas deben cumplirse) o ANY (al menos una)
## Se usa solo si root_condition es null
enum ConditionMode { ALL, ANY }
@export var condition_mode: ConditionMode = ConditionMode.ALL

@export_group("Movement (NPC)")
## Tipo de movimiento del NPC (solo para NPCs)
@export_enum("None", "Random", "Path", "RandomTurning", "LookPattern") var movement_type: int = 0

## Comportamiento de orientación al interactuar (solo para NPCs)
@export_enum("Face Player", "Fixed", "Face and Restore") var orientation_behavior: int = 0

## Dirección inicial del NPC (solo para NPCs)
@export_enum("Up", "Down", "Left", "Right") var initial_direction: int = 1  # 1 = Down

## Velocidad de movimiento del NPC (solo para NPCs)
@export_enum("Slowest", "Slower", "Normal", "Faster", "Fastest") var movement_speed: int = 2  # 2 = Normal

## Referencia al Event de origen (no exportada, solo runtime)
## Se asigna cuando se duplica la página desde un Event
var source_event: Event = null

# Sistema de sprites
@export_group("Sprite Configuration")

## Recurso ActorStyle que define el set completo de animaciones para esta página
@export var actor_style: ActorStyle = null

## Textura del sprite (para spritesheets 4x4 de NPCs)
@export var sprite_texture: Texture2D = null

## Si está activado, genera automáticamente animaciones desde el spritesheet 4x4
## Si está desactivado, la textura se usa como imagen simple estática
@export var is_spritesheet: bool = false

## Tamaño de cada frame en el spritesheet (solo si is_spritesheet = true)
@export var frame_size := Vector2(32, 48)

## SpriteFrames manual para casos personalizados
@export var sprite_frames: SpriteFrames = null

## Si true, este evento mostrará reflejo en el agua cuando esté sobre tiles de agua
@export var has_water_reflection: bool = false

## Obtiene los SpriteFrames (generados automáticamente o asignados manualmente)
func get_sprite_frames() -> SpriteFrames:
	if actor_style:
		return null
	if sprite_texture and is_spritesheet:
		return SpriteFramesGenerator.generate_from_4x4_spritesheet(sprite_texture, frame_size)
	if sprite_frames:
		return sprite_frames
	if sprite_texture:
		return _generate_simple_sprite_frames(sprite_texture)
	return null

## Genera un SpriteFrames simple con una sola animación "default" y un frame
func _generate_simple_sprite_frames(texture: Texture2D) -> SpriteFrames:
	if not texture:
		return null

	var frames = SpriteFrames.new()

	# SpriteFrames.new() ya crea una animación "default" por defecto
	# Si no existe, la añadimos; si existe, solo la configuramos
	if not frames.has_animation("default"):
		frames.add_animation("default")

	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", 5.0)

	# Limpiar frames existentes si los hay y añadir el nuestro
	frames.clear("default")
	frames.add_frame("default", texture)

	return frames


## Evalúa si las condiciones de esta página se cumplen
## Retorna true si la página puede activarse
func evaluate_conditions(event_id: String = "") -> bool:
	# Crear el contexto de evaluación
	var context = EventConditionContext.new(event_id, GameStateService)

	# Prioridad: usar root_condition si está definido
	if root_condition:
		return root_condition.evaluate(context)

	# Fallback: usar sistema legacy (conditions array)
	if conditions.size() == 0:
		return true

	# Evaluar según el modo (ALL o ANY)
	match condition_mode:
		ConditionMode.ALL:
			# Todas las condiciones deben cumplirse
			for condition in conditions:
				if not condition or not condition.evaluate(context):
					return false
			return true
		ConditionMode.ANY:
			# Al menos una condición debe cumplirse
			for condition in conditions:
				if condition and condition.evaluate(context):
					return true
			return false
		_:
			return true


## Retorna true si esta página tiene alguna condición configurada
func has_conditions() -> bool:
	# Verificar si tiene root_condition
	if root_condition:
		return true

	# Verificar sistema legacy
	return conditions.size() > 0


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
