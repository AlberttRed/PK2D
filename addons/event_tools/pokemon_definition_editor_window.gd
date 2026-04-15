@tool
extends Window
class_name PokemonDefinitionEditorWindow

signal saved(definition: PokemonDefinition)
signal cancelled()

var _definition: PokemonDefinition = null

var _pokemon_id_option: OptionButton
var _level_spin: SpinBox
var _nickname_edit: LineEdit
var _gender_option: OptionButton
var _shiny_check: CheckBox
var _is_wild_check: CheckBox

var _randomize_ivs_check: CheckBox
var _hp_ivs_spin: SpinBox
var _attack_ivs_spin: SpinBox
var _defense_ivs_spin: SpinBox
var _sp_attack_ivs_spin: SpinBox
var _sp_defense_ivs_spin: SpinBox
var _speed_ivs_spin: SpinBox

var _randomize_evs_check: CheckBox
var _hp_evs_spin: SpinBox
var _attack_evs_spin: SpinBox
var _defense_evs_spin: SpinBox
var _sp_attack_evs_spin: SpinBox
var _sp_defense_evs_spin: SpinBox
var _speed_evs_spin: SpinBox

var _nature_option: OptionButton
var _ability_option: OptionButton
var _moves_list: ItemList
var _add_move_button: Button
var _edit_move_button: Button
var _remove_move_button: Button
var _held_item_option: OptionButton
var _move_ids: Array[MovesEnum.Values] = []
var _move_names_by_id: Dictionary = {}

func _ready() -> void:
	title = "Editar PokemonDefinition"
	size = Vector2i(680, 760)
	close_requested.connect(_on_close_requested)
	_build_ui()

func open_for_definition(definition: PokemonDefinition, window_title: String = "Editar PokemonDefinition") -> void:
	_definition = definition
	title = window_title
	_load_to_ui()
	popup_centered(size)

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_top = 8
	root.offset_right = -8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	content.add_child(_section_title("Datos Base"))
	_pokemon_id_option = _add_pokemon_row(content)

	content.add_child(_section_title("Informacion Basica"))
	_level_spin = _add_spin_row(content, "Nivel", 1, 100, 5)
	_nickname_edit = _add_line_row(content, "Apodo", "Sin apodo")
	_gender_option = _add_gender_row(content)
	_shiny_check = _add_check_row(content, "Shiny")
	_is_wild_check = _add_check_row(content, "Es salvaje")

	content.add_child(_section_title("IVs"))
	_randomize_ivs_check = _add_check_row(content, "Aleatorizar IVs")
	_hp_ivs_spin = _add_spin_row(content, "HP IVs", 0, 31, 0)
	_attack_ivs_spin = _add_spin_row(content, "Attack IVs", 0, 31, 0)
	_defense_ivs_spin = _add_spin_row(content, "Defense IVs", 0, 31, 0)
	_sp_attack_ivs_spin = _add_spin_row(content, "SpAttack IVs", 0, 31, 0)
	_sp_defense_ivs_spin = _add_spin_row(content, "SpDefense IVs", 0, 31, 0)
	_speed_ivs_spin = _add_spin_row(content, "Speed IVs", 0, 31, 0)

	content.add_child(_section_title("EVs"))
	_randomize_evs_check = _add_check_row(content, "Aleatorizar EVs")
	_hp_evs_spin = _add_spin_row(content, "HP EVs", 0, 252, 0)
	_attack_evs_spin = _add_spin_row(content, "Attack EVs", 0, 252, 0)
	_defense_evs_spin = _add_spin_row(content, "Defense EVs", 0, 252, 0)
	_sp_attack_evs_spin = _add_spin_row(content, "SpAttack EVs", 0, 252, 0)
	_sp_defense_evs_spin = _add_spin_row(content, "SpDefense EVs", 0, 252, 0)
	_speed_evs_spin = _add_spin_row(content, "Speed EVs", 0, 252, 0)

	content.add_child(_section_title("Naturaleza y Habilidad"))
	_nature_option = _add_nature_row(content)
	_ability_option = _add_ability_row(content)

	content.add_child(_section_title("Moveset"))
	_build_moveset_ui(content)

	content.add_child(_section_title("Otros"))
	_held_item_option = _add_item_row(content)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	var save_btn := Button.new()
	save_btn.text = "Aceptar"
	save_btn.pressed.connect(_on_accept_pressed)
	buttons.add_child(save_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_btn)

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	return label

