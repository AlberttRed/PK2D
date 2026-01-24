@tool
extends Window

## Ventana de edición para StartBattleEventCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: StartBattleEventCommand)
signal cancelled

var command: StartBattleEventCommand = null

# Valores originales para poder cancelar
var original_battle_type: int = 0
var original_battle_mode: int = 1
var original_transition_type: int = 0
var original_defeated_flag: String = ""
var original_trainer_data: TrainerData = null
var original_wild_pokemon: Array[Pokemon] = []

# Referencias a los controles
var battle_type_option: OptionButton = null
var trainer_data_label: Label = null
var trainer_data_button: Button = null
var wild_pokemon_list: ItemList = null
var battle_mode_option: OptionButton = null
var transition_type_option: OptionButton = null
var defeated_flag_line_edit: LineEdit = null

func _ready() -> void:
	title = "Editar StartBattleEventCommand"
	size = Vector2(600, 530)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	_setup_ui()

func _setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Título
	var title_label = Label.new()
	title_label.text = "Editar StartBattleEventCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Battle Type
	var battle_type_container = HBoxContainer.new()
	var battle_type_label = Label.new()
	battle_type_label.text = "Tipo de combate:"
	battle_type_label.custom_minimum_size.x = 150
	battle_type_container.add_child(battle_type_label)

	battle_type_option = OptionButton.new()
	battle_type_option.add_item("WILD")
	battle_type_option.add_item("TRAINER")
	battle_type_option.add_item("CUSTOM")
	battle_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_type_option.item_selected.connect(_on_battle_type_changed)
	battle_type_container.add_child(battle_type_option)
	vbox.add_child(battle_type_container)

	# Trainer Data (solo visible para TRAINER)
	var trainer_data_container = VBoxContainer.new()
	trainer_data_container.name = "TrainerDataContainer"
	trainer_data_container.custom_minimum_size = Vector2(0, 130)  # Misma altura que WildPokemonContainer

	var trainer_data_title = Label.new()
	trainer_data_title.text = "Trainer Data:"
	trainer_data_container.add_child(trainer_data_title)

	var trainer_data_row = HBoxContainer.new()
	trainer_data_label = Label.new()
	trainer_data_label.text = "(Ninguno)"
	trainer_data_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trainer_data_row.add_child(trainer_data_label)

	trainer_data_button = Button.new()
	trainer_data_button.text = "Seleccionar..."
	trainer_data_button.pressed.connect(_on_select_trainer_data)
	trainer_data_row.add_child(trainer_data_button)

	var clear_trainer_button = Button.new()
	clear_trainer_button.text = "Limpiar"
	clear_trainer_button.pressed.connect(_on_clear_trainer_data)
	trainer_data_row.add_child(clear_trainer_button)

	trainer_data_container.add_child(trainer_data_row)
	vbox.add_child(trainer_data_container)

	# Wild Pokemon (solo visible para WILD)
	var wild_pokemon_container = VBoxContainer.new()
	wild_pokemon_container.name = "WildPokemonContainer"
	wild_pokemon_container.custom_minimum_size = Vector2(0, 130)  # Misma altura que TrainerDataContainer

	var wild_pokemon_title = Label.new()
	wild_pokemon_title.text = "Pokémon Salvajes:"
	wild_pokemon_container.add_child(wild_pokemon_title)

	# Contenedor horizontal para la lista y los botones
	var wild_pokemon_row = HBoxContainer.new()
	wild_pokemon_row.add_theme_constant_override("separation", 10)

	# Contenedor para el ItemList que limita su tamaño
	# La altura debe coincidir con la altura de los 3 botones (aproximadamente 3 * 30px + separación)
	var list_container = Control.new()
	list_container.custom_minimum_size = Vector2(280, 100)  # Ancho mitad de ventana, altura igual a los 3 botones
	list_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # No expandir
	list_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # No expandir verticalmente

	wild_pokemon_list = ItemList.new()
	wild_pokemon_list.set_anchors_preset(Control.PRESET_FULL_RECT)  # Llenar el contenedor
	wild_pokemon_list.max_columns = 1  # Lista vertical
	wild_pokemon_list.same_column_width = true
	list_container.add_child(wild_pokemon_list)
	wild_pokemon_row.add_child(list_container)

	# Contenedor vertical para los botones (alineados a la izquierda)
	var wild_pokemon_buttons = VBoxContainer.new()
	wild_pokemon_buttons.add_theme_constant_override("separation", 5)
	wild_pokemon_buttons.alignment = BoxContainer.ALIGNMENT_BEGIN  # Alinear a la izquierda
	wild_pokemon_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # No expandir

	var add_pokemon_button = Button.new()
	add_pokemon_button.text = "Añadir"
	add_pokemon_button.pressed.connect(func(): print("Añadir pokémon (placeholder)"))
	wild_pokemon_buttons.add_child(add_pokemon_button)

	var edit_pokemon_button = Button.new()
	edit_pokemon_button.text = "Editar"
	edit_pokemon_button.pressed.connect(func(): print("Editar pokémon (placeholder)"))
	wild_pokemon_buttons.add_child(edit_pokemon_button)

	var remove_pokemon_button = Button.new()
	remove_pokemon_button.text = "Quitar"
	remove_pokemon_button.pressed.connect(_on_remove_pokemon_pressed)
	wild_pokemon_buttons.add_child(remove_pokemon_button)

	wild_pokemon_row.add_child(wild_pokemon_buttons)
	wild_pokemon_container.add_child(wild_pokemon_row)

	vbox.add_child(wild_pokemon_container)

	# Battle Mode
	var battle_mode_container = HBoxContainer.new()
	var battle_mode_label = Label.new()
	battle_mode_label.text = "Modo de batalla:"
	battle_mode_label.custom_minimum_size.x = 150
	battle_mode_container.add_child(battle_mode_label)

	battle_mode_option = OptionButton.new()
	battle_mode_option.add_item("NONE")
	battle_mode_option.add_item("SINGLE")
	battle_mode_option.add_item("DOUBLE")
	battle_mode_option.add_item("TRIPLE")
	battle_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_mode_container.add_child(battle_mode_option)
	vbox.add_child(battle_mode_container)

	# Separador para Visual
	vbox.add_child(HSeparator.new())

	var visual_label = Label.new()
	visual_label.text = "Visual:"
	visual_label.add_theme_constant_override("margin_top", 10)
	vbox.add_child(visual_label)

	# Transition Type
	var transition_type_container = HBoxContainer.new()
	var transition_type_label = Label.new()
	transition_type_label.text = "Tipo de transición:"
	transition_type_label.custom_minimum_size.x = 150
	transition_type_container.add_child(transition_type_label)

	transition_type_option = OptionButton.new()
	transition_type_option.add_item("Battle1")
	transition_type_option.add_item("Battle2")
	transition_type_option.add_item("Battle3")
	transition_type_option.add_item("Battle4")
	transition_type_option.add_item("Normal01")
	transition_type_option.add_item("Normal02")
	transition_type_option.add_item("Hexatr")
	transition_type_option.add_item("Hexatrc")
	transition_type_option.add_item("Hexatzr")
	transition_type_option.add_item("WipeVertical")
	transition_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transition_type_container.add_child(transition_type_option)
	vbox.add_child(transition_type_container)

	# Separador para State Tracking
	vbox.add_child(HSeparator.new())

	var state_label = Label.new()
	state_label.text = "State Tracking:"
	state_label.add_theme_constant_override("margin_top", 10)
	vbox.add_child(state_label)

	# Defeated Flag
	var defeated_flag_container = HBoxContainer.new()
	var defeated_flag_label = Label.new()
	defeated_flag_label.text = "Flag de derrota:"
	defeated_flag_label.custom_minimum_size.x = 150
	defeated_flag_container.add_child(defeated_flag_label)

	defeated_flag_line_edit = LineEdit.new()
	defeated_flag_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defeated_flag_line_edit.placeholder_text = "ej: route_1_trainer_defeated"
	defeated_flag_container.add_child(defeated_flag_line_edit)
	vbox.add_child(defeated_flag_container)

	# Botones
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)

	var accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)

