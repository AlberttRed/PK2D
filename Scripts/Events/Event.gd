extends Node2D
class_name Event

signal event_triggered(page)

##Lista de páginas de evento (EventPage) que puede ejecutar el vento, cada una con su lista de comandos (EventCommand) definida.
@export var pages: Array[EventPage] = []
@export var current_page_index: int = 0

var current_page: Resource = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	setup_current_page()
	hide_default_sprite_if_needed()
	
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
	
	# Actualizar el sprite según la página activa
	update_sprite_from_current_page()

## Actualiza el sprite del evento según la página activa
func update_sprite_from_current_page() -> void:
	if not sprite:
		return
	
	if current_page and current_page.sprite_frames:
		sprite.sprite_frames = current_page.sprite_frames
	else:
		# Si no hay página activa o no tiene sprite, usar sprite por defecto
		# Esto se puede personalizar según tus necesidades
		sprite.sprite_frames = null
	
	# Revisar si necesita ocultar el sprite por defecto
	hide_default_sprite_if_needed()

func trigger() -> void:
	if current_page:
		print("Event '%s' triggered!" % name)
		event_triggered.emit(current_page)
		
		# Emitir señal global para solicitar ejecución del evento
		SignalManager.event_requested.emit(self, null)

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

## Oculta el sprite si está usando la imagen por defecto (solo visible en editor)
func hide_default_sprite_if_needed() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	
	# Verificar si está usando el sprite por defecto
	var is_using_default_sprite = is_using_default_event_sprite()
	
	if is_using_default_sprite:
		# Ocultar el sprite durante la ejecución del juego
		sprite.visible = false
		print("Event '%s': Sprite por defecto ocultado en ejecución" % name)

## Verifica si el evento está usando el sprite por defecto
func is_using_default_event_sprite() -> bool:
	if not sprite or not sprite.sprite_frames:
		return false
	
	# Obtener la ruta del sprite actual
	var current_sprite_path = sprite.sprite_frames.resource_path
	
	# Verificar si coincide con el sprite por defecto
	var default_sprite_path = "res://Sprites/Eventos/DefaultEventSprite.png"
	
	# También verificar por el nombre del recurso
	if current_sprite_path.find("DefaultEventSprite") != -1:
		return true
	
	# Verificar si la primera animación usa la textura por defecto
	if sprite.sprite_frames.has_animation("default"):
		var frame_count = sprite.sprite_frames.get_frame_count("default")
		if frame_count > 0:
			var frame_texture = sprite.sprite_frames.get_frame_texture("default", 0)
			if frame_texture and frame_texture.resource_path == default_sprite_path:
				return true
	
	return false

## Permite mostrar temporalmente el sprite del evento (útil para eventos que cambian de apariencia)
func show_sprite() -> void:
	if sprite:
		sprite.visible = true

## Permite ocultar el sprite del evento
func hide_sprite() -> void:
	if sprite:
		sprite.visible = false

## Restablece la visibilidad del sprite según si es por defecto o no
func reset_sprite_visibility() -> void:
	if is_using_default_event_sprite():
		sprite.visible = false
	else:
		sprite.visible = true

## Cambia a una página específica del evento
func switch_to_page(page_index: int) -> void:
	if page_index >= 0 and page_index < pages.size():
		current_page_index = page_index
		setup_current_page()
		print("Event '%s': Cambiado a página %d" % [name, page_index])

## Cambia al siguiente página del evento
func next_page() -> void:
	var next_index = current_page_index + 1
	if next_index < pages.size():
		switch_to_page(next_index)
	else:
		print("Event '%s': No hay más páginas disponibles" % name)

## Cambia a la página anterior del evento
func previous_page() -> void:
	var prev_index = current_page_index - 1
	if prev_index >= 0:
		switch_to_page(prev_index)
	else:
		print("Event '%s': Ya está en la primera página" % name)

func _to_string() -> String:
	return name
