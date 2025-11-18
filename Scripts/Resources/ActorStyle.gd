extends Resource
class_name ActorStyle

@export var walk_frames: SpriteFrames
@export var run_frames: SpriteFrames
@export var surf_frames: SpriteFrames

@export var mo_start_frames: SpriteFrames
@export var mo_end_frames: SpriteFrames

@export var surf_jump_frames: SpriteFrames

@export var bike_frames: SpriteFrames

@export var extra_animations: Dictionary[String, SpriteFrames] = {}
