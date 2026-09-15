@tool
extends Window

## Ventana de edición para PlaySoundCommand

signal command_edited(command: PlaySoundCommand)
signal cancelled

var command: PlaySoundCommand = null

var original_sound: AudioStream = null
var original_bus: String = "SFX"
var original_wait_until_finished: bool = false
var original_volume_db: float = 0.0
var original_pause_bgm: bool = false

var sound_path_label: Label = null
var bus_option: OptionButton = null
var wait_check: CheckBox = null
var pause_bgm_check: CheckBox = null
var volume_spinbox: SpinBox = null
var _pending_sound: AudioStream = null


func _ready() -> void:
	title = "Editar PlaySoundCommand"
	size = Vector2(520, 320)
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
	title_label.text = "Editar PlaySoundCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Sound file
	var sound_container = HBoxContainer.new()
	var sound_label = Label.new()
	sound_label.text = "Sonido:"
	sound_label.custom_minimum_size.x = 150
	sound_container.add_child(sound_label)

	sound_path_label = Label.new()
	sound_path_label.text = "(sin sonido)"
	sound_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_path_label.clip_text = true
	sound_container.add_child(sound_path_label)

	var browse_button = Button.new()
	browse_button.text = "Examinar…"
	browse_button.pressed.connect(_on_browse_pressed)
	sound_container.add_child(browse_button)

	var clear_button = Button.new()
	clear_button.text = "Quitar"
	clear_button.pressed.connect(_on_clear_sound_pressed)
	sound_container.add_child(clear_button)
	vbox.add_child(sound_container)

	# Bus
	var bus_container = HBoxContainer.new()
	var bus_label = Label.new()
	bus_label.text = "Bus:"
	bus_label.custom_minimum_size.x = 150
	bus_container.add_child(bus_label)

	bus_option = OptionButton.new()
	bus_option.add_item("SFX")
	bus_option.add_item("UI")
	bus_option.add_item("Master")
	bus_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bus_container.add_child(bus_option)
	vbox.add_child(bus_container)

	# Volume
	var volume_container = HBoxContainer.new()
	var volume_label = Label.new()
	volume_label.text = "Volumen (dB):"
	volume_label.custom_minimum_size.x = 150
	volume_container.add_child(volume_label)

	volume_spinbox = SpinBox.new()
	volume_spinbox.min_value = -40.0
	volume_spinbox.max_value = 24.0
	volume_spinbox.step = 0.5
	volume_spinbox.value = 0.0
	volume_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_container.add_child(volume_spinbox)
	vbox.add_child(volume_container)

	# Wait
	wait_check = CheckBox.new()
	wait_check.text = "Esperar hasta que termine"
	wait_check.button_pressed = false
	vbox.add_child(wait_check)

	pause_bgm_check = CheckBox.new()
	pause_bgm_check.text = "Pausar música de fondo mientras suena"
	pause_bgm_check.button_pressed = false
	vbox.add_child(pause_bgm_check)

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


func load_command(cmd: PlaySoundCommand) -> void:
	if not cmd:
		push_error("PlaySoundCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd
	original_sound = cmd.sound
	original_bus = cmd.bus
	original_wait_until_finished = cmd.wait_until_finished
	original_volume_db = cmd.volume_db
	original_pause_bgm = cmd.pause_bgm
	_pending_sound = cmd.sound

	_update_sound_label()
	_select_bus_option(cmd.bus)
	if volume_spinbox:
		volume_spinbox.value = cmd.volume_db
	if wait_check:
		wait_check.button_pressed = cmd.wait_until_finished
	if pause_bgm_check:
		pause_bgm_check.button_pressed = cmd.pause_bgm


func _select_bus_option(bus_name: String) -> void:
	if not bus_option:
		return
	for i in bus_option.item_count:
		if bus_option.get_item_text(i) == bus_name:
			bus_option.select(i)
			return
	bus_option.select(0)


func _update_sound_label() -> void:
	if not sound_path_label:
		return
	if _pending_sound == null:
		sound_path_label.text = "(sin sonido)"
		return
	var path := _pending_sound.resource_path
	sound_path_label.text = path.get_file() if not path.is_empty() else "(stream embebido)"


func _on_browse_pressed() -> void:
	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.title = "Seleccionar AudioStream"
	file_dialog.current_dir = "res://Audio/SE"
	file_dialog.add_filter("*.ogg,*.wav,*.mp3", "Audio")
	file_dialog.add_filter("*.ogg", "OGG")
	file_dialog.add_filter("*.wav", "WAV")
	file_dialog.add_filter("*.mp3", "MP3")
	file_dialog.file_selected.connect(func(path: String):
		_on_sound_file_selected(path)
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)


func _on_sound_file_selected(path: String) -> void:
	var stream = load(path)
	if stream is AudioStream:
		_pending_sound = stream as AudioStream
		_update_sound_label()
	else:
		push_warning("PlaySoundCommandEditor: El archivo no es un AudioStream: %s" % path)


func _on_clear_sound_pressed() -> void:
	_pending_sound = null
	_update_sound_label()


func _apply_values_to_command() -> void:
	if not command:
		return
	command.sound = _pending_sound
	command.bus = bus_option.get_item_text(bus_option.selected) if bus_option else "SFX"
	command.wait_until_finished = wait_check.button_pressed if wait_check else false
	command.pause_bgm = pause_bgm_check.button_pressed if pause_bgm_check else false
	command.volume_db = volume_spinbox.value if volume_spinbox else 0.0


func _restore_original_values() -> void:
	if not command:
		return
	command.sound = original_sound
	command.bus = original_bus
	command.wait_until_finished = original_wait_until_finished
	command.pause_bgm = original_pause_bgm
	command.volume_db = original_volume_db


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
