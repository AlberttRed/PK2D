@tool
extends Window

## Ventana para mostrar el mapa de la escena actual
var overworld_grid: OverworldGrid = null
var edited_scene_root: Node2D = null
var active_event: Event = null  # Evento que se está editando (solo este será visible)
var hidden_events: Array[Event] = []  # Lista de eventos ocultos para restaurar después

# Restricción de celdas según tipo de movimiento
var movement_type: int = 1  # 1=RANDOM (por defecto), 5=RANDOM_VERTICAL, 6=RANDOM_HORIZONTAL
var event_tile_position: Vector2i = Vector2i.ZERO  # Posición del evento en coordenadas de tile

var viewport_wrapper: Control = null
var viewport_container: SubViewportContainer = null
var map_viewport: SubViewport = null
var map_instance: Node2D = null
var camera: Camera2D = null
var grid_overlay: Control = null
var selected_cell_rect: ColorRect = null
## Valor centinela para indicar "sin selección" (usa valor muy negativo para no conflictuar con coords reales)
const UNSELECTED_CELL = Vector2i(-9999, -9999)
var selected_cell: Vector2i = UNSELECTED_CELL
var cell_size: int = 32
var main_vbox: VBoxContainer = null
var reference_tile_layer: TileMapLayer = null  # Capa de referencia para conversión de coordenadas
var assign_button: Button = null  # Botón para asignar la posición

# Variables para arrastre del mapa
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var camera_start_pos: Vector2 = Vector2.ZERO

# Modo de selección múltiple
var multiple_selection_mode: bool = false
var selected_tiles: Array[Vector2i] = []  # Array de celdas seleccionadas en modo múltiple
var selected_tiles_rects: Dictionary = {}  # {Vector2i: ColorRect} para mostrar múltiples selecciones

## Señal emitida cuando se selecciona una celda (modo simple)
signal cell_selected(cell_pos: Vector2i)
## Señal emitida cuando se seleccionan múltiples celdas (modo múltiple)
signal tiles_selected(tiles: Array[Vector2i])
## Señal emitida cuando se cancela la selección
signal cancelled

func _ready() -> void:
	print("Event Tools: position_selector_window._ready() llamado")
	title = "Vista del Mapa"
	size = Vector2i(800, 600)
	min_size = Vector2i(400, 300)
	unresizable = false
	# Configurar la ventana para que sea modal (igual que sprite_editor)
	always_on_top = false
	exclusive = true
	# Conectar la señal de cerrar (botón X) para que haga lo mismo que cancelar
	close_requested.connect(_on_close_requested)

	# Asegurar que la ventana pueda recibir eventos
	# Esperar un frame para que la ventana esté completamente inicializada
	await get_tree().process_frame
	set_process_input(true)
	set_process_unhandled_input(true)
	print("Event Tools: Ventana configurada, process_input: ", is_processing_input(), ", process_unhandled_input: ", is_processing_unhandled_input())

	# Crear layout
	main_vbox = VBoxContainer.new()
	main_vbox.name = "VBoxContainer"
	add_child(main_vbox)

	# Label de instrucciones
	var label = Label.new()
	label.text = "Vista del mapa de la escena actual - Haz click en una celda para seleccionarla"
	main_vbox.add_child(label)

	# Label para mostrar la celda seleccionada
	var selected_label = Label.new()
	selected_label.name = "SelectedCellLabel"
	selected_label.text = "Celda seleccionada: Ninguna"
	main_vbox.add_child(selected_label)

	# Label para mostrar celdas seleccionadas (modo múltiple)
	var multiple_label = Label.new()
	multiple_label.name = "MultipleSelectionLabel"
	multiple_label.text = "Celdas seleccionadas: 0 (Click para añadir/quitar)"
	multiple_label.visible = false
	main_vbox.add_child(multiple_label)

	# Contenedor del viewport (usar un Control normal para poder añadir el overlay encima)
	viewport_wrapper = Control.new()
	viewport_wrapper.name = "ViewportWrapper"
	viewport_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE  # No capturar eventos aquí, dejar que el overlay los capture
	main_vbox.add_child(viewport_wrapper)

	# Contenedor del viewport
	viewport_container = SubViewportContainer.new()
	viewport_container.stretch = false  # Deshabilitar stretch para poder cambiar el tamaño manualmente
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # No interceptar clicks, dejar que el overlay los capture
	viewport_wrapper.add_child(viewport_container)

	# Viewport para mostrar el mapa
	map_viewport = SubViewport.new()
	map_viewport.size = Vector2i(800, 600)
	viewport_container.add_child(map_viewport)

	# Cámara para navegar el mapa
	camera = Camera2D.new()
	camera.name = "PreviewCamera"
	map_viewport.add_child(camera)

	# Overlay para mostrar la cuadrícula y manejar clicks
	# Añadirlo al wrapper, no al viewport_container, para que esté encima
	grid_overlay = Control.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Capturar clicks
	grid_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_overlay.z_index = 100  # Asegurar que esté encima
	grid_overlay.gui_input.connect(_on_grid_overlay_input)
	# Asegurar que el overlay esté al final para que esté encima de todo
	viewport_wrapper.add_child(grid_overlay)
	# Mover al final para asegurar que esté encima
	viewport_wrapper.move_child(grid_overlay, viewport_wrapper.get_child_count() - 1)

	# ColorRect para mostrar la celda seleccionada (más visible que dibujar)
	selected_cell_rect = ColorRect.new()
	selected_cell_rect.name = "SelectedCellRect"
	selected_cell_rect.color = Color(1.0, 0.0, 0.0, 0.6)  # Rojo más visible
	selected_cell_rect.visible = false
	selected_cell_rect.z_index = 200  # Encima de todo
	selected_cell_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # No interceptar clicks
	selected_cell_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_wrapper.add_child(selected_cell_rect)
	# Mover al final para asegurar que esté encima de todo
	viewport_wrapper.move_child(selected_cell_rect, viewport_wrapper.get_child_count() - 1)

	# Conectar también el dibujado directamente
	grid_overlay.draw.connect(_draw_grid_overlay)

	# Forzar redibujado inicial y periódico
	call_deferred("_force_grid_redraw")

	# Redibujar cuando cambie el tamaño de la ventana
	size_changed.connect(_on_window_size_changed)

	# Botones de control
	var hbox = HBoxContainer.new()

	var zoom_in_btn = Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.pressed.connect(_on_zoom_in_pressed)
	hbox.add_child(zoom_in_btn)

	var zoom_out_btn = Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.pressed.connect(_on_zoom_out_pressed)
	hbox.add_child(zoom_out_btn)

	var reset_btn = Button.new()
	reset_btn.text = "Resetear vista"
	reset_btn.pressed.connect(func():
		_reset_camera()
		if grid_overlay:
			grid_overlay.queue_redraw()
	)
	hbox.add_child(reset_btn)

	hbox.add_child(Control.new())  # Spacer

	# Botones de navegación (flechas)
	var nav_label = Label.new()
	nav_label.text = "Navegar:"
	hbox.add_child(nav_label)

	var up_btn = Button.new()
	up_btn.text = "↑"
	up_btn.custom_minimum_size = Vector2(30, 30)
	up_btn.pressed.connect(func(): _move_camera(Vector2.UP))
	hbox.add_child(up_btn)

	var nav_vbox = VBoxContainer.new()
	var left_btn = Button.new()
	left_btn.text = "←"
	left_btn.custom_minimum_size = Vector2(30, 30)
	left_btn.pressed.connect(func(): _move_camera(Vector2.LEFT))
	nav_vbox.add_child(left_btn)

	var right_btn = Button.new()
	right_btn.text = "→"
	right_btn.custom_minimum_size = Vector2(30, 30)
	right_btn.pressed.connect(func(): _move_camera(Vector2.RIGHT))
	nav_vbox.add_child(right_btn)
	hbox.add_child(nav_vbox)

	var down_btn = Button.new()
	down_btn.text = "↓"
	down_btn.custom_minimum_size = Vector2(30, 30)
	down_btn.pressed.connect(func(): _move_camera(Vector2.DOWN))
	hbox.add_child(down_btn)

	hbox.add_child(Control.new())  # Spacer

	# Botón Cancelar
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	hbox.add_child(cancel_btn)

	# Botón Asignar posición
	assign_button = Button.new()
	assign_button.text = "Asignar posición"
	assign_button.disabled = true  # Inicialmente deshabilitado
	assign_button.pressed.connect(_on_assign_button_pressed)
	hbox.add_child(assign_button)

	main_vbox.add_child(hbox)

	# Ajustar el tamaño del viewport después de que todo esté listo
	call_deferred("_update_viewport_size")

	# Verificar que el overlay recibe eventos
	print("Event Tools: Overlay creado, mouse_filter: ", grid_overlay.mouse_filter)

	# También intentar capturar eventos a nivel de ventana como fallback
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process_input(true)

	# Verificar que el procesamiento de input está activo
	print("Event Tools: process_input: ", is_processing_input(), ", process_unhandled_input: ", is_processing_unhandled_input())

