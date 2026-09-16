@tool
extends Window

## Editor para SetRespawnCommand: mapa + tile (selector) + facing.

signal command_edited(command: SetRespawnCommand)
signal cancelled

var command: SetRespawnCommand = null
var _event_node: Node = null

var event_node: Node:
	get:
		return _event_node
	set(value):
		_event_node = value
		if map_option:
			_populate_map_names()
			if command:
				_set_option_selection(map_option, command.map_id if not command.map_id.is_empty() else _get_current_map_name())

var original_map_id: String = ""
var original_target_tile: Vector2i = Vector2i.ZERO
var original_facing: int = 0
var original_tag: String = ""

var map_option: OptionButton = null
var facing_option: OptionButton = null
var tag_edit: LineEdit = null
var tile_label: Label = null
var select_tile_button: Button = null
var accept_button: Button = null

var _cached_overworld_scene: PackedScene = null


func _ready() -> void:
	title = "Editar SetRespawnCommand"
	size = Vector2(480, 300)
	unresizable = false
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
	title_label.text = "SetRespawnCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var hint = Label.new()
	hint.text = "Punto de blanqueo (mapa + tile + dirección). Tag opcional para condiciones (variable RESPAWN_TAG)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(hint)

	map_option = _create_labeled_option("Mapa:", vbox)
	map_option.item_selected.connect(func(_i): _update_accept_button_state())
	call_deferred("_populate_map_names")

	var tile_row = HBoxContainer.new()
	var tile_pos_label = Label.new()
	tile_pos_label.text = "Posición tile:"
	tile_pos_label.custom_minimum_size.x = 150
	tile_row.add_child(tile_pos_label)
	tile_label = Label.new()
	tile_label.text = "(no seleccionado)"
	tile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_row.add_child(tile_label)
	select_tile_button = Button.new()
	select_tile_button.text = "Seleccionar..."
	select_tile_button.pressed.connect(_on_select_tile_pressed)
	tile_row.add_child(select_tile_button)
	vbox.add_child(tile_row)

	facing_option = _create_labeled_option("Dirección:", vbox)
	facing_option.add_item("Arriba")
	facing_option.add_item("Abajo")
	facing_option.add_item("Izquierda")
	facing_option.add_item("Derecha")

	var tag_row = HBoxContainer.new()
	var tag_label = Label.new()
	tag_label.text = "Tag:"
	tag_label.custom_minimum_size.x = 150
	tag_row.add_child(tag_label)
	tag_edit = LineEdit.new()
	tag_edit.placeholder_text = "p. ej. verde, plateada…"
	tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_row.add_child(tag_edit)
	vbox.add_child(tag_row)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons.add_child(accept_button)
	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_button)
	vbox.add_child(buttons)


func _create_labeled_option(label_text: String, parent: Container) -> OptionButton:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	container.add_child(label)
	var option = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(option)
	parent.add_child(container)
	return option


func _get_current_grid() -> Node:
	if not _event_node:
		return null
	var parent = _event_node.get_parent()
	if parent and parent.name == "Events":
		var grid = parent.get_parent()
		if grid and grid.is_in_group("OverworldGrid"):
			return grid
	return null


func _get_current_map_scene() -> Node:
	var grid = _get_current_grid()
	if grid:
		var map_scene = grid.get_parent()
		if map_scene and map_scene.get_script() and map_scene.get_script().get_global_name() == "MapScene":
			return map_scene
	return null


func _get_current_map_name() -> String:
	var map_scene = _get_current_map_scene()
	if map_scene:
		var map_id = map_scene.get("map_id")
		if map_id and map_id != "":
			return str(map_id)
		return map_scene.name
	return ""


func _set_option_selection(option: OptionButton, value: String, default_index: int = 0) -> void:
	if not option:
		return
	var selected_index = default_index
	if value != "":
		var found = false
		for i in range(option.get_item_count()):
			if option.get_item_text(i) == value:
				selected_index = i
				found = true
				break
		if not found:
			option.add_item(value)
			selected_index = option.get_item_count() - 1
	option.selected = selected_index


func _get_option_text(option: OptionButton, default_value: String = "") -> String:
	if not option:
		return default_value
	var selected_index = option.selected
	if selected_index >= 0 and selected_index < option.get_item_count():
		return option.get_item_text(selected_index)
	return default_value


func _get_world_system() -> Node:
	const OVERWORLD_SCENE = "res://Scenes/Overworld/Overworld.tscn"
	if not _cached_overworld_scene:
		_cached_overworld_scene = load(OVERWORLD_SCENE) as PackedScene
	if not _cached_overworld_scene:
		return null
	var overworld_instance = _cached_overworld_scene.instantiate()
	if not overworld_instance:
		return null
	var world_system = overworld_instance.get_node_or_null("WorldSystem")
	overworld_instance.queue_free()
	return world_system