func _add_spin_row(parent: VBoxContainer, label_text: String, min_v: int, max_v: int, default_v: int) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(170, 0)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.value = default_v
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(spin)
	parent.add_child(row)
	return spin

func _add_pokemon_row(parent: VBoxContainer) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Pokemon:"
	label.custom_minimum_size = Vector2(170, 0)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(option)
	parent.add_child(row)
	_populate_pokemon_options(option)
	return option

func _add_item_row(parent: VBoxContainer) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Held Item:"
	label.custom_minimum_size = Vector2(170, 0)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(option)
	parent.add_child(row)
	_populate_item_options(option)
	return option

func _populate_pokemon_options(option: OptionButton) -> void:
	option.clear()
	var dir_path := "res://Resources/Data/Pokemon"
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		option.add_item("001 - Bulbasaur", 1)
		return

	var entries: Array[Dictionary] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var file_base := file_name.get_basename()
			var parts := file_base.split(" - ", false, 1)
			if parts.size() > 0:
				var id_str := parts[0].strip_edges()
				if id_str.is_valid_int():
					var pid := int(id_str)
					var display := file_base
					if parts.size() == 1:
						display = "%03d - Pokemon #%d" % [pid, pid]
					entries.append({
						"id": pid,
						"text": display
					})
		file_name = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0)))
	for entry in entries:
		option.add_item(str(entry.get("text", "")), int(entry.get("id", 0)))

	if option.item_count == 0:
		option.add_item("001 - Bulbasaur", 1)

func _populate_item_options(option: OptionButton) -> void:
	option.clear()
	option.add_item("000 - Sin objeto", 0)

	var dir_path := "res://Resources/Data/Items"
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		return

	var entries: Array[Dictionary] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var file_base := file_name.get_basename()
			var parts := file_base.split(" - ", false, 1)
			if parts.size() > 0:
				var id_str := parts[0].strip_edges()
				if id_str.is_valid_int():
					var iid := int(id_str)
					var display := file_base
					if parts.size() == 1:
						display = "%03d - Item #%d" % [iid, iid]
					entries.append({
						"id": iid,
						"text": display
					})
		file_name = dir.get_next()
	dir.list_dir_end()

	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0)))
	for entry in entries:
		option.add_item(str(entry.get("text", "")), int(entry.get("id", 0)))

func _build_moveset_ui(parent: VBoxContainer) -> void:
	_load_move_names()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_moves_list = ItemList.new()
	_moves_list.custom_minimum_size = Vector2(0, 120)
	_moves_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_moves_list)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	row.add_child(buttons)

	_add_move_button = Button.new()
	_add_move_button.text = "Añadir"
	_add_move_button.pressed.connect(_on_add_move_pressed)
	buttons.add_child(_add_move_button)

	_edit_move_button = Button.new()
	_edit_move_button.text = "Editar"
	_edit_move_button.pressed.connect(_on_edit_move_pressed)
	buttons.add_child(_edit_move_button)

	_remove_move_button = Button.new()
	_remove_move_button.text = "Eliminar"
	_remove_move_button.pressed.connect(_on_remove_move_pressed)
	buttons.add_child(_remove_move_button)

