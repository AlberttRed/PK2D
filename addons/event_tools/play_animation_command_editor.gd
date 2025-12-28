@tool
extends Window

## Ventana de edición para PlayAnimationCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: PlayAnimationCommand)
signal cancelled

var command: PlayAnimationCommand = null
var _event_node: Node = null

# Valores originales para poder cancelar
var original_target_name: String = ""
var original_animation_name: String = ""
var original_wait_until_finished: bool = true

# Referencias a los controles
var target_option: OptionButton = null
var page_option: OptionButton = null
var animation_option: OptionButton = null
var wait_check: CheckBox = null
var accept_button: Button = null

func _ready() -> void:
	title = "Editar PlayAnimationCommand"
	size = Vector2(500, 350)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Editar PlayAnimationCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Target
	var target_container = HBoxContainer.new()
	var target_label = Label.new()
	target_label.text = "Target:"
	target_label.custom_minimum_size.x = 200
	target_container.add_child(target_label)

	target_option = OptionButton.new()
	target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_option.item_selected.connect(_on_target_selected)
	target_container.add_child(target_option)
	vbox.add_child(target_container)

	# Page Selection
	var page_container = HBoxContainer.new()
	var page_label = Label.new()
	page_label.text = "Página:"
	page_label.custom_minimum_size.x = 200
	page_container.add_child(page_label)

	page_option = OptionButton.new()
	page_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_option.item_selected.connect(_on_page_selected)
	page_option.disabled = true
	page_container.add_child(page_option)
	vbox.add_child(page_container)

	# Animation Name
	var animation_container = HBoxContainer.new()
	var animation_label = Label.new()
	animation_label.text = "Animación:"
	animation_label.custom_minimum_size.x = 200
	animation_container.add_child(animation_label)

	animation_option = OptionButton.new()
	animation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animation_option.item_selected.connect(_on_animation_selected)
	animation_container.add_child(animation_option)
	vbox.add_child(animation_container)

	# Wait until finished
	wait_check = CheckBox.new()
	wait_check.text = "Esperar hasta que termine"
	wait_check.button_pressed = true
	vbox.add_child(wait_check)

	# Botones
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)

	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)

	# Poblar eventos después de añadir los controles
	call_deferred("_populate_target_names")

## Helper: Obtiene el OverworldGrid del mapa actual
func _get_current_grid() -> Node:
	if not _event_node:
		return null
	var parent = _event_node.get_parent()
	if parent and parent.name == "Events":
		var grid = parent.get_parent()
		if grid and grid.is_in_group("OverworldGrid"):
			return grid
	return null

## Pobla el dropdown con los eventos del mapa
func _populate_target_names() -> void:
	if not target_option:
		return

	target_option.clear()

	# Si tenemos el event_node, obtener los eventos del mapa
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child is Event or (child.has_method("trigger") and child.has_method("setup_current_page")):
						if child.name != "":
							target_option.add_item(child.name)

	# Si no hay eventos, añadir un placeholder
	if target_option.get_item_count() == 0:
		target_option.add_item("(sin eventos)")

## Obtiene todas las páginas de un evento
func _get_event_pages(event: Node) -> Array[EventPage]:
	var pages: Array[EventPage] = []
	if not event:
		return pages

	if event.has_method("get") and event.get("pages"):
		var event_pages = event.get("pages")
		if event_pages is Array:
			for page in event_pages:
				if page is EventPage:
					pages.append(page)

	return pages

# Cache de páginas válidas por evento (índice del dropdown -> EventPage)
var _valid_pages_cache: Array[EventPage] = []

## Obtiene el EventPage seleccionado en el dropdown
func _get_selected_page() -> EventPage:
	if not page_option or page_option.disabled:
		return null

	var selected_index = page_option.selected
	if selected_index < 0 or selected_index >= _valid_pages_cache.size():
		return null

	return _valid_pages_cache[selected_index]