func _move_overlay_to_top() -> void:
	if grid_overlay and viewport_container:
		viewport_container.move_child(grid_overlay, viewport_container.get_child_count() - 1)

	# Asegurar que el overlay se redibuje periódicamente cuando la cámara cambie
	if grid_overlay:
		# Usar un timer para redibujar periódicamente (útil cuando se arrastra la cámara)
		var redraw_timer = Timer.new()
		redraw_timer.wait_time = 0.1
		redraw_timer.timeout.connect(func(): grid_overlay.queue_redraw())
		redraw_timer.autostart = true
		add_child(redraw_timer)

func _update_selected_cell_rect() -> void:
	if not selected_cell_rect or not is_instance_valid(selected_cell_rect):
		return

	# En modo múltiple, no mostrar el rectángulo temporal
	if multiple_selection_mode:
		selected_cell_rect.visible = false
		return

	if not camera or not is_instance_valid(camera):
		return

	if not map_viewport or not is_instance_valid(map_viewport):
		return

	if not viewport_wrapper or not is_instance_valid(viewport_wrapper):
		return

	if selected_cell == UNSELECTED_CELL:
		selected_cell_rect.visible = false
		return

	# Verificar que las funciones auxiliares existan y que los nodos necesarios estén listos
	if not reference_tile_layer or not is_instance_valid(reference_tile_layer):
		return

	# Calcular posición del centro de la celda en coordenadas del mundo
	var cell_world_center = _cell_to_world(selected_cell)

	# Calcular las esquinas de la celda en coordenadas del mundo
	# Usar el centro y restar/sumar la mitad del tamaño de la celda
	var half_cell_size = cell_size / 2.0
	var cell_world_top_left = cell_world_center - Vector2(half_cell_size, half_cell_size)
	var cell_world_bottom_right = cell_world_center + Vector2(half_cell_size, half_cell_size)

	# Convertir las esquinas a coordenadas de pantalla
	var cell_screen_top_left = _world_to_screen(cell_world_top_left)
	var cell_screen_bottom_right = _world_to_screen(cell_world_bottom_right)

	# Calcular tamaño y posición desde las esquinas
	var cell_screen_size = cell_screen_bottom_right - cell_screen_top_left
	var cell_screen_center = (cell_screen_top_left + cell_screen_bottom_right) / 2.0

	# Asegurar que el tamaño mínimo sea visible
	if cell_screen_size.x < 5:
		cell_screen_size.x = 5
	if cell_screen_size.y < 5:
		cell_screen_size.y = 5

	# Posicionar y dimensionar el ColorRect (coordenadas locales del wrapper)
	var rect_pos = cell_screen_center - cell_screen_size / 2.0
	selected_cell_rect.position = rect_pos
	selected_cell_rect.size = cell_screen_size
	selected_cell_rect.visible = true