func _add_line_row(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(170, 0)
	var line := LineEdit.new()
	line.placeholder_text = placeholder
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(line)
	parent.add_child(row)
	return line

func _add_check_row(parent: VBoxContainer, label_text: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = label_text
	parent.add_child(check)
	return check

func _add_gender_row(parent: VBoxContainer) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Genero:"
	label.custom_minimum_size = Vector2(170, 0)
	var option := OptionButton.new()
	option.add_item("Sin indicar", 0)
	option.add_item("Macho", 1)
	option.add_item("Hembra", 2)
	option.add_item("Sin genero", 3)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(option)
	parent.add_child(row)
	return option

func _add_nature_row(parent: VBoxContainer) -> OptionButton:
	return _add_enum_option_row(parent, "Naturaleza", NaturesEnum.Values)

func _add_ability_row(parent: VBoxContainer) -> OptionButton:
	return _add_enum_option_row(parent, "Habilidad", AbilitiesEnum.Values)

func _add_enum_option_row(parent: VBoxContainer, label_text: String, enum_values: Dictionary) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(170, 0)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(option)
	parent.add_child(row)

	var entries: Array[Dictionary] = []
	for key in enum_values.keys():
		entries.append({
			"id": int(enum_values[key]),
			"key": str(key)
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0)))
	for entry in entries:
		option.add_item(_format_enum_label(str(entry.get("key", ""))), int(entry.get("id", 0)))

	return option

func _format_enum_label(raw: String) -> String:
	return raw.replace("_", " ").to_lower().capitalize()

func _select_option_by_id(option: OptionButton, target_id: int) -> void:
	if option == null or option.item_count == 0:
		return
	for i in range(option.item_count):
		if option.get_item_id(i) == target_id:
			option.select(i)
			return
	option.select(0)

func _get_selected_option_id(option: OptionButton) -> int:
	if option == null or option.item_count == 0:
		return 0
	var selected := option.selected
	if selected < 0:
		return option.get_item_id(0)
	return option.get_item_id(selected)

func _load_to_ui() -> void:
	if _definition == null:
		return
	_select_pokemon_id(int(_definition.pokemon_id))
	_level_spin.value = _definition.level
	_nickname_edit.text = _definition.nickname
	_gender_option.selected = _definition.gender
	_shiny_check.button_pressed = _definition.shiny
	_is_wild_check.button_pressed = _definition.is_wild

	_randomize_ivs_check.button_pressed = _definition.randomize_ivs
	_hp_ivs_spin.value = _definition.hp_IVs
	_attack_ivs_spin.value = _definition.attack_IVs
	_defense_ivs_spin.value = _definition.defense_IVs
	_sp_attack_ivs_spin.value = _definition.spAttack_IVs
	_sp_defense_ivs_spin.value = _definition.spDefense_IVs
	_speed_ivs_spin.value = _definition.speed_IVs

	_randomize_evs_check.button_pressed = _definition.randomize_evs
	_hp_evs_spin.value = _definition.hp_EVs
	_attack_evs_spin.value = _definition.attack_EVs
	_defense_evs_spin.value = _definition.defense_EVs
	_sp_attack_evs_spin.value = _definition.spAttack_EVs
	_sp_defense_evs_spin.value = _definition.spDefense_EVs
	_speed_evs_spin.value = _definition.speed_EVs

	_select_option_by_id(_nature_option, int(_definition.nature_id))
	_select_option_by_id(_ability_option, int(_definition.ability_id))
	_move_ids = _definition.custom_move_ids.duplicate()
	_refresh_moves_list()
	_select_item_id(_definition.held_item_id)

func _apply_from_ui() -> void:
	if _definition == null:
		return
	_definition.pokemon_id = _get_selected_pokemon_id() as PokemonsEnum.Values
	_definition.level = int(_level_spin.value)
	_definition.nickname = _nickname_edit.text.strip_edges()
	_definition.gender = _gender_option.selected
	_definition.shiny = _shiny_check.button_pressed
	_definition.is_wild = _is_wild_check.button_pressed

	_definition.randomize_ivs = _randomize_ivs_check.button_pressed
	_definition.hp_IVs = int(_hp_ivs_spin.value)
	_definition.attack_IVs = int(_attack_ivs_spin.value)
	_definition.defense_IVs = int(_defense_ivs_spin.value)
	_definition.spAttack_IVs = int(_sp_attack_ivs_spin.value)
	_definition.spDefense_IVs = int(_sp_defense_ivs_spin.value)
	_definition.speed_IVs = int(_speed_ivs_spin.value)

	_definition.randomize_evs = _randomize_evs_check.button_pressed
	_definition.hp_EVs = int(_hp_evs_spin.value)
	_definition.attack_EVs = int(_attack_evs_spin.value)
	_definition.defense_EVs = int(_defense_evs_spin.value)
	_definition.spAttack_EVs = int(_sp_attack_evs_spin.value)
	_definition.spDefense_EVs = int(_sp_defense_evs_spin.value)
	_definition.speed_EVs = int(_speed_evs_spin.value)

	_definition.nature_id = _get_selected_option_id(_nature_option) as NaturesEnum.Values
	_definition.ability_id = _get_selected_option_id(_ability_option) as AbilitiesEnum.Values
	_definition.custom_move_ids = _move_ids.duplicate()
	_definition.held_item_id = _get_selected_item_id()

func _on_accept_pressed() -> void:
	_apply_from_ui()
	saved.emit(_definition)
	queue_free()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()

func _select_pokemon_id(pokemon_id: int) -> void:
	var index := -1
	for i in range(_pokemon_id_option.item_count):
		if _pokemon_id_option.get_item_id(i) == pokemon_id:
			index = i
			break
	if index == -1:
		_pokemon_id_option.add_item("%03d - Pokemon #%d" % [pokemon_id, pokemon_id], pokemon_id)
		index = _pokemon_id_option.item_count - 1
	_pokemon_id_option.select(index)

func _get_selected_pokemon_id() -> int:
	if _pokemon_id_option == null or _pokemon_id_option.item_count == 0:
		return 1
	var selected := _pokemon_id_option.selected
	if selected < 0:
		return 1
	return _pokemon_id_option.get_item_id(selected)

func _select_item_id(item_id: int) -> void:
	var index := -1
	for i in range(_held_item_option.item_count):
		if _held_item_option.get_item_id(i) == item_id:
			index = i
			break
	if index == -1:
		_held_item_option.add_item("%03d - Item #%d" % [item_id, item_id], item_id)
		index = _held_item_option.item_count - 1
	_held_item_option.select(index)

func _get_selected_item_id() -> int:
	if _held_item_option == null or _held_item_option.item_count == 0:
		return 0
	var selected := _held_item_option.selected
	if selected < 0:
		return 0
	return _held_item_option.get_item_id(selected)

func _load_move_names() -> void:
	_move_names_by_id.clear()
	var dir_path := "res://Resources/Data/Moves"
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var file_base := file_name.get_basename()
			var parts := file_base.split(" - ", false, 1)
			if parts.size() > 0:
				var id_str := parts[0].strip_edges()
				if id_str.is_valid_int():
					var mid := int(id_str)
					var display := file_base
					if parts.size() == 1:
						display = "%03d - Move #%d" % [mid, mid]
					_move_names_by_id[mid] = display
		file_name = dir.get_next()
	dir.list_dir_end()

func _refresh_moves_list() -> void:
	if _moves_list == null:
		return
	_moves_list.clear()
	if _move_ids.is_empty():
		_moves_list.add_item("(Sin movimientos personalizados)")
		_moves_list.set_item_disabled(0, true)
		return

	for i in range(_move_ids.size()):
		var move_id := int(_move_ids[i])
		var display := _move_names_by_id.get(move_id, "%03d - Move #%d" % [move_id, move_id])
		_moves_list.add_item("%d) %s" % [i + 1, display])

func _on_add_move_pressed() -> void:
	if _move_ids.size() >= 4:
		_show_warning("Máximo 4 movimientos personalizados.")
		return
	var picker = ResourcePickerAPI.open_move_picker(null, _on_move_picked_for_add, Callable())
	if picker == null:
		_show_warning("No se pudo abrir el selector de movimientos.")

func _on_edit_move_pressed() -> void:
	if _move_ids.is_empty():
		return
	var selected := _moves_list.get_selected_items()
	if selected.is_empty():
		_show_warning("Selecciona un movimiento para editar.")
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _move_ids.size():
		return
	var current_id := int(_move_ids[idx])
	var picker = ResourcePickerAPI.open_move_picker(current_id, func(result: ResourcePickerResult):
		if result == null:
			return
		var move_id := int(result.resource_id)
		if move_id <= 0:
			return
		_move_ids[idx] = move_id as MovesEnum.Values
		_refresh_moves_list()
		_moves_list.select(idx)
	, Callable())
	if picker == null:
		_show_warning("No se pudo abrir el selector de movimientos.")

func _on_remove_move_pressed() -> void:
	if _move_ids.is_empty():
		return
	var selected := _moves_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= _move_ids.size():
		return
	_move_ids.remove_at(idx)
	_refresh_moves_list()

func _on_move_picked_for_add(result: ResourcePickerResult) -> void:
	if result == null:
		return
	var move_id := int(result.resource_id)
	if move_id <= 0:
		return
	_move_ids.append(move_id as MovesEnum.Values)
	_refresh_moves_list()
	_moves_list.select(_move_ids.size() - 1)

func _show_warning(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Aviso"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
