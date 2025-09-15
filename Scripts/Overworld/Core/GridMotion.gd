extends Node
class_name GridMotion

signal step_started()
signal step_finished(tile: Vector2i)

## Duración base de un paso (en segundos)
@export var step_duration := 0.266
@export var initial_delay := 0.12  # tiempo que hay que mantener pulsado antes de moverse

## Multiplicador de velocidad (1 = normal, 2 = correr, 0.5 = ralentizado…)
var speed_multiplier := 1.0

var hold_time:float
var moving := false
var dir := Vector2.DOWN
var previous_dir := dir

@onready var actor := get_parent() as Node2D
@onready var grid: OverworldGrid = get_tree().get_first_node_in_group("OverworldGrid")

func get_step_duration() -> float:
	return step_duration / speed_multiplier

##Gets de speed scale that will be used to move and animate the actor when moving
func get_speed_multiplier(d: Vector2, can_step: bool, initial_step: bool) -> float:
	if initial_step:
		return 1.0
	if Input.is_action_pressed("run") and can_step:
		return 2.0
	if not can_step:
		return 0.5
	return 1.0


func current_tile() -> Vector2i:
	return grid.world_to_tile(actor.global_position)

func face(d: Vector2) -> void:
	if d != Vector2.ZERO:
		self.previous_dir = dir
		self.dir = d

func try_step(d: Vector2) -> bool:
	if moving or d == Vector2.ZERO:
		return false
	face(d)
	
	var from := current_tile()
	var to := from + Vector2i(d)
	var can_step := grid.can_step_to(actor, from, to)
	var initial_step := requires_initial_step(d)

	speed_multiplier = get_speed_multiplier(d, can_step, initial_step)
	
	step_started.emit()

	#If cannot move to next tile, or trying a first quick tap to another direction when idle, stay in same position
	if not can_step or requires_initial_step(d):
		to = from

	moving = true
	grid.reserve(from, to, actor)

	var target := grid.tile_to_world_center(to)
	
	if to == from:
		await get_tree().create_timer(get_step_duration()).timeout
	else:
		var t := actor.create_tween()
		t.tween_property(actor, "global_position", target, get_step_duration())
		await t.finished

	grid.commit(from, to, actor)
	moving = false
	
	step_finished.emit(to)

	await grid.on_enter_tile(actor, to)
	return true
	
func event_at_offset(offset: int = 1) -> Event:
	# offset = 1 → el tile de delante
	# offset = 2 → dos tiles más adelante
	# offset = -1 → el tile de detrás
	print(current_tile())
	var target_tile = current_tile() + Vector2i(dir) * offset
	print(target_tile)
	return grid.event_at(target_tile)

func event_in_front() -> Event:
	return event_at_offset(1)

##Checks if actor need to do the first step animation before moving
func requires_initial_step(dir:Vector2) -> bool:
	return (dir != previous_dir and self.hold_time < initial_delay)