## Obtiene el SpriteFrames de un EventPage
func _get_sprite_frames_from_page(page: EventPage) -> SpriteFrames:
	if not page:
		return null

	# Verificar si tiene actor_style (no tiene SpriteFrames)
	if page.has_method("get"):
		var actor_style = page.get("actor_style")
		if actor_style != null:
			return null

	# Primero intentar obtener sprite_frames directamente (más confiable en @tool)
	var sprite_frames = null
	if page.has_method("get"):
		sprite_frames = page.get("sprite_frames")
		if sprite_frames is SpriteFrames:
			var animation_names = sprite_frames.get_animation_names()
			if not animation_names.is_empty():
				return sprite_frames

	# Si no hay sprite_frames directo, verificar si tiene sprite_texture
	var sprite_texture = null
	var is_spritesheet = false

	if page.has_method("get"):
		sprite_texture = page.get("sprite_texture")
		is_spritesheet = page.get("is_spritesheet")

		# Si tiene sprite_texture y NO es spritesheet, genera un SpriteFrames simple
		# con animación "default" - podemos generarlo manualmente en @tool
		if sprite_texture and not is_spritesheet:
			# Generar SpriteFrames simple con animación "default"
			var simple_frames = SpriteFrames.new()
			if not simple_frames.has_animation("default"):
				simple_frames.add_animation("default")
			simple_frames.set_animation_loop("default", true)
			simple_frames.set_animation_speed("default", 5.0)
			simple_frames.clear("default")
			simple_frames.add_frame("default", sprite_texture)
			return simple_frames

		# Para character_spritesheet o sprite_texture con is_spritesheet=true,
		# NO intentar llamar get_sprite_frames() en modo @tool porque:
		# 1. Puede ser una instancia placeholder
		# 2. SpriteFramesGenerator puede no estar disponible
		# 3. La generación dinámica puede fallar
		# En estos casos, retornar null (no podemos obtener animaciones en @tool)

	return null

## Obtiene el evento seleccionado en el dropdown
func _get_selected_event() -> Node:
	if not target_option:
		return null

	var selected_index = target_option.selected
	if selected_index < 0 or selected_index >= target_option.get_item_count():
		return null

	var selected_text = target_option.get_item_text(selected_index)
	if selected_text == "(sin eventos)":
		return null

	# Buscar el evento en el mapa
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child.name == selected_text:
						return child

	return null

## Se llama cuando se selecciona una página diferente
func _on_page_selected(_index: int) -> void:
	_update_animation_list()

## Actualiza el dropdown de animaciones según la página seleccionada
func _update_animation_list() -> void:
	if not animation_option:
		return

	animation_option.clear()
	animation_option.disabled = true
	# Deshabilitar el botón Aceptar cuando se limpia la lista
	_update_accept_button_state()

	var page = _get_selected_page()
	if not page:
		return

	var sprite_frames = _get_sprite_frames_from_page(page)
	if not sprite_frames:
		return

	# Obtener las animaciones del SpriteFrames
	var animation_names = sprite_frames.get_animation_names()
	if animation_names.is_empty():
		return

	# Poblar el dropdown con las animaciones
	for anim_name in animation_names:
		animation_option.add_item(anim_name)

	# Habilitar el dropdown si hay animaciones
	if animation_option.get_item_count() > 0:
		animation_option.disabled = false
		# No seleccionar automáticamente ninguna animación
		animation_option.selected = -1
		_update_accept_button_state()

