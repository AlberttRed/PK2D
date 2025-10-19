extends Resource
class_name EventPage

## Modo de ejecución de la página: en cola (QUEUED) o paralelo (PARALLEL)
enum ExecutionMode { QUEUED, PARALLEL }

@export var execution_mode: ExecutionMode = ExecutionMode.QUEUED

@export var trigger_type: EventTriggers.TriggerType = EventTriggers.TriggerType.ACTION
@export var commands: Array[EventCommand] = []
@export var blocks_player: bool = true
@export var through: bool = false

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
