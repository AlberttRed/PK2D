extends Node2D
class_name Event

signal event_triggered(page)

##Lista de páginas de evento (EventPage) que puede ejecutar el vento, cada una con su lista de comandos (EventCommand) definida.
@export var pages: Array[EventPage] = []
@export var current_page_index: int = 0

var current_page: Resource = null

var placeholder_sprite: AnimatedSprite2D
var actor_animator: ActorAnimator

# Referencia al OverworldContext para coordinación con EventSystem
var overworld_context: OverworldContext = null

func _ready() -> void:
	print("Event '%s': _ready() iniciado" % name)

	# Obtener referencias a los nodos manualmente para controlar el orden
	placeholder_sprite = $AnimatedSprite2D
	actor_animator = $ActorAnimator

	print("Event '%s': actor_animator obtenido = %s" % [name, actor_animator])

	# Duplicar páginas para evitar modificar Resources compartidos
	_duplicate_all_pages()

	# Ocultar placeholder primero
	hide_placeholder_sprite()

	# Ahora configurar la página actual (esto aplicará el sprite)
	print("Event '%s': Llamando a setup_current_page()" % name)
	setup_current_page()
	print("Event '%s': setup_current_page() completado" % name)

	# Conectar a señales de cambio de estado para reevaluación automática
	_connect_to_state_signals()

	# Autorun inmediato
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.AUTORUN:
		trigger()

## Configura current_page basado en current_page_index y pages
## Evalúa condiciones de todas las páginas para encontrar la activa
func setup_current_page() -> void:
	print("Event '%s': setup_current_page() - pages.size() = %d" % [name, pages.size()])

	if pages.size() == 0:
		current_page = null
		current_page_index = 0
		print("Event '%s': No hay páginas, llamando update_sprite_from_current_page()" % name)
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
				update_sprite_from_current_page()  # También actualizar aunque no haya cambiado de página
			return

	# Si ninguna página cumple las condiciones, usar la primera por defecto
	current_page_index = 0
	current_page = pages[0] if pages.size() > 0 else null
	print("Event '%s': Usando página por defecto (índice 0), llamando update_sprite_from_current_page()" % name)
	update_sprite_from_current_page()

## Actualiza el sprite y propiedades del evento según la página activa
func update_sprite_from_current_page() -> void:
	if not actor_animator or not actor_animator.sprite:
		return

	if current_page:
		# Usar el método get_sprite_frames() que soporta generación automática
		var frames = current_page.get_sprite_frames()
		if frames:
			actor_animator.set_sprite_frames(frames)
			actor_animator.set_sprite_offset(Vector2(0, 0))
			actor_animator.show_sprite()
		else:
			actor_animator.sprite.sprite_frames = null
			actor_animator.hide_sprite()
	else:
		actor_animator.sprite.sprite_frames = null
		actor_animator.hide_sprite()

	# Actualizar ocupación en el grid (through, blocks_player)
	_refresh_occupancy()

func trigger() -> void:
	if current_page:
		print("Event '%s' triggered!" % name)
		event_triggered.emit(current_page)

		# Solicitar la ejecución del evento mediante el contexto
		if overworld_context:
			overworld_context.request_event(self)
		else:
			push_warning("Event '%s': OverworldContext no disponible al solicitar ejecución" % name)

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

func on_player_collision() -> void:
	# Si el jugador colisiona contra el evento (intenta entrar pero no puede)
	if current_page and current_page.trigger_type == EventTriggers.TriggerType.PLAYER_COLLISION:
		print("Player collided!")
		trigger()

## Oculta el sprite placeholder (solo se usa en el editor)
func hide_placeholder_sprite() -> void:
	if placeholder_sprite:
		placeholder_sprite.visible = false

## Permite mostrar temporalmente el sprite del evento
func show_sprite() -> void:
	if actor_animator:
		actor_animator.show_sprite()

## Permite ocultar el sprite del evento
func hide_sprite() -> void:
	if actor_animator:
		actor_animator.hide_sprite()

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


## Actualiza la ocupación del evento en el grid cuando cambia de página
func _refresh_occupancy() -> void:
	# Buscar el nodo Occupancy (si existe)
	var occupancy_node = get_node_or_null("Occupancy")
	if occupancy_node and occupancy_node.has_method("refresh_occupancy"):
		occupancy_node.refresh_occupancy()


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

## Duplica todas las páginas para evitar modificar los Resources originales
## Esto permite que cada instancia del evento tenga sus propias copias que pueden modificarse
## sin afectar el Resource original cacheado por Godot
func _duplicate_all_pages() -> void:
	var duplicated_pages: Array[EventPage] = []
	for page in pages:
		if page:
			duplicated_pages.append(page.duplicate(true))
	pages = duplicated_pages

## Conecta el evento a las señales globales de cambio de estado
func _connect_to_state_signals() -> void:
	# Conectar directamente a las señales del GameStateService (autoload)
	if not GameStateService.flag_changed.is_connected(_on_state_changed):
		GameStateService.flag_changed.connect(_on_state_changed)
	if not GameStateService.variable_changed.is_connected(_on_state_changed_var):
		GameStateService.variable_changed.connect(_on_state_changed_var)
	if not GameStateService.self_switch_changed.is_connected(_on_state_changed_switch):
		GameStateService.self_switch_changed.connect(_on_state_changed_switch)


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

func set_overworld_context(context: OverworldContext) -> void:
	overworld_context = context
