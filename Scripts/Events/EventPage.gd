extends Resource
class_name EventPage

## Modo de ejecución de la página: en cola (QUEUED) o paralelo (PARALLEL)
enum ExecutionMode { QUEUED, PARALLEL }

@export var execution_mode: ExecutionMode = ExecutionMode.QUEUED

@export var trigger_type: EventTriggers.TriggerType = EventTriggers.TriggerType.ACTION
@export var commands: Array[EventCommand] = []
@export var blocks_player: bool = true
@export var through: bool = false
@export var sprite_frames: SpriteFrames = null