func _populate_map_names() -> void:
	if not map_option:
		return
	map_option.clear()
	var current_map_name = _get_current_map_name()
	if current_map_name != "":
		map_option.add_item(current_map_name)
	var world_system = _get_world_system()
	if world_system:
		var world_map_scenes = world_system.get("world_map_scenes")
		if world_map_scenes != null and world_map_scenes is Array:
			for packed_scene in world_map_scenes:
				if packed_scene is PackedScene:
					var scene_path = packed_scene.resource_path
					if scene_path:
						var file_name = scene_path.get_file().get_basename()
						if file_name != "" and file_name != current_map_name:
							map_option.add_item(file_name)


func _load_map_grid(map_name: String) -> Node:
	var world_system = _get_world_system()
	if not world_system:
		return null
	var world_map_scenes = world_system.get("world_map_scenes")
	if world_map_scenes == null or not world_map_scenes is Array:
		return null
	for packed_scene in world_map_scenes:
		if packed_scene is PackedScene:
			var scene_path = packed_scene.resource_path
			if scene_path:
				var file_name = scene_path.get_file().get_basename()
				if file_name == map_name:
					var map_instance = packed_scene.instantiate()
					if map_instance:
						var grid = map_instance.get_node_or_null("OverworldGrid")
						if grid:
							map_instance.remove_child(grid)
							map_instance.queue_free()
							return grid
						map_instance.queue_free()
					break
	return null


func load_command(cmd: SetRespawnCommand) -> void:
	if not cmd:
		push_error("SetRespawnCommandEditor: comando inválido")
		return
	command = cmd
	original_map_id = cmd.map_id
	original_target_tile = cmd.target_tile
	original_facing = int(cmd.facing_direction)
	original_tag = cmd.tag

	if map_option:
		if map_option.get_item_count() == 0:
			_populate_map_names()
		var map_to_select := cmd.map_id if not cmd.map_id.is_empty() else _get_current_map_name()
		_set_option_selection(map_option, map_to_select)

	if tile_label:
		if cmd.target_tile != Vector2i.ZERO:
			tile_label.text = "(%d, %d)" % [cmd.target_tile.x, cmd.target_tile.y]
		else:
			tile_label.text = "(no seleccionado)"

	if facing_option:
		facing_option.selected = clampi(int(cmd.facing_direction), 0, 3)

	if tag_edit:
		tag_edit.text = cmd.tag

	_update_accept_button_state()


func _apply() -> void:
	if not command:
		return
	command.map_id = _get_option_text(map_option, _get_current_map_name())
	# target_tile se actualiza al seleccionar en el mapa
	if facing_option:
		command.facing_direction = facing_option.selected as SetRespawnCommand.FacingDirection
	if tag_edit:
		command.tag = tag_edit.text.strip_edges()


func _restore() -> void:
	if not command:
		return
	command.map_id = original_map_id
	command.target_tile = original_target_tile
	command.facing_direction = original_facing as SetRespawnCommand.FacingDirection
	command.tag = original_tag
	if map_option:
		_set_option_selection(map_option, original_map_id if not original_map_id.is_empty() else _get_current_map_name())
	if tile_label:
		if original_target_tile != Vector2i.ZERO:
			tile_label.text = "(%d, %d)" % [original_target_tile.x, original_target_tile.y]
		else:
			tile_label.text = "(no seleccionado)"
	if facing_option:
		facing_option.selected = clampi(original_facing, 0, 3)
	if tag_edit:
		tag_edit.text = original_tag


func _update_accept_button_state() -> void:
	if not accept_button:
		return
	var has_map := not _get_option_text(map_option).is_empty()
	var has_tile := command != null and command.target_tile != Vector2i.ZERO
	accept_button.disabled = not (has_map and has_tile)


func _on_select_tile_pressed() -> void:
	var target_map_name = _get_option_text(map_option, _get_current_map_name())
	if target_map_name.is_empty():
		push_error("SetRespawnCommandEditor: No se pudo determinar el mapa")
		return

	var grid = _load_map_grid(target_map_name)
	if not grid:
		push_error("SetRespawnCommandEditor: No se pudo cargar OverworldGrid de: " + target_map_name)
		return

	var selector_script = load("res://addons/event_tools/position_selector_window.gd")
	if not selector_script:
		push_error("SetRespawnCommandEditor: No se encontró position_selector_window.gd")
		return

	var selector_window = selector_script.new()
	add_child(selector_window)

	await selector_window.setup(grid, grid.get_parent(), null)
	selector_window.set_multiple_selection_mode(false)

	if command and command.target_tile != Vector2i.ZERO:
		selector_window.selected_cell = command.target_tile

	selector_window.cell_selected.connect(func(cell_pos: Vector2i):
		if command:
			command.target_tile = cell_pos
		if tile_label:
			tile_label.text = "(%d, %d)" % [cell_pos.x, cell_pos.y]
		_update_accept_button_state()
		selector_window.queue_free()
	)
	selector_window.cancelled.connect(func():
		selector_window.queue_free()
	)
	selector_window.popup_centered()


func _on_accept_pressed() -> void:
	_apply()
	command_edited.emit(command)
	hide()


func _on_cancel_pressed() -> void:
	_restore()
	cancelled.emit()
	hide()


func _on_close_requested() -> void:
	_restore()
	cancelled.emit()
	hide()
