extends Resource
class_name EventPage

## Modo de ejecución de la página: en cola (QUEUED) o paralelo (PARALLEL)
enum ExecutionMode { QUEUED, PARALLEL }

## Nombre personalizado de la página (opcional)
## Si está vacío, se usa "Página" por defecto
@export var page_name: String = ""

@export var execution_mode: ExecutionMode = ExecutionMode.QUEUED

## Trigger que define cuándo se activa esta página
## Si es null, se usa un ActionTrigger por defecto
@export var trigger: EventTrigger = null

@export var commands: Array[EventCommand] = []
## Condición raíz del árbol de condiciones
## Permite expresiones lógicas anidadas complejas (AND/OR/NOT)
@export var root_condition: EventCondition = null
@export var blocks_player: bool = true
@export var through: bool = false

@export_group("Trainer Detection")
## Si true, activa la detección de trainer cuando esta página está activa
## SOLO funciona si el Event es de tipo Trainer
@export var enable_trainer_detection: bool = false

## Rango de detección en tiles (solo si enable_trainer_detection = true)
@export_range(1, 10) var detection_range: int = 5



@export_group("Movement (NPC)")
## Tipo de movimiento del NPC (solo para NPCs)
@export_enum("None", "Random", "Path", "RandomTurning", "LookPattern", "RandomVertical", "RandomHorizontal") var movement_type: int = 0

## Comportamiento de orientación al interactuar (solo para NPCs)
@export_enum("Face Player", "Fixed", "Face and Restore") var orientation_behavior: int = 0

## Dirección inicial del NPC (solo para NPCs)
@export_enum("Up", "Down", "Left", "Right") var initial_direction: int = 1  # 1 = Down

## Velocidad de movimiento del NPC (solo para NPCs)
@export_enum("Slowest", "Slower", "Normal", "Faster", "Fastest") var movement_speed: int = 2  # 2 = Normal

## Si true, preserva la dirección actual cuando cambia de página y no hay cambio de sprite
## Útil para mantener la dirección después de interactuar (ej: NPC mirando hacia el jugador)
@export var preserve_direction_on_sprite_match: bool = false

@export_group("Random Movement (NPC)")
## Tiempo mínimo entre movimientos aleatorios (en segundos)
@export var random_move_interval_min: float = 2.0
## Tiempo máximo entre movimientos aleatorios (en segundos)
@export var random_move_interval_max: float = 5.0

@export_group("Path Movement (NPC)")
## Array de direcciones a seguir en bucle (UP, DOWN, LEFT, RIGHT, LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT)
@export var path_directions: Array[DirectionEnum.Type] = []

@export_group("Look Pattern (NPC)")
## Array de direcciones de mirada a seguir en bucle (LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT)
@export var look_pattern_directions: Array[DirectionEnum.Type] = []
## Tiempo en segundos que el NPC mira en cada dirección antes de cambiar
@export var look_pattern_delay: float = 2.0

@export_group("Random Turning (NPC)")
## Intervalo mínimo entre giros aleatorios
@export var random_turning_interval_min: float = 2.0
## Intervalo máximo entre giros aleatorios
@export var random_turning_interval_max: float = 5.0

@export_group("Player Awareness (NPC)")
## Si está activo, el NPC puede detectar y girar hacia el jugador
@export var awareness_enabled: bool = false
## Probabilidad base de girar hacia el jugador (0.0 a 1.0)
@export var awareness_chance: float = 0.3
## Multiplicador de probabilidad cuando el jugador corre
@export var awareness_running_multiplier: float = 2.0
## Distancia máxima para detectar al jugador (en tiles)
@export var awareness_detection_distance: float = 3.0

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

## Tamaño de cada frame del sprite (usado para spritesheets y para indicar el tamaño del sprite)
@export var frame_size := Vector2(32, 48)

## Offset del sprite (ajuste de posición, útil para centrar sprites en el tile)
## Para NPCs, el valor por defecto visual es (0, -8), pero se guarda como (0, 0) si no se modifica
@export var sprite_offset := Vector2(0, 0)
## Indica si el offset ha sido configurado explícitamente por el usuario
## Si es false y sprite_offset es (0, 0), los NPCs aplicarán (0, -8) por defecto
@export var sprite_offset_configured: bool = false

## Animación inicial a mostrar (solo para eventos normales, no NPCs)
## Si está vacío, se usa "idle" por defecto, o la primera animación disponible
@export var initial_animation: String = "idle"
## Frame inicial a mostrar dentro de la animación (solo para eventos normales, no NPCs)
## Por defecto es 0 (primer frame)
@export var initial_frame: int = 0