func _force_grid_redraw() -> void:
	if grid_overlay:
		grid_overlay.queue_redraw()
		# Redibujar periódicamente para mantener la cuadrícula visible
		var redraw_timer = Timer.new()
		redraw_timer.wait_time = 0.1
		redraw_timer.timeout.connect(_on_redraw_timer_timeout)
		redraw_timer.autostart = true
		add_child(redraw_timer)

func _update_viewport_size() -> void:
	if map_viewport and viewport_container:
		# Esperar a que el contenedor tenga un tamaño válido
		await get_tree().process_frame
		var container_size = viewport_container.size
		if container_size.x > 0 and container_size.y > 0:
			map_viewport.size = container_size
			# Asegurar que el overlay también tenga el tamaño correcto
			if grid_overlay:
				grid_overlay.size = container_size
				grid_overlay.queue_redraw()

func setup(overworld_grid_node: OverworldGrid, scene_root: Node2D, event_to_show: Event = null) -> void:
	overworld_grid = overworld_grid_node
	edited_scene_root = scene_root
	active_event = event_to_show

	# Ocultar todos los eventos excepto el activo
	_hide_other_events()

	# Esperar a que _ready() termine y el map_viewport esté inicializado
	if not map_viewport:
		await get_tree().process_frame
		await get_tree().process_frame

	# Verificar que map_viewport existe
	if not map_viewport:
		push_error("Event Tools: map_viewport no está inicializado")
		return

	# Duplicar el OverworldGrid para mostrarlo en el preview
	if overworld_grid:
		map_instance = overworld_grid.duplicate(true)  # Duplicar con subrecursos
		map_viewport.add_child(map_instance)

		# Obtener la capa de referencia para conversión de coordenadas
		reference_tile_layer = _get_reference_tile_layer()
		if reference_tile_layer:
			# Obtener el tamaño de celda del TileMapLayer
			var tile_set = reference_tile_layer.tile_set
			if tile_set:
				cell_size = tile_set.tile_size.x

		# Asegurar que el viewport esté listo antes de ajustar la cámara
		await get_tree().process_frame
		await get_tree().process_frame

		# Ajustar cámara para mostrar todo el mapa
		_reset_camera()

func _get_reference_tile_layer() -> TileMapLayer:
	if not map_instance:
		return null

	# Buscar el primer TileMapLayer en el map_instance
	for child in map_instance.get_children():
		if child is TileMapLayer:
			return child as TileMapLayer

	return null

func _on_assign_button_pressed() -> void:
	# Restaurar visibilidad de eventos ocultos
	_restore_events_visibility()

	if multiple_selection_mode:
		# Modo múltiple: emitir todas las celdas seleccionadas
		if selected_tiles.is_empty():
			return
		tiles_selected.emit(selected_tiles.duplicate())
	else:
		# Modo simple: verificar que hay una celda seleccionada
		if selected_cell == UNSELECTED_CELL:
			return
		# Emitir señal de celda seleccionada
		cell_selected.emit(selected_cell)

	# Cerrar la ventana de forma segura
	hide()
	# Liberar la ventana después de un frame para evitar errores de X11
	call_deferred("queue_free")

func _reset_camera() -> void:
	if not map_instance or not overworld_grid:
		return

	# Calcular límites del mapa desde los TileMapLayers
	var bounds = _calculate_map_bounds()
	if bounds.size.x > 0 and bounds.size.y > 0:
		# La cámara debe estar en el centro del mapa
		# bounds.position es el origen (0,0) del TileMapLayer
		# bounds.get_center() es el centro del mapa en coordenadas del TileMapLayer
		camera.position = bounds.get_center()
		print("Event Tools: _reset_camera - bounds: ", bounds, ", camera.position: ", camera.position)
		# Ajustar zoom para mostrar todo el mapa con un poco de margen
		var viewport_size = map_viewport.size
		var zoom_x = viewport_size.x / (bounds.size.x * 1.2)
		var zoom_y = viewport_size.y / (bounds.size.y * 1.2)
		camera.zoom = Vector2(min(zoom_x, zoom_y), min(zoom_x, zoom_y))
	else:
		camera.position = Vector2.ZERO
		camera.zoom = Vector2.ONE

func _calculate_map_bounds() -> Rect2:
	if not overworld_grid:
		return Rect2()

	# Buscar hijos TileMapLayer directamente
	var tile_layers: Array[TileMapLayer] = []
	for child in overworld_grid.get_children():
		if child is TileMapLayer:
			tile_layers.append(child)

	if tile_layers.is_empty():
		return Rect2()

	# Usar el primer TileMapLayer como referencia
	var ref_layer = tile_layers[0]
	if not ref_layer:
		return Rect2()

	var used_rect = ref_layer.get_used_rect()
	if used_rect.size.x == 0 or used_rect.size.y == 0:
		return Rect2()

	# Convertir tiles a píxeles
	# map_to_local() convierte coordenadas de tile a coordenadas locales del TileMapLayer
	# El TileMapLayer tiene su origen en (0,0) en la esquina superior izquierda
	var world_pos_min = ref_layer.map_to_local(used_rect.position)
	var world_pos_max = ref_layer.map_to_local(used_rect.position + used_rect.size)

	return Rect2(world_pos_min, world_pos_max - world_pos_min)

