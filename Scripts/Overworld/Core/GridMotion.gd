extends Node
class_name GridMotion

signal step_started()
signal step_finished(tile: Vector2i)

@export var step_duration := 0.266
@export var initial_delay := 0.12  # tiempo que hay que mantener pulsado antes de moverse
var hold_time:float

var moving := false
var dir := Vector2.DOWN
var previous_dir := dir

@onready var actor := get_parent() as Node2D
@onready var grid: OverworldGrid = get_tree().get_first_node_in_group("OverworldGrid")

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
	step_started.emit()
	
	var from := current_tile()
	var to := from + Vector2i(d)
	
	#If cannot move to next tile, or trying a first quick tap to another direction when idle, stay in same position
	if not grid.can_step_to(actor, from, to) or (d != previous_dir and self.hold_time < initial_delay):
		to = from

	moving = true
	grid.reserve(from, to, actor)

	var target := grid.tile_to_world_center(to)
	
	if to == from:
		await get_tree().create_timer(step_duration).timeout
	else:
		var t := actor.create_tween()
		t.tween_property(actor, "global_position", target, step_duration)
		await t.finished

	grid.commit(from, to, actor)
	moving = false
	
	step_finished.emit(to)

	await grid.on_enter_tile(actor, to)
	return true
