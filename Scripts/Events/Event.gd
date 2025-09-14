extends Node2D
class_name Event

signal event_triggered(page)

@export var event_name: String = "Event"

##Lista de páginas de evento (EventPage) que puede ejecutar el vento, cada una con su lista de comandos (EventCommand) definida.
@export var pages: Array[EventPage] = []
@export var current_page_index: int = 0:
	set(value):
		set_current_page(value)

## Indica si el Event ocupa espacio dentro del gird, por lo que puede bloquear el movimiento a otros actores del mapa
@export var blocks_movement: bool = true
var current_page: Resource = null
@onready var grid: OverworldGrid = get_tree().get_first_node_in_group("OverworldGrid")

# Aquí exponemos el SpriteFrames que usará el AnimatedSprite2D hijo
@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		if $AnimatedSprite2D:
			$AnimatedSprite2D.sprite_frames = value

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if pages.size() > 0:
		set_current_page(0)

	# Snap al grid y registrar ocupación si corresponde
	var tile := grid.world_to_tile(global_position)
	if blocks_movement:
		grid.occupy(tile, self)

	# Autorun inmediato
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.AUTORUN:
		trigger()

func set_current_page(index: int) -> void:
	if index >= 0 and index < pages.size():
		current_page_index = index
		current_page = pages[index]
	else:
		current_page_index = -1
		current_page = null

func trigger() -> void:
	if current_page:
		event_triggered.emit(current_page)

## --- Helpers ---
func get_tile() -> Vector2i:
	return grid.world_to_tile(global_position)

func on_player_action() -> void:
	# Si el jugador pulsa "A" frente al evento
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.ACTION:
		trigger()

func on_player_touch() -> void:
	# Si el jugador entra en la misma celda
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.TOUCH:
		trigger()
