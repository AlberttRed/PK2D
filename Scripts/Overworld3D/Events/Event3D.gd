extends Node3D
class_name Event3D
## Equivalente 3D de `Event` (2D). Reutiliza EventPage / triggers / commands / conditions del sistema 2D.
##
## PBI #962: núcleo + ocupación en celda.
##  - `pages` + selección de página activa (port 1:1 de Event.setup_current_page).
##  - Se ajusta al centro de su celda XZ (conserva Y) y se registra en el OverworldGrid3D del mapa.
##  - Una página no-through (o sin página) bloquea el paso, igual que en 2D.
##  - Visual placeholder (caja + etiqueta) hasta que cada evento tenga su modelo (p.ej. Door3D).
## PBI #963: disparo de triggers (try_fire / trigger / on_player_action / on_player_collision),
## igual que Event 2D. La ejecución real (EventSystem/EventController) llega en #964.

signal event_triggered(page)
signal page_changed(page)

## Lista de páginas (EventPage) con sus comandos; igual que en el Event 2D.
@export var pages: Array[EventPage] = []
@export var current_page_index: int = 0
## Si está deshabilitado, el evento no se disparará (útil para debug)
@export var disabled: bool = false
## Mantener visible el placeholder en juego (en 2D se oculta; en 3D aún no hay sprite/modelo).
@export var show_placeholder_in_game: bool = true:
	set(v):
		show_placeholder_in_game = v
		_apply_placeholder_visibility()

var current_page: Resource = null

## Referencia al contexto del Overworld (se conectará en #963/#964).
var overworld_context: OverworldContext = null

var grid: OverworldGrid3D = null
var _cell: Vector2i = Vector2i.ZERO
var _registered: bool = false


func _ready() -> void:
	# Duplicar páginas para no modificar Resources compartidos (igual que Event 2D).
	_duplicate_all_pages()

	grid = _find_grid()
	if grid == null:
		push_warning("Event3D '%s': no se encontró OverworldGrid3D; el evento no ocupará celda." % name)
	else:
		_cell = grid.world_to_cell(global_position)
		global_position = grid.cell_to_world_center(_cell, global_position.y)
		grid.register_event(_cell, self)
		_registered = true

	_apply_placeholder_visibility()
	setup_current_page()
	_connect_to_state_signals()


func _exit_tree() -> void:
	if grid != null and is_instance_valid(grid) and _registered:
		grid.unregister_event(_cell, self)
		_registered = false


func _find_grid() -> OverworldGrid3D:
	var p := get_parent()
	while p != null:
		if p is OverworldGrid3D:
			return p as OverworldGrid3D
		p = p.get_parent()
	return get_tree().get_first_node_in_group(OverworldGrid3D.GROUP) as OverworldGrid3D


# --- Celda / ocupación ---

func current_cell() -> Vector2i:
	return _cell


## true si el evento bloquea el paso (página no-through o sin página activa, como en 2D).
func blocks_movement() -> bool:
	return current_page == null or not current_page.through


## Mueve el evento a otra celda XZ (conserva Y) y actualiza el registro.
func move_to_cell(cell: Vector2i) -> void:
	if grid == null:
		return
	if _registered:
		grid.unregister_event(_cell, self)
	_cell = cell
	global_position = grid.cell_to_world_center(_cell, global_position.y)
	grid.register_event(_cell, self)
	_registered = true


# --- Páginas (port de Event.gd, sin la parte de sprite 2D) ---

## Configura current_page evaluando las condiciones de todas las páginas.
func setup_current_page() -> void:
	if pages.size() == 0:
		current_page = null
		current_page_index = 0
		_on_page_applied()
		return

	var event_id := _get_event_id()
	var best_page_with_conditions: EventPage = null
	var best_index_with_conditions: int = -1
	var best_page_without_conditions: EventPage = null
	var best_index_without_conditions: int = -1

	# Orden inverso (prioridad a las últimas páginas).
	for i in range(pages.size() - 1, -1, -1):
		var page = pages[i]
		if not page:
			continue
		if page.evaluate_conditions(event_id, self):
			if page.has_conditions():
				if best_page_with_conditions == null or i > best_index_with_conditions:
					best_page_with_conditions = page
					best_index_with_conditions = i
			else:
				if best_page_without_conditions == null or i > best_index_without_conditions:
					best_page_without_conditions = page
					best_index_without_conditions = i

	# Prioridad: páginas con condiciones sobre páginas sin condiciones.
	var selected_page: EventPage = null
	var selected_index: int = -1
	if best_page_with_conditions:
		selected_page = best_page_with_conditions
		selected_index = best_index_with_conditions
	elif best_page_without_conditions:
		selected_page = best_page_without_conditions
		selected_index = best_index_without_conditions

	if selected_page:
		current_page_index = selected_index
		current_page = selected_page
	else:
		# Todas con condiciones y ninguna cumple: evento desactivado.
		current_page = null
		current_page_index = -1
	_on_page_applied()


## Aplica efectos de la página activa (posición de página; el visual llegará con Door3D).
func _on_page_applied() -> void:
	if current_page and current_page.page_position != Vector2i(-1, -1):
		# Solo "no definida" si es exactamente (-1, -1): las celdas pueden ser negativas.
		move_to_cell(current_page.page_position)
	page_changed.emit(current_page)


