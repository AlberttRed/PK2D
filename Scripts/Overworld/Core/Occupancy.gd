extends Node
class_name Occupancy

@onready var actor := get_parent() as Node2D
@onready var grid: OverworldGrid = get_tree().get_first_node_in_group("OverworldGrid")

func _ready() -> void:
	# Snap al centro de tile y registra ocupación inicial
	var tile := grid.world_to_tile(actor.global_position)
	actor.global_position = grid.tile_to_world_center(tile)
	grid.occupy(tile, actor)

## Si en algún momento teletransportas:
func teleport_to_tile(t: Vector2i) -> void:
	var cur := grid.world_to_tile(actor.global_position)
	grid.vacate(cur, actor)
	actor.global_position = grid.tile_to_world_center(t)
	grid.occupy(t, actor)
