extends Camera2D
class_name OverworldCamera

@export var use_camera_limits := true
@export var map_layer_path: NodePath  # Capa de referencia del mapa

var target: Node2D

func _ready():
	enabled = true
	if map_layer_path != NodePath() and use_camera_limits:
		var ref = get_node(map_layer_path) as TileMapLayer
		if ref:
			var used = ref.get_used_rect()
			var tile_size = ref.tile_set.tile_size
			limit_left = used.position.x * tile_size.x
			limit_top = used.position.y * tile_size.y
			limit_right = (used.position.x + used.size.x) * tile_size.x
			limit_bottom = (used.position.y + used.size.y) * tile_size.y