## Maneja el cambio de tipo de combate
func _on_battle_type_changed(index: int) -> void:
	# Buscar los contenedores por nombre
	var trainer_container = null
	var wild_container = null

	for child in get_children():
		if child is VBoxContainer:
			for subchild in child.get_children():
				if subchild.name == "TrainerDataContainer":
					trainer_container = subchild
				elif subchild.name == "WildPokemonContainer":
					wild_container = subchild

	if trainer_container and wild_container:
		match index:
			StartBattleEventCommand.BattleType.TRAINER:
				trainer_container.visible = true
				wild_container.visible = false
			StartBattleEventCommand.BattleType.WILD:
				trainer_container.visible = false
				wild_container.visible = true
			_:
				trainer_container.visible = false
				wild_container.visible = false

## Abre el selector de recursos para TrainerData
func _on_select_trainer_data() -> void:
	if not command:
		return

	# Crear un EditorFileDialog para seleccionar archivos TrainerData
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_dir = "res://Resources/Trainers/"
	file_dialog.add_filter("*.tres", "TrainerData")
	file_dialog.title = "Seleccionar TrainerData"

	# Conectar la señal de selección de archivo
	file_dialog.file_selected.connect(func(path: String):
		var trainer_data = load(path) as TrainerData
		if trainer_data:
			command.trainer_data = trainer_data
			_update_trainer_data_display()

			# Si el flag está vacío, generar uno basado en el TrainerData
			if defeated_flag_line_edit and defeated_flag_line_edit.text.strip_edges().is_empty():
				var default_flag = _generate_default_flag()
				defeated_flag_line_edit.text = default_flag
				command.defeated_flag = default_flag

			print("StartBattleEventCommandEditor: TrainerData seleccionado: ", path)
		else:
			push_error("StartBattleEventCommandEditor: El archivo seleccionado no es un TrainerData válido")
		file_dialog.queue_free()
	)

	# Conectar la señal de cancelación
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

	# Añadir el diálogo a la escena y mostrarlo
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