func _on_viewport_wrapper_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# mouse_event.position ya está en coordenadas locales del viewport_wrapper
			var local_pos = mouse_event.position
			_handle_click(local_pos)
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Solo procesar clicks, ignorar movimiento
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# Verificar si el click está en un botón u otro control interactivo
			# Si es así, no procesar el click como selección de celda
			var clicked_control = _get_control_at_position(mouse_event.position)
			if clicked_control and (clicked_control is Button or clicked_control.get_parent() is HBoxContainer):
				# Es un botón, dejar que se maneje normalmente
				return

			if viewport_wrapper and viewport_wrapper.is_visible_in_tree():
				# Obtener posición del click relativa a la ventana
				var window_pos = mouse_event.position

				# Calcular la posición del wrapper dentro de la ventana
				# El wrapper está después de los labels y botones
				var wrapper_y_offset = 0.0
				var controls_height = 0.0
				if main_vbox:
					for child in main_vbox.get_children():
						if child == viewport_wrapper:
							break
						if child is Control:
							var child_height = child.size.y if child.size.y > 0 else child.custom_minimum_size.y
							wrapper_y_offset += child_height
							controls_height += child_height

				# Calcular el tamaño del wrapper usando el tamaño de la ventana menos los controles
				var wrapper_height = size.y - controls_height

				# Verificar si el click está dentro del área del wrapper
				if window_pos.y >= wrapper_y_offset and window_pos.y < wrapper_y_offset + wrapper_height:
					# Convertir posición de ventana a local del wrapper
					var local_pos = Vector2(window_pos.x, window_pos.y - wrapper_y_offset)

					# Verificar que el click esté dentro del área visible del viewport
					if _is_click_inside_viewport(local_pos):
						print("Event Tools: Click detectado - local_pos: ", local_pos)
						_handle_click(local_pos)
						get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# Fallback adicional: capturar eventos no manejados (solo clicks)
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if viewport_wrapper and viewport_wrapper.is_visible_in_tree():
				# Obtener posición del click relativa a la ventana
				var window_pos = mouse_event.position

				# Calcular la posición del wrapper dentro de la ventana
				var wrapper_y_offset = 0.0
				var controls_height = 0.0
				if main_vbox:
					for child in main_vbox.get_children():
						if child == viewport_wrapper:
							break
						if child is Control:
							var child_height = child.size.y if child.size.y > 0 else child.custom_minimum_size.y
							wrapper_y_offset += child_height
							controls_height += child_height

				# Calcular el tamaño del wrapper usando el tamaño de la ventana menos los controles
				var wrapper_height = size.y - controls_height

				# Verificar si el click está dentro del área del wrapper
				if window_pos.y >= wrapper_y_offset and window_pos.y < wrapper_y_offset + wrapper_height:
					# Convertir posición de ventana a local del wrapper
					var local_pos = Vector2(window_pos.x, window_pos.y - wrapper_y_offset)
					_handle_click(local_pos)
					get_viewport().set_input_as_handled()

func _get_control_at_position(pos: Vector2) -> Control:
	# Buscar recursivamente el control en la posición dada
	for child in get_children():
		if child is Control:
			var control = child as Control
			if control.visible and control.get_rect().has_point(pos - control.position):
				# Verificar si es un botón o está dentro de un HBoxContainer (botones)
				if control is Button:
					return control
				# Buscar recursivamente en los hijos
				var found = _get_control_at_position_recursive(control, pos - control.position)
				if found:
					return found
	return null

func _get_control_at_position_recursive(parent: Control, local_pos: Vector2) -> Control:
	for child in parent.get_children():
		if child is Control:
			var control = child as Control
			if control.visible and control.get_rect().has_point(local_pos - control.position):
				if control is Button:
					return control
				var found = _get_control_at_position_recursive(control, local_pos - control.position)
				if found:
					return found
	return null

func _is_click_inside_viewport(local_pos: Vector2) -> bool:
	if not viewport_container or not map_viewport:
		return false

	# Verificar que el click esté dentro del área del container
	if local_pos.x < 0 or local_pos.y < 0:
		return false
	if local_pos.x >= viewport_container.size.x or local_pos.y >= viewport_container.size.y:
		return false

	# Verificar que esté dentro del área visible del viewport (considerando el offset)
	var container_size = viewport_container.size
	var viewport_size = Vector2(map_viewport.size)
	var viewport_offset = Vector2.ZERO

	if container_size.x > viewport_size.x:
		viewport_offset.x = (container_size.x - viewport_size.x) / 2.0
	if container_size.y > viewport_size.y:
		viewport_offset.y = (container_size.y - viewport_size.y) / 2.0

	# Ajustar la posición local por el offset del viewport
	var viewport_local_pos = local_pos - viewport_offset

	# Verificar que esté dentro del viewport
	return viewport_local_pos.x >= 0 and viewport_local_pos.x < viewport_size.x and \
		   viewport_local_pos.y >= 0 and viewport_local_pos.y < viewport_size.y

func _handle_click(screen_pos: Vector2) -> void:
	# screen_pos está en coordenadas del viewport_wrapper (o grid_overlay que tiene el mismo tamaño)
	# Convertir a coordenadas del mundo usando el método que funciona
	var world_pos = _screen_to_world_position(screen_pos)

	# Convertir directamente usando el TileMapLayer
	# NOTA: Se aplica +1 en Y para corregir el offset visual del click
	var cell_pos: Vector2i
	if reference_tile_layer and is_instance_valid(reference_tile_layer):
		var local_pos = reference_tile_layer.to_local(world_pos)
		var tile_pos = reference_tile_layer.local_to_map(local_pos)
		# Offset +1 en Y para que el click seleccione la celda correcta visualmente
		tile_pos.y += 1
		cell_pos = tile_pos
	else:
		cell_pos = _world_to_cell(world_pos)

	# Verificar si la celda es válida según el tipo de movimiento
	if not _is_cell_valid_for_movement(cell_pos):
		print("Event Tools: Celda %s no válida para tipo de movimiento %d (evento en %s)" % [cell_pos, movement_type, event_tile_position])
		return

	# Actualizar celda seleccionada según el modo
	if multiple_selection_mode:
		# Modo múltiple: añadir/quitar celda del array
		print("Event Tools: Click en modo múltiple - celda: ", cell_pos, ", ya seleccionada: ", cell_pos in selected_tiles)
		if cell_pos in selected_tiles:
			# Ya está seleccionada, quitarla
			selected_tiles.erase(cell_pos)
			_remove_tile_rect(cell_pos)
			print("Event Tools: Celda quitada. Total seleccionadas: ", selected_tiles.size())
		else:
			# Añadirla
			selected_tiles.append(cell_pos)
			_create_tile_rect(cell_pos)
			print("Event Tools: Celda añadida. Total seleccionadas: ", selected_tiles.size())

		_update_multiple_selection_label()

		# En modo múltiple, no mostrar el rectángulo temporal (solo los rectángulos de selección)
		# Ocultar el rectángulo temporal para evitar confusión
		if selected_cell_rect:
			selected_cell_rect.visible = false

		# Habilitar el botón si hay celdas seleccionadas
		if assign_button:
			assign_button.disabled = selected_tiles.is_empty()
	else:
		# Modo simple: seleccionar una sola celda
		selected_cell = cell_pos

		# Actualizar el label
		if main_vbox:
			var selected_label = main_vbox.get_node_or_null("SelectedCellLabel")
			if selected_label:
				selected_label.text = "Celda seleccionada: (%d, %d)" % [cell_pos.x, cell_pos.y]

		# Actualizar el rectángulo de la celda seleccionada
		_update_selected_cell_rect()

		# Habilitar el botón de asignar posición
		if assign_button:
			assign_button.disabled = false

	# Redibujar el overlay
	if grid_overlay:
		grid_overlay.queue_redraw()