## Pobla el dropdown de páginas con las páginas que tienen SpriteFrames
func _populate_page_list() -> void:
	if not page_option:
		return

	page_option.clear()
	page_option.disabled = true
	_valid_pages_cache.clear()

	var selected_event = _get_selected_event()
	if not selected_event:
		return

	var pages = _get_event_pages(selected_event)
	if pages.is_empty():
		return

	# Añadir solo las páginas que tienen SpriteFrames válidos
	for i in range(pages.size()):
		var page = pages[i]
		if not page:
			continue

		# Verificar si tiene sprite_frames, sprite_texture o character_spritesheet
		var has_sprite_data = false
		if page.has_method("get"):
			var sprite_frames = page.get("sprite_frames")
			var sprite_texture = page.get("sprite_texture")
			var character_spritesheet = page.get("character_spritesheet")
			var actor_style = page.get("actor_style")

			# Si tiene actor_style, no tiene SpriteFrames
			if actor_style != null:
				continue

			# Si tiene alguno de estos, puede tener SpriteFrames
			if sprite_frames or sprite_texture or character_spritesheet:
				has_sprite_data = true

		if has_sprite_data:
			# Intentar obtener el SpriteFrames
			var sprite_frames = _get_sprite_frames_from_page(page)
			# Si tiene sprite_frames válido, añadirlo
			# Si no, pero tiene sprite_texture o character_spritesheet, también añadirlo
			# (el SpriteFrames se generará en runtime)
			if sprite_frames:
				_valid_pages_cache.append(page)
				# Mostrar "Página X" en el dropdown
				page_option.add_item("Página %d" % (i + 1))
			elif page.has_method("get"):
				# Si tiene sprite_texture o character_spritesheet pero no podemos obtener
				# el SpriteFrames en @tool, aún así mostrar la página
				# (las animaciones se generarán en runtime)
				var sprite_texture = page.get("sprite_texture")
				var character_spritesheet = page.get("character_spritesheet")
				if sprite_texture or character_spritesheet:
					_valid_pages_cache.append(page)
					page_option.add_item("Página %d" % (i + 1))

	# Habilitar el dropdown si hay páginas válidas
	if page_option.get_item_count() > 0:
		page_option.disabled = false
		# Seleccionar la primera página por defecto
		page_option.selected = 0
		_update_animation_list()
	else:
		# Si no hay páginas válidas, limpiar las animaciones
		animation_option.clear()
		animation_option.disabled = true
		_update_accept_button_state()

## Se llama cuando se selecciona un target diferente
func _on_target_selected(_index: int) -> void:
	_populate_page_list()

## Se llama cuando se selecciona una animación
func _on_animation_selected(_index: int) -> void:
	_update_accept_button_state()

## Actualiza el estado del botón Aceptar
func _update_accept_button_state() -> void:
	if not accept_button or not animation_option:
		return

	# Deshabilitar si:
	# - No hay animación seleccionada (selected < 0)
	# - El dropdown está deshabilitado (no hay animaciones disponibles)
	# - No hay animaciones en el dropdown
	var has_selection = animation_option.selected >= 0
	var has_animations = animation_option.get_item_count() > 0
	var is_enabled = not animation_option.disabled

	accept_button.disabled = not (has_selection and has_animations and is_enabled)

## Setter para event_node
func set_event_node(value: Node) -> void:
	_event_node = value
	_populate_target_names()
	_populate_page_list()