## Limpia el TrainerData
func _on_clear_trainer_data() -> void:
	if command:
		# Modificar directamente (se restaurará si se cancela)
		command.trainer_data = null
		_update_trainer_data_display()

## Actualiza la visualización del TrainerData
func _update_trainer_data_display() -> void:
	if not command or not trainer_data_label:
		return

	if command.trainer_data:
		var resource_path = ""
		if command.trainer_data.resource_path:
			resource_path = command.trainer_data.resource_path
		else:
			resource_path = command.trainer_data.resource_name if command.trainer_data.has("resource_name") else "TrainerData"
		trainer_data_label.text = resource_path.get_file()
	else:
		trainer_data_label.text = "(Ninguno)"

## Actualiza la visualización de Wild Pokemon
## Obtiene el nombre de un Pokémon desde su recurso
func _get_pokemon_name(pokemon: Pokemon) -> String:
	if not pokemon:
		return "(null)"

	# Intentar obtener el nombre desde base si está disponible
	var base_data = pokemon.get("base")
	if base_data and base_data is PokemonData:
		var name_value = base_data.get("Name")
		if name_value and name_value != "":
			return name_value

	# Si base no está disponible, intentar cargar directamente desde el archivo .tres
	var pokemon_id = pokemon.get("pokemon_id")
	if pokemon_id:
		# Intentar cargar el PokemonData directamente desde el archivo
		# El formato es: res://Resources/Data/Pokemon/XXX.tres donde XXX es el ID con ceros a la izquierda
		var pokemon_id_int = pokemon_id as int
		if pokemon_id_int > 0:
			var pokemon_path = "res://Resources/Data/Pokemon/%03d.tres" % pokemon_id_int
			var pokemon_data = load(pokemon_path) as PokemonData
			if pokemon_data:
				var name_value = pokemon_data.get("Name")
				if name_value and name_value != "":
					return name_value

		# Si no se puede cargar desde archivo, intentar DatabaseService
		var db_service = null
		if has_node("/root/DatabaseService"):
			db_service = get_node("/root/DatabaseService")
		elif get_tree() and get_tree().root.has_node("DatabaseService"):
			db_service = get_tree().root.get_node("DatabaseService")

		if db_service:
			# Usar call() para evitar errores con placeholders
			var pokemon_data_result = db_service.call("get_pokemon", pokemon_id)
			if pokemon_data_result and pokemon_data_result is PokemonData:
				var name_value = pokemon_data_result.get("Name")
				if name_value and name_value != "":
					return name_value

		# Si no se puede obtener el nombre, mostrar solo el ID como último recurso
		return "Pokemon #%d" % pokemon_id_int

	return "(sin datos)"

func _update_wild_pokemon_display() -> void:
	if not command or not wild_pokemon_list:
		return

	wild_pokemon_list.clear()

	if command.wild_pokemon.is_empty():
		wild_pokemon_list.add_item("(Ninguno configurado)")
		wild_pokemon_list.set_item_disabled(0, true)
	else:
		for pokemon in command.wild_pokemon:
			var pokemon_name = _get_pokemon_name(pokemon)
			wild_pokemon_list.add_item(pokemon_name)

## Elimina el pokémon seleccionado del array
func _on_remove_pokemon_pressed() -> void:
	if not command or not wild_pokemon_list:
		return

	var selected_indices = wild_pokemon_list.get_selected_items()
	if selected_indices.is_empty():
		print("StartBattleEventCommandEditor: No hay pokémon seleccionado para eliminar")
		return

	# Obtener el índice del pokémon seleccionado
	var selected_index = selected_indices[0]

	# Verificar que el índice sea válido
	if selected_index < 0 or selected_index >= command.wild_pokemon.size():
		print("StartBattleEventCommandEditor: Índice de pokémon inválido")
		return

	# Eliminar el pokémon del array
	command.wild_pokemon.remove_at(selected_index)

	# Actualizar la visualización
	_update_wild_pokemon_display()

	print("StartBattleEventCommandEditor: Pokémon eliminado del array")

