@tool
extends Window

signal command_edited(command)
signal cancelled

var command = null
var definition_editor_script: GDScript = null

var original_show_message: bool = true
var original_pokemon_def: PokemonDefinition = null
var original_message_template: String = "¡Obtuviste a [pokemon]!"

var pokemon_summary_label: Label = null
var edit_pokemon_button: Button = null
var show_message_check: CheckBox = null
var message_template_text_edit: TextEdit = null

func _ready() -> void:
	title = "Editar GivePokemonCommand"
	size = Vector2(640, 430)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)
	definition_editor_script = load("res://addons/event_tools/pokemon_definition_editor_window.gd") as GDScript
	_setup_ui()

func _setup_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Editar GivePokemonCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var poke_row := HBoxContainer.new()
	var poke_label := Label.new()
	poke_label.text = "Pokémon:"
	poke_label.custom_minimum_size.x = 120
	poke_row.add_child(poke_label)

	pokemon_summary_label = Label.new()
	pokemon_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poke_row.add_child(pokemon_summary_label)

	edit_pokemon_button = Button.new()
	edit_pokemon_button.text = "Editar..."
	edit_pokemon_button.pressed.connect(_on_edit_pokemon_pressed)
	poke_row.add_child(edit_pokemon_button)

	vbox.add_child(poke_row)

	show_message_check = CheckBox.new()
	show_message_check.text = "Mostrar mensajes de recibido / envío al PC"
	show_message_check.button_pressed = true
	vbox.add_child(show_message_check)

	var msg_label := Label.new()
	msg_label.text = "Mensaje personalizable (primero):"
	vbox.add_child(msg_label)

	message_template_text_edit = TextEdit.new()
	message_template_text_edit.custom_minimum_size.y = 90
	message_template_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	message_template_text_edit.text = "¡Obtuviste a [pokemon]!"
	vbox.add_child(message_template_text_edit)

	var help_label := Label.new()
	help_label.text = "Placeholders: [pokemon], [player], [level]"
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(help_label)

	vbox.add_spacer(false)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)

	var accept_button := Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons.add_child(accept_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_button)

	vbox.add_child(buttons)

func load_command(cmd) -> void:
	if cmd == null:
		push_error("GivePokemonCommandEditor: comando inválido")
		return
	command = cmd
	original_show_message = bool(cmd.show_message)
	original_pokemon_def = cmd.pokemon_def.duplicate(true) if cmd.pokemon_def != null else null
	original_message_template = str(cmd.message_template)
	if command.pokemon_def == null:
		command.pokemon_def = _create_default_definition()
	if show_message_check:
		show_message_check.button_pressed = bool(command.show_message)
	if message_template_text_edit:
		message_template_text_edit.text = str(command.message_template)
	_update_summary()

func _create_default_definition() -> PokemonDefinition:
	var def := PokemonDefinition.new()
	def.pokemon_id = PokemonsEnum.Values.BULBASAUR
	def.level = 5
	return def

func _update_summary() -> void:
	if pokemon_summary_label == null:
		return
	if command == null or command.pokemon_def == null:
		pokemon_summary_label.text = "(Sin Pokémon definido)"
		return
	var def: PokemonDefinition = command.pokemon_def
	var species_name := PokemonsEnum.get_display_name(int(def.pokemon_id))
	if species_name.strip_edges().is_empty():
		species_name = "Pokémon #%d" % int(def.pokemon_id)
	var nickname := def.nickname.strip_edges()
	if nickname.is_empty():
		pokemon_summary_label.text = "%s - Nv.%d" % [species_name, int(def.level)]
	else:
		pokemon_summary_label.text = "%s (%s) - Nv.%d" % [nickname, species_name, int(def.level)]

func _on_edit_pokemon_pressed() -> void:
	if definition_editor_script == null:
		push_warning("GivePokemonCommandEditor: no se pudo cargar PokemonDefinitionEditorWindow.")
		return
	if command == null:
		return
	if command.pokemon_def == null:
		command.pokemon_def = _create_default_definition()
	var editor = definition_editor_script.new()
	if editor == null:
		push_warning("GivePokemonCommandEditor: no se pudo instanciar PokemonDefinitionEditorWindow.")
		return
	add_child(editor)
	editor.saved.connect(func(updated_definition: PokemonDefinition):
		command.pokemon_def = updated_definition
		_update_summary()
	)
	editor.open_for_definition(command.pokemon_def, "Editar Pokémon a entregar")

func _apply_values_to_command() -> void:
	if command == null:
		return
	command.show_message = show_message_check.button_pressed if show_message_check else true
	command.message_template = message_template_text_edit.text if message_template_text_edit else "¡Obtuviste a [pokemon]!"
	if command.pokemon_def == null:
		command.pokemon_def = _create_default_definition()

func _restore_original_values() -> void:
	if command == null:
		return
	command.show_message = original_show_message
	command.pokemon_def = original_pokemon_def.duplicate(true) if original_pokemon_def != null else null
	command.message_template = original_message_template

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	queue_free()

func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	_on_cancel_pressed()
