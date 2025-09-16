extends Node2D
class_name Event

signal event_triggered(page)

@export var event_name: String = "Event"

##Lista de páginas de evento (EventPage) que puede ejecutar el vento, cada una con su lista de comandos (EventCommand) definida.
@export var pages: Array[EventPage] = []
@export var current_page_index: int = 0

## Indica si el Event ocupa espacio dentro del gird, por lo que puede bloquear el movimiento a otros actores del mapa
@export var blocks_movement: bool = true
var current_page: Resource = null

# Aquí exponemos el SpriteFrames que usará el AnimatedSprite2D hijo
@export var sprite_frames: SpriteFrames:
	set(value):
		sprite_frames = value
		if $AnimatedSprite2D:
			$AnimatedSprite2D.sprite_frames = value

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	setup_current_page()
	
	# Autorun inmediato
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.AUTORUN:
		trigger()

## Configura current_page basado en current_page_index y pages
func setup_current_page() -> void:
	if pages.size() == 0:
		current_page = null
	elif current_page_index >= 0 and current_page_index < pages.size():
		current_page = pages[current_page_index]
	else:
		current_page_index = 0
		if pages.size() > 0:
			current_page = pages[0]
		else:
			current_page = null

func trigger() -> void:
	if current_page:
		print("Event '%s' triggered!" % event_name)
		event_triggered.emit(current_page)
		
		# Delegar ejecución al EventSystem
		EventSystem.start_event(self)

func on_player_action() -> void:
	# Si el jugador pulsa "A" frente al evento
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.ACTION:
		print("Interact!")
		trigger()

func on_player_touch() -> void:
	# Si el jugador entra en la misma celda
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.TOUCH:
		print("Touched!")
		trigger()

func _to_string() -> String:
	return name
