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
	
	# Conectar a señales de cambio de estado para reevaluación automática
	_connect_to_state_signals()
	
	# Autorun inmediato
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.AUTORUN:
		trigger()

## Configura current_page basado en current_page_index y pages
## Evalúa condiciones de todas las páginas para encontrar la activa
func setup_current_page() -> void:
	if pages.size() == 0:
		current_page = null
		current_page_index = 0
		update_sprite_from_current_page()
		return
	
	# Obtener ID único del evento para self-switches
	var event_id = _get_event_id()
	
	# Evaluar páginas en orden inverso (prioridad a las últimas)
	# Esto permite tener una página "por defecto" al inicio y páginas condicionales después
	for i in range(pages.size() - 1, -1, -1):
		var page = pages[i]
		if page and page.evaluate_conditions(event_id):
			# Esta página cumple las condiciones
			if current_page_index != i:
				current_page_index = i
				current_page = page
				update_sprite_from_current_page()
				print("Event '%s': Página activa cambiada a índice %d" % [name, i])
			else:
				current_page = page
			return
	
	# Si ninguna página cumple las condiciones, usar la primera por defecto
	current_page_index = 0
	current_page = pages[0] if pages.size() > 0 else null
	update_sprite_from_current_page()

## Actualiza el sprite del evento según la página activa
func update_sprite_from_current_page() -> void:
	if not sprite:
		return
	
	if current_page:
		# Usar el método get_sprite_frames() que soporta generación automática
		var frames = current_page.get_sprite_frames()
		if frames:
			sprite.sprite_frames = frames
		else:
			sprite.sprite_frames = null
	else:
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


## Reevalúa las condiciones y actualiza la página activa
## Se llama automáticamente cuando cambian flags, variables o self-switches
func refresh_active_page() -> void:
	var old_page_index = current_page_index
	setup_current_page()
	
	# Si cambió de página, puede haber nuevo trigger type
	if old_page_index != current_page_index:
		# Si la nueva página es AUTORUN, trigger inmediato
		if current_page and current_page.trigger_type == EventTriggers.TriggerType.AUTORUN:
			call_deferred("trigger")


## Conecta el evento a las señales globales de cambio de estado
func _connect_to_state_signals() -> void:
	# Conectar a las señales reenviadas por SignalManager
	SignalManager.game_flag_changed.connect(_on_state_changed)
	SignalManager.game_variable_changed.connect(_on_state_changed_var)
	SignalManager.game_self_switch_changed.connect(_on_state_changed_switch)


## Callback cuando cambia un flag global
func _on_state_changed(_flag_name: String, _new_value: bool) -> void:
	refresh_active_page()


## Callback cuando cambia una variable global
func _on_state_changed_var(_variable_name: String, _new_value: int) -> void:
	refresh_active_page()


## Callback cuando cambia un self-switch
func _on_state_changed_switch(event_id: String, _switch_letter: String, _new_value: bool) -> void:
	# Solo reevaluar si el self-switch pertenece a este evento
	if event_id == _get_event_id():
		refresh_active_page()


## Obtiene un ID único para este evento (usado para self-switches)
## Formato: "mapid_eventname" o solo el nombre del nodo
func _get_event_id() -> String:
	# Usar el nombre del nodo como ID único
	# En el futuro se puede mejorar con: "current_map_id + '_' + name"
	return name