## SpriteFrames manual para casos personalizados
@export var sprite_frames: SpriteFrames = null

## Si true, este evento mostrará reflejo en el agua cuando esté sobre tiles de agua
@export var has_water_reflection: bool = false

## Obtiene los SpriteFrames (generados automáticamente o asignados manualmente)
## event_node: Nodo Event opcional para detectar si es NPC y generar animaciones apropiadas
func get_sprite_frames(event_node: Node = null) -> SpriteFrames:
	if actor_style:
		return null
	if sprite_texture and is_spritesheet:
		return SpriteFramesGenerator.generate_from_4x4_spritesheet(sprite_texture, frame_size)
	if sprite_frames:
		return sprite_frames
	if sprite_texture:
		# Si es un NPC y no es spritesheet, generar frames con animaciones de NPC
		if event_node:
			var script = event_node.get_script()
			if script and script.resource_path.ends_with("NPC.gd"):
				return _generate_npc_sprite_frames(sprite_texture, frame_size)
			elif event_node.has_method("get_movement_type"):
				return _generate_npc_sprite_frames(sprite_texture, frame_size)
		# Para eventos normales, generar frames simples
		return _generate_simple_sprite_frames(sprite_texture, frame_size)
	return null

## Genera un SpriteFrames simple con una sola animación "default" y un frame
## frame_size: Tamaño del frame (puede usarse para información o ajustes)
func _generate_simple_sprite_frames(texture: Texture2D, frame_size: Vector2 = Vector2(32, 48)) -> SpriteFrames:
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

## Genera SpriteFrames para NPCs con todas las animaciones necesarias
## usando la misma textura para todos los frames
## frame_size: Tamaño del frame (puede usarse para información o ajustes)
func _generate_npc_sprite_frames(texture: Texture2D, frame_size: Vector2 = Vector2(32, 48)) -> SpriteFrames:
	if not texture:
		return null

	var frames = SpriteFrames.new()

	# Animación "idle" con 4 frames (uno para cada dirección)
	# ActorAnimator.idle() espera: frame 0=down, 1=left, 2=right, 3=up
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 5.0)
	for i in range(4):
		frames.add_frame("idle", texture)

	# Animaciones walk y run para cada dirección
	var directions = ["down", "left", "right", "up"]
	for dir in directions:
		for stride in ["left", "right"]:
			# walk
			var walk_anim = "walk_%s_%s" % [dir, stride]
			frames.add_animation(walk_anim)
			frames.set_animation_loop(walk_anim, false)
			frames.set_animation_speed(walk_anim, 7.5)
			frames.add_frame(walk_anim, texture)
			frames.add_frame(walk_anim, texture)

			# run (mismos frames, más rápido)
			var run_anim = "run_%s_%s" % [dir, stride]
			frames.add_animation(run_anim)
			frames.set_animation_loop(run_anim, false)
			frames.set_animation_speed(run_anim, 10.0)
			frames.add_frame(run_anim, texture)
			frames.add_frame(run_anim, texture)

	return frames


## Evalúa si las condiciones de esta página se cumplen
## Retorna true si la página puede activarse
func evaluate_conditions(event_id: String = "") -> bool:
	# Crear el contexto de evaluación
	var context = EventConditionContext.new(event_id, GameStateService)

	# Si no hay root_condition, la página siempre se puede activar
	if not root_condition:
		return true

	return root_condition.evaluate(context)


## Retorna true si esta página tiene alguna condición configurada
func has_conditions() -> bool:
	return root_condition != null

## Verifica si esta página depende de una variable global específica
## Retorna true si alguna condición de la página usa la variable
func depends_on_variable(variable_name: String) -> bool:
	if not root_condition:
		return false
	return root_condition.depends_on_variable(variable_name)

## Verifica si esta página depende de un flag global específico
## Retorna true si alguna condición de la página usa el flag
func depends_on_flag(flag_name: String) -> bool:
	if not root_condition:
		return false
	return root_condition.depends_on_flag(flag_name)


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


## Obtiene el trigger efectivo de esta página
## Si trigger es null, retorna un ActionTrigger por defecto
func get_effective_trigger() -> EventTrigger:
	if trigger != null:
		return trigger

	# Si no hay trigger asignado, usar ActionTrigger por defecto
	# Crear una instancia temporal (no se guarda en el Resource)
	var default_trigger = ActionTrigger.new()
	return default_trigger
