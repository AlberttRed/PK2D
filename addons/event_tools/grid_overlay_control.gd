@tool
extends Control

## Control personalizado para dibujar la cuadrícula del mapa
var parent_window: Window = null

func _ready() -> void:
	if has_meta("parent_window"):
		parent_window = get_meta("parent_window")

func _draw() -> void:
	if not parent_window:
		return

	var cell_size = parent_window.cell_size
	var selected_cell = parent_window.selected_cell
	var camera = parent_window.camera
	var map_viewport = parent_window.map_viewport

	if not camera or not map_viewport:
		return

	var overlay_size = size
	if overlay_size.x <= 0 or overlay_size.y <= 0:
		return

	# Calcular el área visible en coordenadas del mundo
	var camera_center = camera.get_screen_center_position()
	var viewport_size = map_viewport.size
	var world_top_left = camera_center - (viewport_size / 2.0) / camera.zoom
	var world_bottom_right = camera_center + (viewport_size / 2.0) / camera.zoom

	# Convertir a celdas
	var cell_start = parent_window._world_to_cell(world_top_left)
	var cell_end = parent_window._world_to_cell(world_bottom_right)

	# Dibujar cuadrícula
	var grid_color = Color(1.0, 1.0, 1.0, 0.3)  # Blanco semitransparente
	var selected_color = Color(1.0, 1.0, 0.0, 0.5)  # Amarillo para la celda seleccionada

	# Dibujar líneas de la cuadrícula
	for x in range(cell_start.x - 1, cell_end.x + 2):
		var world_x = x * cell_size
		var screen_pos = parent_window._world_to_screen(Vector2(world_x, 0))
		if screen_pos.x >= 0 and screen_pos.x <= overlay_size.x:
			draw_line(
				Vector2(screen_pos.x, 0),
				Vector2(screen_pos.x, overlay_size.y),
				grid_color,
				1.0
			)

	for y in range(cell_start.y - 1, cell_end.y + 2):
		var world_y = y * cell_size
		var screen_pos = parent_window._world_to_screen(Vector2(0, world_y))
		if screen_pos.y >= 0 and screen_pos.y <= overlay_size.y:
			draw_line(
				Vector2(0, screen_pos.y),
				Vector2(overlay_size.x, screen_pos.y),
				grid_color,
				1.0
			)

	# Dibujar celda seleccionada
	if selected_cell.x >= 0 and selected_cell.y >= 0:
		var cell_world_pos = parent_window._cell_to_world(selected_cell)
		var cell_screen_pos = parent_window._world_to_screen(cell_world_pos)
		var cell_screen_size = Vector2(cell_size, cell_size) / camera.zoom

		# Dibujar rectángulo de la celda seleccionada
		var rect = Rect2(
			cell_screen_pos - cell_screen_size / 2.0,
			cell_screen_size
		)
		draw_rect(rect, selected_color, false, 2.0)
		draw_rect(rect, Color(selected_color.r, selected_color.g, selected_color.b, 0.2), true)