func _on_window_size_changed() -> void:
	# Actualizar el tamaño del viewport cuando cambie el tamaño de la ventana
	call_deferred("_update_viewport_size")
	if grid_overlay:
		grid_overlay.queue_redraw()
	if selected_cell_rect:
		_update_selected_cell_rect()
	if multiple_selection_mode:
		_update_all_tile_rects()

func _on_grid_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		# Click izquierdo: seleccionar celda
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# mouse_event.position está en coordenadas locales del grid_overlay
			# Como el grid_overlay tiene PRESET_FULL_RECT, sus coordenadas coinciden con el wrapper
			var local_pos = mouse_event.position
			_handle_click(local_pos)
			get_viewport().set_input_as_handled()
		# Click derecho o central: iniciar arrastre para mover el mapa
		elif (mouse_event.button_index == MOUSE_BUTTON_RIGHT or mouse_event.button_index == MOUSE_BUTTON_MIDDLE) and mouse_event.pressed:
			is_dragging = true
			drag_start_pos = mouse_event.position
			camera_start_pos = camera.position
			get_viewport().set_input_as_handled()
		# Soltar botón: terminar arrastre
		elif (mouse_event.button_index == MOUSE_BUTTON_RIGHT or mouse_event.button_index == MOUSE_BUTTON_MIDDLE) and not mouse_event.pressed:
			is_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if is_dragging and camera:
			var mouse_event = event as InputEventMouseMotion
			var drag_delta = drag_start_pos - mouse_event.position
			# Convertir el delta de píxeles de pantalla a píxeles del mundo según el zoom
			var world_delta = drag_delta / camera.zoom
			# Mover la cámara en la dirección opuesta al arrastre
			camera.position = camera_start_pos + world_delta
			# Redibujar el overlay
			if grid_overlay:
				grid_overlay.queue_redraw()
			call_deferred("_update_selected_cell_rect")
			if multiple_selection_mode:
				call_deferred("_update_all_tile_rects")
			get_viewport().set_input_as_handled()

func _screen_to_world_position(screen_pos: Vector2) -> Vector2:
	if not camera or not map_viewport or not viewport_container or not map_instance:
		return Vector2.ZERO

	# La posición screen_pos está en coordenadas locales del viewport_wrapper
	var container_offset = viewport_container.position
	var adjusted_screen_pos = screen_pos - container_offset

	# Obtener tamaños
	var container_size = viewport_container.size
	var viewport_size = Vector2(map_viewport.size)

	# Calcular el offset del viewport dentro del container
	var viewport_offset = Vector2.ZERO
	if container_size.x > viewport_size.x:
		viewport_offset.x = (container_size.x - viewport_size.x) / 2.0
	if container_size.y > viewport_size.y:
		viewport_offset.y = (container_size.y - viewport_size.y) / 2.0

	# Convertir coordenadas del container a coordenadas del viewport
	var viewport_local_pos = adjusted_screen_pos - viewport_offset

	# Verificar que estamos dentro del viewport
	if viewport_local_pos.x < 0 or viewport_local_pos.x >= viewport_size.x or \
	   viewport_local_pos.y < 0 or viewport_local_pos.y >= viewport_size.y:
		viewport_local_pos.x = clamp(viewport_local_pos.x, 0, viewport_size.x - 1)
		viewport_local_pos.y = clamp(viewport_local_pos.y, 0, viewport_size.y - 1)

	# Convertir posición de pantalla a posición relativa al centro del viewport
	var relative_pos = viewport_local_pos - viewport_size / 2.0

	# Obtener la posición de la cámara en coordenadas del mundo
	# camera.position está en coordenadas relativas al map_instance (OverworldGrid)
	# que tiene su origen en (0,0) en la esquina superior izquierda del TileMapLayer
	var camera_world_pos = camera.position

	# Convertir a coordenadas del mundo usando el zoom de la cámara
	# La posición del mundo es relativa al map_instance (OverworldGrid), con origen en (0,0)
	# El cálculo: posición de la cámara + offset relativo al centro del viewport
	# Ajustar ligeramente para centrar mejor la detección del click
	var world_pos = camera_world_pos + relative_pos / camera.zoom

	return world_pos

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	# Convertir posición del mundo a coordenadas de celda
	# world_pos está en coordenadas relativas al map_instance (OverworldGrid)
	# que tiene su origen en (0,0) en la esquina superior izquierda
	# Usar el TileMapLayer para conversión correcta si está disponible
	if reference_tile_layer:
		# world_pos está en coordenadas globales del map_instance
		# Necesitamos convertirlo a coordenadas locales del TileMapLayer
		# El TileMapLayer está dentro del map_instance, así que world_pos es relativo al map_instance
		# Convertir a coordenadas locales del TileMapLayer
		var local_pos = reference_tile_layer.to_local(world_pos)

		# Convertir a coordenadas de tile
		# local_to_map() devuelve el tile basándose en la esquina superior izquierda
		# Si al hacer click se selecciona la celda de arriba, necesitamos desplazar hacia abajo
		# Para centrar la detección, desplazamos media celda hacia abajo y a la derecha
		var half_cell = Vector2(cell_size, cell_size) / 2.0
		var adjusted_local_pos = local_pos + half_cell
		var tile_pos = reference_tile_layer.local_to_map(adjusted_local_pos)

		print("Event Tools: _world_to_cell - world_pos: ", world_pos, ", local_pos: ", local_pos, ", adjusted_local_pos: ", adjusted_local_pos, ", tile_pos: ", tile_pos)
		return tile_pos
	else:
		# Fallback: calcular directamente
		# Las coordenadas del mundo ya están relativas al origen (0,0)
		# Ajustar por la mitad de la celda para centrar la detección
		var adjusted_world_pos = world_pos + Vector2(cell_size, cell_size) / 2.0
		var cell_x = int(floor(adjusted_world_pos.x / cell_size))
		var cell_y = int(floor(adjusted_world_pos.y / cell_size))
		return Vector2i(cell_x, cell_y)