## Genera un flag por defecto basado en el formato estándar
func _generate_default_flag() -> String:
	# Si hay un TrainerData, usar su nombre como base
	if command and command.trainer_data:
		var trainer_name = command.trainer_data.resource_path.get_file().get_basename() if command.trainer_data.resource_path else "trainer"
		# Convertir a snake_case y añadir sufijo
		trainer_name = trainer_name.to_lower().replace(" ", "_")
		return "%s_defeated" % trainer_name

	# Si no hay TrainerData, usar un formato genérico
	return "trainer_defeated"

## Carga un comando existente para editar
func load_command(cmd: StartBattleEventCommand) -> void:
	if not cmd:
		push_error("StartBattleEventCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Si el flag está vacío, generar uno por defecto
	if cmd.defeated_flag.is_empty():
		cmd.defeated_flag = _generate_default_flag()

	# Guardar valores originales para poder cancelar
	original_battle_type = cmd.battle_type
	original_battle_mode = cmd.battle_mode
	original_transition_type = cmd.transition_type
	original_defeated_flag = cmd.defeated_flag
	original_trainer_data = cmd.trainer_data
	# Hacer una copia profunda del array de wild_pokemon
	original_wild_pokemon.clear()
	for pokemon in cmd.wild_pokemon:
		if pokemon:
			# Duplicar cada pokémon para tener una copia independiente
			var pokemon_copy = pokemon.duplicate(true) as Pokemon
			original_wild_pokemon.append(pokemon_copy)
		else:
			original_wild_pokemon.append(null)

	# Cargar valores en los controles
	if battle_type_option:
		battle_type_option.selected = cmd.battle_type
		_on_battle_type_changed(cmd.battle_type)

	_update_trainer_data_display()
	_update_wild_pokemon_display()

	if battle_mode_option:
		battle_mode_option.selected = cmd.battle_mode

	if transition_type_option:
		transition_type_option.selected = cmd.transition_type

	if defeated_flag_line_edit:
		defeated_flag_line_edit.text = cmd.defeated_flag

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.battle_type = battle_type_option.selected if battle_type_option else StartBattleEventCommand.BattleType.WILD
	command.battle_mode = battle_mode_option.selected if battle_mode_option else 1
	command.transition_type = transition_type_option.selected if transition_type_option else 0

	# Aplicar flag con validación (no puede estar vacío)
	var flag_text = defeated_flag_line_edit.text.strip_edges() if defeated_flag_line_edit else ""
	if flag_text.is_empty():
		# Si está vacío, generar uno por defecto
		flag_text = _generate_default_flag()
		if defeated_flag_line_edit:
			defeated_flag_line_edit.text = flag_text
	command.defeated_flag = flag_text
	# trainer_data y wild_pokemon se editan desde el inspector

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.battle_type = original_battle_type
	command.battle_mode = original_battle_mode
	command.transition_type = original_transition_type
	command.defeated_flag = original_defeated_flag
	command.trainer_data = original_trainer_data

	# Restaurar el array de wild_pokemon desde la copia
	command.wild_pokemon.clear()
	for pokemon in original_wild_pokemon:
		if pokemon:
			# Duplicar cada pokémon para restaurar una copia independiente
			var pokemon_copy = pokemon.duplicate(true) as Pokemon
			command.wild_pokemon.append(pokemon_copy)
		else:
			command.wild_pokemon.append(null)

	# Actualizar visualización
	_update_trainer_data_display()
	_update_wild_pokemon_display()

func _on_accept_pressed() -> void:
	# Validar que el flag no esté vacío
	var flag_text = defeated_flag_line_edit.text.strip_edges() if defeated_flag_line_edit else ""
	if flag_text.is_empty():
		# Mostrar error y no cerrar la ventana
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = "El flag de derrota no puede estar vacío.\nPor favor, introduce un valor (ej: route_1_trainer_defeated)"
		error_dialog.title = "Error de validación"
		add_child(error_dialog)
		error_dialog.popup_centered()
		error_dialog.confirmed.connect(func(): error_dialog.queue_free())
		return

	_apply_values_to_command()
	command_edited.emit(command)
	hide()

func _on_cancel_pressed() -> void:
	# Restaurar valores originales antes de cancelar
	_restore_original_values()
	cancelled.emit()
	hide()

func _on_close_requested() -> void:
	# Restaurar valores originales antes de cerrar
	_restore_original_values()
	cancelled.emit()
	hide()

