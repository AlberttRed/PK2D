@tool
extends Window

## Ventana de edición para FadeCommand

signal command_edited(command: FadeCommand)
signal cancelled

var command: FadeCommand = null

var original_mode: int = 0
var original_effect: int = 0
var original_mask: int = 0
var original_duration: float = 1.0
var original_wait_for_completion: bool = true

var mode_option: OptionButton = null
var effect_option: OptionButton = null
var mask_option: OptionButton = null
var mask_container: HBoxContainer = null
var duration_spinbox: SpinBox = null
var wait_for_completion_check: CheckBox = null


func _ready() -> void:
	title = "Editar FadeCommand"
	size = Vector2(480, 320)
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
	title_label.text = "Editar FadeCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Mode
	var mode_container = HBoxContainer.new()
	var mode_label = Label.new()
	mode_label.text = "Modo:"
	mode_label.custom_minimum_size.x = 160
	mode_container.add_child(mode_label)

	mode_option = OptionButton.new()
	mode_option.add_item("IN (a negro)", FadeCommand.FadeMode.IN)
	mode_option.add_item("OUT (desde negro)", FadeCommand.FadeMode.OUT)
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_container.add_child(mode_option)
	vbox.add_child(mode_container)

	# Effect
	var effect_container = HBoxContainer.new()
	var effect_label = Label.new()
	effect_label.text = "Efecto:"
	effect_label.custom_minimum_size.x = 160
	effect_container.add_child(effect_label)

	effect_option = OptionButton.new()
	effect_option.add_item("Solid (fade)", FadeCommand.FadeEffect.SOLID)
	effect_option.add_item("Mask (máscara)", FadeCommand.FadeEffect.MASK)
	effect_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_option.item_selected.connect(_on_effect_selected)
	effect_container.add_child(effect_option)
	vbox.add_child(effect_container)

	# Mask
	mask_container = HBoxContainer.new()
	var mask_label = Label.new()
	mask_label.text = "Máscara:"
	mask_label.custom_minimum_size.x = 160
	mask_container.add_child(mask_label)

	mask_option = OptionButton.new()
	for mask_type in ScreenTransitionEnum.all_types():
		mask_option.add_item(ScreenTransitionEnum.get_display_name(mask_type), int(mask_type))
	mask_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask_container.add_child(mask_option)
	vbox.add_child(mask_container)

	# Duration
	var duration_container = HBoxContainer.new()
	var duration_label = Label.new()
	duration_label.text = "Duración (segundos):"
	duration_label.custom_minimum_size.x = 160
	duration_container.add_child(duration_label)

	duration_spinbox = SpinBox.new()
	duration_spinbox.min_value = 0.0
	duration_spinbox.max_value = 999.0
	duration_spinbox.step = 0.1
	duration_spinbox.value = 1.0
	duration_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_container.add_child(duration_spinbox)
	vbox.add_child(duration_container)

	wait_for_completion_check = CheckBox.new()
	wait_for_completion_check.text = "Esperar a que termine el fade"
	wait_for_completion_check.button_pressed = true
	vbox.add_child(wait_for_completion_check)

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
	_update_mask_visibility()


func load_command(cmd: FadeCommand) -> void:
	if not cmd:
		push_error("FadeCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd
	original_mode = cmd.mode
	original_effect = cmd.effect
	original_mask = int(cmd.mask)
	original_duration = cmd.duration
	original_wait_for_completion = cmd.wait_for_completion

	if mode_option:
		mode_option.select(_find_option_index(mode_option, int(cmd.mode)))
	if effect_option:
		effect_option.select(_find_option_index(effect_option, int(cmd.effect)))
	if mask_option:
		mask_option.select(_find_option_index(mask_option, int(cmd.mask)))
	if duration_spinbox:
		duration_spinbox.value = cmd.duration
	if wait_for_completion_check:
		wait_for_completion_check.button_pressed = cmd.wait_for_completion
	_update_mask_visibility()


func _find_option_index(option: OptionButton, id: int) -> int:
	for i in option.item_count:
		if option.get_item_id(i) == id:
			return i
	return 0


func _on_effect_selected(_index: int) -> void:
	_update_mask_visibility()


func _update_mask_visibility() -> void:
	if not mask_container or not effect_option:
		return
	var effect_id := effect_option.get_selected_id()
	mask_container.visible = effect_id == FadeCommand.FadeEffect.MASK


func _apply_values_to_command() -> void:
	if not command:
		return
	command.mode = mode_option.get_selected_id() if mode_option else FadeCommand.FadeMode.OUT
	command.effect = effect_option.get_selected_id() if effect_option else FadeCommand.FadeEffect.SOLID
	command.mask = mask_option.get_selected_id() as ScreenTransitionEnum.Type if mask_option else ScreenTransitionEnum.Type.WIPE_VERTICAL
	command.duration = duration_spinbox.value if duration_spinbox else 1.0
	command.wait_for_completion = wait_for_completion_check.button_pressed if wait_for_completion_check else true


func _restore_original_values() -> void:
	if not command:
		return
	command.mode = original_mode
	command.effect = original_effect
	command.mask = original_mask as ScreenTransitionEnum.Type
	command.duration = original_duration
	command.wait_for_completion = original_wait_for_completion


func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()


func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()


func _on_close_requested() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()