func _cell_to_world(cell_pos: Vector2i) -> Vector2:
	# Convertir coordenadas de celda a posición del mundo (centro de la celda)
	# cell_pos son coordenadas REALES del TileMapLayer
	if reference_tile_layer and is_instance_valid(reference_tile_layer):
		# Convertir coordenadas de tile a coordenadas locales del TileMapLayer
		var local_pos = reference_tile_layer.map_to_local(cell_pos)
		# Convertir a coordenadas globales del TileMapLayer (que es relativo al map_instance)
		return reference_tile_layer.to_global(local_pos)
	else:
		# Fallback: calcular directamente
		return Vector2(cell_pos.x * cell_size + cell_size / 2.0, cell_pos.y * cell_size + cell_size / 2.0)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	if not camera or not is_instance_valid(camera):
		return Vector2.ZERO
	if not map_viewport or not is_instance_valid(map_viewport):
		return Vector2.ZERO
	if not viewport_container or not is_instance_valid(viewport_container):
		return Vector2.ZERO

	# Obtener la posición de la cámara en coordenadas del mundo
	# camera.position está en coordenadas relativas al map_instance (OverworldGrid)
	# con origen en (0,0) en la esquina superior izquierda
	var camera_world_pos = camera.position
	var viewport_size = Vector2(map_viewport.size)

	# Convertir coordenadas del mundo a coordenadas de pantalla del viewport
	# world_pos está en coordenadas relativas al map_instance (OverworldGrid), con origen en (0,0)
	var relative_pos = (world_pos - camera_world_pos) * camera.zoom
	var screen_pos_in_viewport = relative_pos + viewport_size / 2.0

	# Calcular el offset del viewport dentro del container (cuando stretch = false, puede estar centrado)
	var container_size = viewport_container.size
	var viewport_offset = Vector2.ZERO

	# Si el container es más grande que el viewport, el viewport está centrado
	if container_size.x > viewport_size.x:
		viewport_offset.x = (container_size.x - viewport_size.x) / 2.0
	if container_size.y > viewport_size.y:
		viewport_offset.y = (container_size.y - viewport_size.y) / 2.0

	# Convertir a coordenadas del container (sumar el offset del viewport)
	var screen_pos_in_container = screen_pos_in_viewport + viewport_offset

	# Ajustar por la posición del viewport_container dentro del wrapper
	var container_offset = viewport_container.position

	# Convertir a coordenadas del wrapper
	var screen_pos = screen_pos_in_container + container_offset

	return screen_pos

func _draw_grid_overlay() -> void:
	if not grid_overlay or not map_viewport or not camera:
		return

	var overlay_size = grid_overlay.size
	if overlay_size.x <= 0 or overlay_size.y <= 0:
		return

	# Dibujar celda seleccionada (más visible)
	if selected_cell != UNSELECTED_CELL:
		var cell_world_pos = _cell_to_world(selected_cell)
		var cell_screen_pos = _world_to_screen(cell_world_pos)
		var cell_screen_size = Vector2(cell_size, cell_size) / camera.zoom

		# Dibujar rectángulo rojo sólido para la celda seleccionada
		var rect = Rect2(
			cell_screen_pos - cell_screen_size / 2.0,
			cell_screen_size
		)

		# Asegurar que el rectángulo esté dentro del overlay
		if rect.position.x < overlay_size.x and rect.position.y < overlay_size.y and rect.position.x + rect.size.x > 0 and rect.position.y + rect.size.y > 0:
			# Dibujar fondo rojo semitransparente
			grid_overlay.draw_rect(rect, Color(1.0, 0.0, 0.0, 0.4), true)
			# Dibujar borde rojo más grueso
			grid_overlay.draw_rect(rect, Color(1.0, 0.0, 0.0, 1.0), false, 3.0)

	# Calcular el área visible en coordenadas del mundo
	var camera_center = camera.get_screen_center_position()
	var viewport_size = map_viewport.size
	var world_top_left = camera_center - (viewport_size / 2.0) / camera.zoom
	var world_bottom_right = camera_center + (viewport_size / 2.0) / camera.zoom

	# Convertir a celdas
	var cell_start = _world_to_cell(world_top_left)
	var cell_end = _world_to_cell(world_bottom_right)

	# Dibujar cuadrícula
	var grid_color = Color(1.0, 1.0, 1.0, 0.6)  # Blanco más visible

	# Dibujar líneas de la cuadrícula verticales
	for x in range(cell_start.x - 1, cell_end.x + 2):
		var world_x = x * cell_size
		var screen_pos_top = _world_to_screen(Vector2(world_x, world_top_left.y))
		var screen_pos_bottom = _world_to_screen(Vector2(world_x, world_bottom_right.y))

		# Asegurar que las líneas estén dentro del overlay
		var start_y = max(0, min(screen_pos_top.y, screen_pos_bottom.y))
		var end_y = min(overlay_size.y, max(screen_pos_top.y, screen_pos_bottom.y))

		if screen_pos_top.x >= 0 and screen_pos_top.x <= overlay_size.x and end_y > start_y:
			grid_overlay.draw_line(
				Vector2(screen_pos_top.x, start_y),
				Vector2(screen_pos_top.x, end_y),
				grid_color,
				1.0
			)

	# Dibujar líneas de la cuadrícula horizontales
	for y in range(cell_start.y - 1, cell_end.y + 2):
		var world_y = y * cell_size
		var screen_pos_left = _world_to_screen(Vector2(world_top_left.x, world_y))
		var screen_pos_right = _world_to_screen(Vector2(world_bottom_right.x, world_y))

		# Asegurar que las líneas estén dentro del overlay
		var start_x = max(0, min(screen_pos_left.x, screen_pos_right.x))
		var end_x = min(overlay_size.x, max(screen_pos_left.x, screen_pos_right.x))

		if screen_pos_left.y >= 0 and screen_pos_left.y <= overlay_size.y and end_x > start_x:
			grid_overlay.draw_line(
				Vector2(start_x, screen_pos_left.y),
				Vector2(end_x, screen_pos_left.y),
				grid_color,
				1.0
			)

