extends Sprite2D

@export var Tipus: int = 1
@export var EncounterTile: bool = true
@export var EncounterArea : int = 1

var EnterDirections: Array = []
var ExitDirections: Array = []

var body

@onready var anim_player = $AnimationPlayer
@onready var timer = $Timer

const grass_overlay_texture = preload("res://Sprites/Others/Stepped_Tall_Grass.png")
const GrassEffect = preload("res://Objetos/Animaciones/GrassEffect.tscn")
var grass_overlay: Sprite2D = null

var player_inside: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	#get_tree().current_scene.get_node("Player")
	GLOBAL.PLAYER.connect("moving_signal", Callable(self, "player_exiting_grass"))
	GLOBAL.PLAYER.connect("moved_signal", Callable(self, "player_in_grass"))

func player_exiting_grass():
	player_inside = false
	timer.start()
	
func player_in_grass():
	if player_inside:
		var grass_effect = GrassEffect.instantiate()
		grass_effect.position = global_position
		get_tree().current_scene.add_child(grass_effect)
		
		if !is_instance_valid(grass_overlay):
			grass_overlay = Sprite2D.new()
			grass_overlay.texture = grass_overlay_texture
			grass_overlay.z_index = 2
			grass_overlay.position = global_position
			get_tree().current_scene.add_child(grass_overlay)
		
func get_custom_data(n):
	return get(n)



func _on_area_2d_body_entered(_body):
	body = _body
	player_inside = true
	anim_player.play("Stepped")


func _on_timer_timeout():
	if is_instance_valid(grass_overlay):
		grass_overlay.queue_free()