## Carga un comando existente para editar
func load_command(cmd: PlayAnimationCommand) -> void:
	if not cmd:
		push_error("PlayAnimationCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_target_name = cmd.target_name
	original_animation_name = cmd.animation_name
	original_wait_until_finished = cmd.wait_until_finished

	# Asegurar que los eventos estén poblados antes de seleccionar
	if target_option:
		if target_option.get_item_count() == 0:
			_populate_target_names()
		_set_target_selection(cmd.target_name)
		# Después de seleccionar el target, poblar las páginas
		# Buscar la página que contiene la animación guardada
		call_deferred("_populate_page_list_and_select_animation", original_animation_name)

	# Actualizar wait_check
	if wait_check:
		wait_check.button_pressed = cmd.wait_until_finished

## Helper: Establece la selección del target
func _set_target_selection(target_name: String) -> void:
	if not target_option:
		return

	# Si está vacío, seleccionar el evento actual si está en la lista
	if target_name.is_empty():
		if target_option.get_item_count() > 0 and _event_node and _event_node.name != "":
			for i in range(target_option.get_item_count()):
				if target_option.get_item_text(i) == _event_node.name:
					target_option.selected = i
					call_deferred("_populate_page_list")
					call_deferred("_set_animation_selection", original_animation_name)
					return
		# Si no se encuentra el evento actual, seleccionar el primero disponible
		if target_option.get_item_count() > 0:
			target_option.selected = 0
			call_deferred("_populate_page_list")
			call_deferred("_set_animation_selection", original_animation_name)
		return

	# Buscar el evento en el dropdown
	for i in range(target_option.get_item_count()):
		if target_option.get_item_text(i) == target_name:
			target_option.selected = i
			call_deferred("_populate_page_list")
			call_deferred("_set_animation_selection", original_animation_name)
			return

## Pobla las páginas y busca la que contiene la animación especificada
func _populate_page_list_and_select_animation(animation_name: String) -> void:
	_populate_page_list()

	# Si hay una animación guardada, buscar en qué página está
	if not animation_name.is_empty() and page_option and not page_option.disabled:
		var selected_event = _get_selected_event()
		if selected_event:
			var pages = _get_event_pages(selected_event)
			# Buscar la página que tiene esta animación
			for i in range(pages.size()):
				var page = pages[i]
				var sprite_frames = _get_sprite_frames_from_page(page)
				if sprite_frames and sprite_frames.has_animation(animation_name):
					# Encontrar el índice en el dropdown (solo páginas válidas)
					var valid_index = 0
					for j in range(i + 1):
						var check_page = pages[j]
						var check_frames = _get_sprite_frames_from_page(check_page)
						if check_frames:
							if j == i:
								page_option.selected = valid_index
								_update_animation_list()
								_set_animation_selection(animation_name)
								return
							valid_index += 1
					break

		# Si no se encuentra, usar la primera página y seleccionar la animación si existe
		if page_option.get_item_count() > 0:
			page_option.selected = 0
			_update_animation_list()
			_set_animation_selection(animation_name)
	else:
		# Si no hay animación guardada, solo seleccionar la primera página
		if page_option and page_option.get_item_count() > 0:
			page_option.selected = 0
			_update_animation_list()

## Helper: Establece la selección de la animación
func _set_animation_selection(animation_name: String) -> void:
	if not animation_option or animation_option.disabled:
		return

	if animation_name.is_empty():
		animation_option.selected = -1
		_update_accept_button_state()
		return

	# Buscar la animación en el dropdown
	for i in range(animation_option.get_item_count()):
		if animation_option.get_item_text(i) == animation_name:
			animation_option.selected = i
			_update_accept_button_state()
			return

	# Si no se encuentra, dejar sin selección
	animation_option.selected = -1
	_update_accept_button_state()

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	# Obtener el nombre del target desde el dropdown
	var target_name = ""
	if target_option:
		var selected_index = target_option.selected
		if selected_index >= 0 and selected_index < target_option.get_item_count():
			var selected_text = target_option.get_item_text(selected_index)
			if selected_text != "(sin eventos)":
				# Si el evento seleccionado es el evento actual, dejar target_name vacío
				if _event_node and _event_node.name != "" and selected_text == _event_node.name:
					target_name = ""
				else:
					target_name = selected_text

	command.target_name = target_name

	# Obtener el nombre de la animación desde el dropdown
	var animation_name = ""
	if animation_option and not animation_option.disabled:
		var selected_index = animation_option.selected
		if selected_index >= 0 and selected_index < animation_option.get_item_count():
			animation_name = animation_option.get_item_text(selected_index)

	command.animation_name = animation_name

	# Wait until finished
	if wait_check:
		command.wait_until_finished = wait_check.button_pressed

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.target_name = original_target_name
	command.animation_name = original_animation_name
	command.wait_until_finished = original_wait_until_finished

	# Restaurar UI
	_set_target_selection(original_target_name)
	if wait_check:
		wait_check.button_pressed = original_wait_until_finished

## Se llama cuando se presiona Aceptar
func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	queue_free()

## Se llama cuando se presiona Cancelar
func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	queue_free()

## Se llama cuando se cierra la ventana
func _on_close_requested() -> void:
	_on_cancel_pressed()