## Maneja el cierre de la ventana (botón X o cancelar)
func _on_close_requested() -> void:
	# Emitir señal de cancelación
	cancelled.emit()
	# Cerrar la ventana de forma segura
	hide()
	# Liberar la ventana después de un frame para evitar errores de X11
	call_deferred("queue_free")

## Maneja el botón cancelar
func _on_cancel_pressed() -> void:
	# Restaurar visibilidad de eventos ocultos
	_restore_events_visibility()
	# Emitir señal de cancelación
	cancelled.emit()
	# Cerrar la ventana de forma segura
	hide()
	# Liberar la ventana después de un frame para evitar errores de X11
	call_deferred("queue_free")

## Configura el tipo de movimiento para filtrar celdas válidas
## @param type: 1=RANDOM (cualquier celda), 5=RANDOM_VERTICAL (mismo X), 6=RANDOM_HORIZONTAL (mismo Y)
## @param event_pos: Posición del evento en coordenadas de tile
func set_movement_restriction(type: int, event_pos: Vector2i) -> void:
	movement_type = type
	event_tile_position = event_pos

	# Actualizar el label de instrucciones según el tipo
	if main_vbox:
		var label = main_vbox.get_child(0) as Label
		if label:
			match type:
				5:  # RANDOM_VERTICAL
					label.text = "Modo VERTICAL: Solo puedes seleccionar celdas en la misma columna (X=%d)" % event_pos.x
				6:  # RANDOM_HORIZONTAL
					label.text = "Modo HORIZONTAL: Solo puedes seleccionar celdas en la misma fila (Y=%d)" % event_pos.y
				_:  # RANDOM u otros
					label.text = "Vista del mapa - Haz click en una celda para seleccionarla"

	print("Event Tools: Restricción de movimiento configurada - tipo: %d, pos evento: %s" % [type, event_pos])


## Verifica si una celda es válida según el tipo de movimiento
func _is_cell_valid_for_movement(cell_pos: Vector2i) -> bool:
	match movement_type:
		5:  # RANDOM_VERTICAL - mismo X
			return cell_pos.x == event_tile_position.x
		6:  # RANDOM_HORIZONTAL - mismo Y
			return cell_pos.y == event_tile_position.y
		_:  # RANDOM u otros - cualquier celda
			return true


## Configura el modo de selección múltiple
func set_multiple_selection_mode(enabled: bool) -> void:
	multiple_selection_mode = enabled
	print("Event Tools: Modo múltiple ", "activado" if enabled else "desactivado")

	# Actualizar UI según el modo
	if main_vbox:
		var selected_label = main_vbox.get_node_or_null("SelectedCellLabel")
		var multiple_label = main_vbox.get_node_or_null("MultipleSelectionLabel")

		if enabled:
			# Modo múltiple: ocultar label simple, mostrar label múltiple
			if selected_label:
				selected_label.visible = false
			if multiple_label:
				multiple_label.visible = true
				_update_multiple_selection_label()
			if assign_button:
				assign_button.text = "Asignar celdas"
			# Ocultar el rectángulo temporal en modo múltiple
			if selected_cell_rect:
				selected_cell_rect.visible = false
		else:
			# Modo simple: mostrar label simple, ocultar label múltiple
			if selected_label:
				selected_label.visible = true
			if multiple_label:
				multiple_label.visible = false
			if assign_button:
				assign_button.text = "Asignar posición"

## Establece las celdas seleccionadas (para cargar desde el editor)
func set_selected_tiles(tiles: Array[Vector2i]) -> void:
	# Limpiar selecciones anteriores
	for tile in selected_tiles:
		_remove_tile_rect(tile)
	selected_tiles.clear()

	# Añadir las nuevas celdas
	for tile in tiles:
		selected_tiles.append(tile)
		_create_tile_rect(tile)

	_update_multiple_selection_label()

	# Habilitar el botón si hay celdas
	if assign_button:
		assign_button.disabled = selected_tiles.is_empty()

## Crea un rectángulo visual para una celda seleccionada
func _create_tile_rect(tile: Vector2i) -> void:
	if tile in selected_tiles_rects:
		return  # Ya existe

	# Crear un ColorRect similar al selected_cell_rect
	var rect = ColorRect.new()
	rect.color = Color(1.0, 0.0, 0.0, 0.6)  # Rojo, mismo color que el rectángulo temporal
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Añadir al grid_overlay
	if grid_overlay:
		grid_overlay.add_child(rect)
		selected_tiles_rects[tile] = rect
		_update_tile_rect_position(tile)

