extends Resource
class_name EventPage

@export var trigger_type: EventTriggers.TriggerType = EventTriggers.TriggerType.ACTION
@export var commands: Array[EventCommand] = []
@export var blocks_player: bool = true
@export var through: bool = false
