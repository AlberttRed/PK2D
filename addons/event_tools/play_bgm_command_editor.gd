@tool
extends Window

## Ventana de edición para PlayBGMCommand

signal command_edited(command: PlayBGMCommand)
signal cancelled

var command: PlayBGMCommand = null

var original_bgm: AudioStream = null
var original_transition_mode: int = 0
var original_fade_duration: float = 0.5
var original_loop: bool = true
var original_persist_across_maps: bool = false

var bgm_path_label: Label = null
var transition_option: OptionButton = null
var fade_spinbox: SpinBox = null
var loop_check: CheckBox = null
var persist_check: CheckBox = null
var _pending_bgm: AudioStream = null


func _ready() -> void:
	title = "Editar PlayBGMCommand"
	size = Vector2(520, 340)
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
	title_label.text = "Editar PlayBGMCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var bgm_container = HBoxContainer.new()
	var bgm_label = Label.new()
	bgm_label.text = "BGM:"
	bgm_label.custom_minimum_size.x = 160
	bgm_container.add_child(bgm_label)

	bgm_path_label = Label.new()
	bgm_path_label.text = "(sin BGM)"
	bgm_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_path_label.clip_text = true
	bgm_container.add_child(bgm_path_label)

	var browse_button = Button.new()
	browse_button.text = "Examinar…"
	browse_button.pressed.connect(_on_browse_pressed)
	bgm_container.add_child(browse_button)

	var clear_button = Button.new()
	clear_button.text = "Quitar"
	clear_button.pressed.connect(_on_clear_bgm_pressed)
	bgm_container.add_child(clear_button)
	vbox.add_child(bgm_container)

	var transition_container = HBoxContainer.new()
	var transition_label = Label.new()
	transition_label.text = "Transición:"
	transition_label.custom_minimum_size.x = 160
	transition_container.add_child(transition_label)

	transition_option = OptionButton.new()
	transition_option.add_item("Fade in / corte", PlayBGMCommand.TransitionMode.FADE_IN)
	transition_option.add_item("Crossfade", PlayBGMCommand.TransitionMode.CROSSFADE)
	transition_option.add_item("Fade out → play (Gen 3)", PlayBGMCommand.TransitionMode.FADE_OUT_THEN_PLAY)
	transition_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transition_container.add_child(transition_option)
	vbox.add_child(transition_container)

	var fade_container = HBoxContainer.new()
	var fade_label = Label.new()
	fade_label.text = "Duración fade (s):"
	fade_label.custom_minimum_size.x = 160
	fade_container.add_child(fade_label)

	fade_spinbox = SpinBox.new()
	fade_spinbox.min_value = 0.0
	fade_spinbox.max_value = 30.0
	fade_spinbox.step = 0.1
	fade_spinbox.value = 0.5
	fade_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fade_container.add_child(fade_spinbox)
	vbox.add_child(fade_container)

	loop_check = CheckBox.new()
	loop_check.text = "Loop"
	loop_check.button_pressed = true
	vbox.add_child(loop_check)

	persist_check = CheckBox.new()
	persist_check.text = "Persistir entre mapas (hasta StopBGM)"
	persist_check.button_pressed = false
	vbox.add_child(persist_check)

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


func load_command(cmd: PlayBGMCommand) -> void:
	if not cmd:
		push_error("PlayBGMCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd
	original_bgm = cmd.bgm
	original_transition_mode = int(cmd.transition_mode)
	original_fade_duration = cmd.fade_duration
	original_loop = cmd.loop
	original_persist_across_maps = cmd.persist_across_maps
	_pending_bgm = cmd.bgm

	_update_bgm_label()
	if transition_option:
		transition_option.select(_find_option_index(transition_option, int(cmd.transition_mode)))
	if fade_spinbox:
		fade_spinbox.value = cmd.fade_duration
	if loop_check:
		loop_check.button_pressed = cmd.loop
	if persist_check:
		persist_check.button_pressed = cmd.persist_across_maps


func _find_option_index(option: OptionButton, id: int) -> int:
	for i in option.item_count:
		if option.get_item_id(i) == id:
			return i
	return 0


func _update_bgm_label() -> void:
	if not bgm_path_label:
		return
	if _pending_bgm == null:
		bgm_path_label.text = "(sin BGM)"
		return
	var path := _pending_bgm.resource_path
	bgm_path_label.text = path.get_file() if not path.is_empty() else "(stream embebido)"


func _on_browse_pressed() -> void:
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.title = "Seleccionar BGM"
	file_dialog.current_dir = "res://Audio/BGM"
	file_dialog.add_filter("*.ogg,*.wav,*.mp3", "Audio")
	file_dialog.file_selected.connect(func(path: String):
		var stream = load(path)
		if stream is AudioStream:
			_pending_bgm = stream as AudioStream
			_update_bgm_label()
		else:
			push_warning("PlayBGMCommandEditor: El archivo no es un AudioStream: %s" % path)
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)


func _on_clear_bgm_pressed() -> void:
	_pending_bgm = null
	_update_bgm_label()


func _apply_values_to_command() -> void:
	if not command:
		return
	command.bgm = _pending_bgm
	command.transition_mode = transition_option.get_selected_id() as PlayBGMCommand.TransitionMode if transition_option else PlayBGMCommand.TransitionMode.FADE_IN
	command.fade_duration = fade_spinbox.value if fade_spinbox else 0.5
	command.loop = loop_check.button_pressed if loop_check else true
	command.persist_across_maps = persist_check.button_pressed if persist_check else false


func _restore_original_values() -> void:
	if not command:
		return
	command.bgm = original_bgm
	command.transition_mode = original_transition_mode as PlayBGMCommand.TransitionMode
	command.fade_duration = original_fade_duration
	command.loop = original_loop
	command.persist_across_maps = original_persist_across_maps


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
