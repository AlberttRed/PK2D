@tool
extends Window

## Ventana para mostrar el mapa de la escena actual
var overworld_grid: OverworldGrid = null
var edited_scene_root: Node2D = null

var viewport_wrapper: Control = null
var viewport_container: SubViewportContainer = null
var map_viewport: SubViewport = null
var map_instance: Node2D = null
var camera: Camera2D = null
var grid_overlay: Control = null
var selected_cell_rect: ColorRect = null
var selected_cell: Vector2i = Vector2i(-1, -1)
var cell_size: int = 32
var main_vbox: VBoxContainer = null
var reference_tile_layer: TileMapLayer = null  # Capa de referencia para conversión de coordenadas
var assign_button: Button = null  # Botón para asignar la posición

## Señal emitida cuando se selecciona una celda
signal cell_selected(cell_pos: Vector2i)

func _ready() -> void:
	print("Event Tools: position_selector_window._ready() llamado")
	title = "Vista del Mapa"
	size = Vector2i(800, 600)
	min_size = Vector2i(400, 300)
	unresizable = false

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
	size_changed.connect(func():
		if grid_overlay:
			grid_overlay.queue_redraw()
		if selected_cell_rect:
			_update_selected_cell_rect()
	)

	# Botones de control
	var hbox = HBoxContainer.new()

	var zoom_in_btn = Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.pressed.connect(func():
		camera.zoom *= 1.2
		if grid_overlay:
			grid_overlay.queue_redraw()
	)
	hbox.add_child(zoom_in_btn)

	var zoom_out_btn = Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.pressed.connect(func():
		camera.zoom /= 1.2
		if grid_overlay:
			grid_overlay.queue_redraw()
	)
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

	# Botón Cancelar
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.pressed.connect(func(): hide())
	hbox.add_child(cancel_btn)

	# Botón Asignar posición
	assign_button = Button.new()
	assign_button.text = "Asignar posición"
	assign_button.disabled = true  # Inicialmente deshabilitado
	assign_button.pressed.connect(_on_assign_button_pressed)
	hbox.add_child(assign_button)

	main_vbox.add_child(hbox)

	# Conectar señal de redimensionamiento
	size_changed.connect(_on_window_size_changed)

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
	if not selected_cell_rect or not camera or not map_viewport or not viewport_wrapper:
		return

	if selected_cell.x < 0 or selected_cell.y < 0:
		selected_cell_rect.visible = false
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
		redraw_timer.timeout.connect(func():
			if grid_overlay and is_instance_valid(grid_overlay):
				grid_overlay.queue_redraw()
			if selected_cell_rect and is_instance_valid(selected_cell_rect):
				_update_selected_cell_rect()
		)
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