## Elimina el rectángulo visual de una celda
func _remove_tile_rect(tile: Vector2i) -> void:
	if tile in selected_tiles_rects:
		var rect = selected_tiles_rects[tile]
		if is_instance_valid(rect):
			rect.queue_free()
		selected_tiles_rects.erase(tile)

## Actualiza la posición de un rectángulo de celda seleccionada
func _update_tile_rect_position(tile: Vector2i) -> void:
	if not (tile in selected_tiles_rects):
		return

	var rect = selected_tiles_rects[tile]
	if not is_instance_valid(rect):
		selected_tiles_rects.erase(tile)
		return

	# Usar las mismas funciones de conversión que _update_selected_cell_rect
	var cell_world_center = _cell_to_world(tile)

	# Calcular las esquinas de la celda en coordenadas del mundo
	var half_cell_size = cell_size / 2.0
	var cell_world_top_left = cell_world_center - Vector2(half_cell_size, half_cell_size)
	var cell_world_bottom_right = cell_world_center + Vector2(half_cell_size, half_cell_size)

	# Convertir las esquinas a coordenadas de pantalla
	var cell_screen_top_left = _world_to_screen(cell_world_top_left)
	var cell_screen_bottom_right = _world_to_screen(cell_world_bottom_right)

	# Calcular tamaño y posición desde las esquinas
	var cell_screen_size = cell_screen_bottom_right - cell_screen_top_left
	var cell_screen_center = (cell_screen_top_left + cell_screen_bottom_right) / 2.0

	# Asegurar que el tamaño mínimo sea visible
	if cell_screen_size.x < 5:
		cell_screen_size.x = 5
	if cell_screen_size.y < 5:
		cell_screen_size.y = 5

	# Posicionar y dimensionar el ColorRect (coordenadas locales del wrapper)
	var rect_pos = cell_screen_center - cell_screen_size / 2.0
	rect.position = rect_pos
	rect.size = cell_screen_size
	rect.visible = true

## Actualiza todas las posiciones de los rectángulos de celdas seleccionadas
func _update_all_tile_rects() -> void:
	for tile in selected_tiles:
		_update_tile_rect_position(tile)

## Actualiza el label de selección múltiple
func _update_multiple_selection_label() -> void:
	if not main_vbox:
		return

	var multiple_label = main_vbox.get_node_or_null("MultipleSelectionLabel")
	if not multiple_label:
		return

	var count = selected_tiles.size()
	if count == 0:
		multiple_label.text = "Celdas seleccionadas: 0 (Click para añadir/quitar)"
	else:
		multiple_label.text = "Celdas seleccionadas: %d (Click para añadir/quitar)" % count

## Callback para el botón de zoom in
func _on_zoom_in_pressed() -> void:
	if camera:
		camera.zoom *= 1.2
	if grid_overlay:
		grid_overlay.queue_redraw()
	call_deferred("_update_selected_cell_rect")
	if multiple_selection_mode:
		call_deferred("_update_all_tile_rects")

## Callback para el botón de zoom out
func _on_zoom_out_pressed() -> void:
	if camera:
		camera.zoom /= 1.2
	if grid_overlay:
		grid_overlay.queue_redraw()
	call_deferred("_update_selected_cell_rect")
	if multiple_selection_mode:
		call_deferred("_update_all_tile_rects")

## Callback para el timer de redibujado
func _on_redraw_timer_timeout() -> void:
	if grid_overlay and is_instance_valid(grid_overlay):
		grid_overlay.queue_redraw()
	if selected_cell_rect and is_instance_valid(selected_cell_rect):
		call_deferred("_update_selected_cell_rect")

## Mueve la cámara en una dirección específica
func _move_camera(direction: Vector2) -> void:
	if not camera:
		return

	# Calcular el desplazamiento basado en el tamaño del viewport y el zoom
	var viewport_size: Vector2
	if map_viewport:
		viewport_size = Vector2(map_viewport.size)
	else:
		viewport_size = Vector2(800, 600)
	# Mover una fracción más pequeña del viewport (1/12 del tamaño visible para movimiento más preciso)
	var move_distance = viewport_size / camera.zoom / 12.0
	camera.position += direction * move_distance

	# Redibujar el overlay
	if grid_overlay:
		grid_overlay.queue_redraw()
	call_deferred("_update_selected_cell_rect")
	if multiple_selection_mode:
		call_deferred("_update_all_tile_rects")

## Oculta todos los eventos excepto el activo
func _hide_other_events() -> void:
	if not edited_scene_root or not active_event:
		return

	hidden_events.clear()

	# Buscar todos los eventos en la escena
	var all_events = _find_all_events(edited_scene_root)

	for event in all_events:
		if event != active_event and is_instance_valid(event):
			# Guardar el estado de visibilidad actual
			if event.visible:
				hidden_events.append(event)
				# Ocultar el evento
				event.visible = false

## Restaura la visibilidad de los eventos ocultos
func _restore_events_visibility() -> void:
	for event in hidden_events:
		if is_instance_valid(event):
			event.visible = true
	hidden_events.clear()

## Busca todos los eventos en la escena
func _find_all_events(root: Node) -> Array[Event]:
	var events: Array[Event] = []

	# Buscar en el grupo de eventos
	if root.get_tree():
		var events_in_group = root.get_tree().get_nodes_in_group("events")
		for node in events_in_group:
			if node is Event and is_instance_valid(node):
				events.append(node)

	# También buscar recursivamente en la escena
	_find_events_recursive(root, events)

	return events

## Busca eventos recursivamente en un nodo y sus hijos
func _find_events_recursive(node: Node, events: Array[Event]) -> void:
	if node is Event and is_instance_valid(node) and not node in events:
		events.append(node)

	for child in node.get_children():
		_find_events_recursive(child, events)