# --- Triggers (port de Event.gd) ---

## Intenta activar el evento con la señal dada. Retorna true si se activó.
func try_fire(signal_type: EventTriggerSignal.SignalType, instigator: Node) -> bool:
	# `disabled` solo bloquea eventos en debug_mode.
	if _is_runtime_disabled():
		return false
	if not current_page:
		return false

	var page_trigger = current_page.get_effective_trigger()
	if not page_trigger:
		return false

	if not page_trigger.can_fire(signal_type, overworld_context, self, instigator):
		return false

	page_trigger.fire(signal_type, overworld_context, self, instigator)
	return true


## Llamado por EventTrigger.fire(). Solicita la ejecución mediante el contexto (#964).
func trigger() -> void:
	if _is_runtime_disabled():
		return
	if current_page:
		print("Event3D '%s' triggered!" % name)
		event_triggered.emit(current_page)
		if overworld_context:
			overworld_context.request_event(self)


## El jugador pulsa "interact" frente al evento.
func on_player_action() -> void:
	if current_page:
		try_fire(EventTriggerSignal.SignalType.ACTION, get_tree().get_first_node_in_group("Player"))


## El jugador intenta entrar en la celda del evento pero choca.
func on_player_collision() -> void:
	if current_page:
		try_fire(EventTriggerSignal.SignalType.COLLISION, get_tree().get_first_node_in_group("Player"))


func switch_to_page(page_index: int) -> void:
	if page_index >= 0 and page_index < pages.size():
		current_page_index = page_index
		setup_current_page()


func next_page() -> void:
	var next_index := current_page_index + 1
	if next_index < pages.size():
		switch_to_page(next_index)


func previous_page() -> void:
	var prev_index := current_page_index - 1
	if prev_index >= 0:
		switch_to_page(prev_index)


## Reevalúa condiciones y actualiza la página activa (llamado al cambiar flags/variables/self-switches).
## El autorun al cambiar de página se añadirá junto a los triggers (#963/#964).
func refresh_active_page() -> void:
	setup_current_page()


func set_overworld_context(context: OverworldContext) -> void:
	var had_context := overworld_context != null
	overworld_context = context
	if not had_context:
		refresh_active_page()


## ID único para self-switches: "mapid_eventname" (map id = padre del OverworldGrid3D).
func _get_event_id() -> String:
	if grid != null:
		var map_id := grid.get_map_id()
		if not map_id.is_empty():
			return "%s_%s" % [map_id, name]
	var current_map_id := GameStateService.get_current_map_id()
	if current_map_id.is_empty():
		return name
	return "%s_%s" % [current_map_id, name]


func _is_runtime_disabled() -> bool:
	return disabled and GameStateService.debug_mode


func _to_string() -> String:
	return name


func _apply_placeholder_visibility() -> void:
	var ph := get_node_or_null("Placeholder") as Node3D
	if ph != null:
		ph.visible = show_placeholder_in_game or Engine.is_editor_hint()
		var label := ph.get_node_or_null("Label3D") as Label3D
		if label != null:
			label.text = String(name)


# --- Estado global (mismas señales que Event 2D) ---

func _duplicate_all_pages() -> void:
	var duplicated_pages: Array[EventPage] = []
	for page in pages:
		if page:
			var duplicated_page := page.duplicate(true) as EventPage
			duplicated_page.take_over_path("")
			duplicated_pages.append(duplicated_page)
		else:
			duplicated_pages.append(null)
	pages = duplicated_pages


func _connect_to_state_signals() -> void:
	if not GameStateService.flag_changed.is_connected(_on_state_changed):
		GameStateService.flag_changed.connect(_on_state_changed)
	if not GameStateService.variable_changed.is_connected(_on_state_changed_var):
		GameStateService.variable_changed.connect(_on_state_changed_var)
	if not GameStateService.self_switch_changed.is_connected(_on_state_changed_switch):
		GameStateService.self_switch_changed.connect(_on_state_changed_switch)
	if not GameStateService.trainer_battle_result_changed.is_connected(_on_trainer_battle_result_changed):
		GameStateService.trainer_battle_result_changed.connect(_on_trainer_battle_result_changed)


func _any_page_depends(check: Callable) -> bool:
	if current_page and check.call(current_page):
		return true
	for page in pages:
		if page and check.call(page):
			return true
	return false


func _on_state_changed(flag_name: String, _new_value: bool) -> void:
	if is_inside_tree() and _any_page_depends(func(p): return p.depends_on_flag(flag_name)):
		refresh_active_page()


func _on_state_changed_var(variable_name: String, _new_value: Variant) -> void:
	if is_inside_tree() and _any_page_depends(func(p): return p.depends_on_variable(variable_name)):
		refresh_active_page()


func _on_state_changed_switch(event_id: String, _switch_letter: String, _new_value: bool) -> void:
	if event_id == _get_event_id() and is_inside_tree():
		refresh_active_page()


func _on_trainer_battle_result_changed(trainer_id: String, _result: String) -> void:
	if is_inside_tree() and _any_page_depends(func(p): return p.depends_on_trainer(trainer_id)):
		refresh_active_page()