func setup(overworld_grid_node: OverworldGrid, scene_root: Node2D) -> void:
	overworld_grid = overworld_grid_node
	edited_scene_root = scene_root

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
	# Verificar que hay una celda seleccionada
	if selected_cell.x < 0 or selected_cell.y < 0:
		return

	# Emitir señal de celda seleccionada
	cell_selected.emit(selected_cell)

	# Cerrar la ventana
	hide()

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
	# Convertir directamente de coordenadas de pantalla a coordenadas de celda usando el TileMapLayer
	var cell_pos: Vector2i

	if reference_tile_layer and camera and map_viewport:
		# Convertir coordenadas de pantalla a coordenadas del viewport
		var container_offset = viewport_container.position
		var adjusted_screen_pos = screen_pos - container_offset

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
		# El viewport tiene su origen en (0,0) en la esquina superior izquierda
		# El centro del viewport está en (viewport_size.x/2, viewport_size.y/2)
		var relative_pos = viewport_local_pos - viewport_size / 2.0

		# Obtener la posición del centro de la pantalla en coordenadas del mundo
		# camera.get_screen_center_position() devuelve la posición del centro de la pantalla
		# en coordenadas relativas al map_instance (OverworldGrid)
		var camera_center_world = camera.get_screen_center_position()

		# Convertir a coordenadas del mundo usando el zoom de la cámara
		# relative_pos está en píxeles de pantalla, necesitamos convertirlo a píxeles del mundo
		var world_pos = camera_center_world + relative_pos / camera.zoom

		# Convertir coordenadas del mundo a coordenadas locales del TileMapLayer
		# world_pos está en coordenadas relativas al map_instance (OverworldGrid)
		# El TileMapLayer está dentro del map_instance y tiene su origen en (0,0)
		# to_local() convierte de coordenadas del map_instance a coordenadas locales del TileMapLayer
		var local_pos = reference_tile_layer.to_local(world_pos)

		# Convertir a coordenadas de tile
		# local_to_map() convierte coordenadas locales del TileMapLayer a coordenadas de tile
		# El TileMapLayer tiene su origen en (0,0) en la esquina superior izquierda
		var tile_pos = reference_tile_layer.local_to_map(local_pos)

		# Obtener el used_rect para ajustar el offset
		# Si el TileMapLayer tiene tiles que empiezan en coordenadas negativas,
		# necesitamos ajustar para que el 0,0 esté en la esquina superior izquierda del mapa visible
		var used_rect = reference_tile_layer.get_used_rect()
		if used_rect.position.x < 0 or used_rect.position.y < 0:
			# Ajustar el tile_pos para que el 0,0 esté en la esquina superior izquierda del mapa visible
			# Restamos el offset negativo para que el tile (0,0) del TileMapLayer se convierta en (0,0) del mapa visible
			cell_pos = tile_pos - used_rect.position
		else:
			cell_pos = tile_pos

		print("Event Tools: screen_pos: ", screen_pos, ", viewport_local_pos: ", viewport_local_pos, ", viewport_size: ", viewport_size, ", relative_pos: ", relative_pos, ", camera_center_world: ", camera_center_world, ", camera.position: ", camera.position, ", zoom: ", camera.zoom, ", world_pos: ", world_pos, ", local_pos: ", local_pos, ", tile_pos: ", tile_pos, ", used_rect: ", used_rect, ", cell_pos: ", cell_pos)
	else:
		# Fallback: usar el método anterior
		var world_pos = _screen_to_world_position(screen_pos)
		cell_pos = _world_to_cell(world_pos)
		print("Event Tools: Click detectado - celda: ", cell_pos)

	# Actualizar celda seleccionada
	selected_cell = cell_pos

	# Actualizar label
	if main_vbox:
		var selected_label = main_vbox.get_node_or_null("SelectedCellLabel")
		if selected_label:
			selected_label.text = "Celda seleccionada: (%d, %d)" % [cell_pos.x, cell_pos.y]

	# Actualizar el rectángulo de la celda seleccionada
	_update_selected_cell_rect()

	# Redibujar el overlay
	if grid_overlay:
		grid_overlay.queue_redraw()

	# Habilitar el botón de asignar posición
	if assign_button:
		assign_button.disabled = false

func _on_window_size_changed() -> void:
	# Actualizar el tamaño del viewport cuando cambie el tamaño de la ventana
	call_deferred("_update_viewport_size")
	if grid_overlay:
		grid_overlay.queue_redraw()

func _on_grid_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# mouse_event.position está en coordenadas locales del grid_overlay
			# Como el grid_overlay tiene PRESET_FULL_RECT, sus coordenadas coinciden con el wrapper
			var local_pos = mouse_event.position
			_handle_click(local_pos)
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
		var tile_pos = reference_tile_layer.local_to_map(local_pos)
		print("Event Tools: _world_to_cell - world_pos: ", world_pos, ", local_pos: ", local_pos, ", tile_pos: ", tile_pos)
		return tile_pos
	else:
		# Fallback: calcular directamente
		# Las coordenadas del mundo ya están relativas al origen (0,0)
		var cell_x = int(floor(world_pos.x / cell_size))
		var cell_y = int(floor(world_pos.y / cell_size))
		return Vector2i(cell_x, cell_y)

func _cell_to_world(cell_pos: Vector2i) -> Vector2:
	# Convertir coordenadas de celda a posición del mundo (centro de la celda)
	# cell_pos está ajustado (0,0 es la esquina superior izquierda del mapa visible)
	# Necesitamos convertirlo de vuelta a las coordenadas reales del TileMapLayer
	var tile_pos: Vector2i
	if reference_tile_layer:
		var used_rect = reference_tile_layer.get_used_rect()
		if used_rect.position.x < 0 or used_rect.position.y < 0:
			# Ajustar de vuelta a las coordenadas reales del TileMapLayer
			tile_pos = cell_pos + used_rect.position
		else:
			tile_pos = cell_pos

		# Convertir coordenadas de tile a coordenadas locales del TileMapLayer
		var local_pos = reference_tile_layer.map_to_local(tile_pos)
		# Convertir a coordenadas globales del TileMapLayer (que es relativo al map_instance)
		# Esto devuelve coordenadas relativas al map_instance con origen en (0,0)
		return reference_tile_layer.to_global(local_pos)
	else:
		# Fallback: calcular directamente
		# Las coordenadas del mundo son relativas al origen (0,0)
		return Vector2(cell_pos.x * cell_size + cell_size / 2.0, cell_pos.y * cell_size + cell_size / 2.0)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	if not camera or not map_viewport or not viewport_container:
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
	if selected_cell.x >= 0 and selected_cell.y >= 0:
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

