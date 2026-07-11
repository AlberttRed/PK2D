extends RichTextLabel

class_name LabelHGSS

signal line_displayed
signal lines_displayed
signal text_completed

const LINE_CHARS = 36
const VISIBLE_CHARS_LIMIT = 72
const MENU_ROW_HEIGHT := 34.0
const MENU_TEXT_RISE := -6
const MENU_FONT_SIZE := 26

var lastLine: int = 0
var nextLineStop: int = 2
var actualLine: int = 0

var isLastLine: bool:
	get:
		return actualLine == get_line_count()

var messageHasFinished: bool:
	get:
		return visible_characters == -1 or visible_characters == get_total_character_count()

@export_enum("Left", "Center", "Right") var align: int
#@export var font_color : Color
#@export var outline_color : Color
#@export var text_font :Font #DynamicFont
#@export var block_outline : bool = true
var _refresh_task_running: bool = false


func _outline_layers() -> Array[RichTextLabel]:
	return [$Outline, $Outline2]


## Replica en Outline/Outline2 las métricas efectivas del RTL principal (tras copiar tema o cambiar texto).
func _sync_outline_layout_from_parent() -> void:
	if not is_inside_tree():
		return
	var line_sep := get_theme_constant("line_separation")
	var para_sep := get_theme_constant("paragraph_separation")
	var font_sz := get_theme_font_size("normal_font_size")
	var spacing_top_val = get("spacing_top")
	for o in _outline_layers():
		o.add_theme_constant_override("line_separation", line_sep)
		o.add_theme_constant_override("paragraph_separation", para_sep)
		o.add_theme_font_size_override("normal_font_size", font_sz)
		o.set("spacing_top", spacing_top_val)


## Iguala Outline/Outline2 al rectángulo del RTL principal (sin PRESET_FULL_RECT: con `fit_content`
## el tamaño efectivo del texto no coincide siempre con el rect de anclas stretch).
func _sync_outline_geometry_from_parent() -> void:
	if not is_inside_tree():
		return
	var sz := size
	for o in _outline_layers():
		o.set_anchors_preset(Control.PRESET_TOP_LEFT)
		o.offset_left = 0.0
		o.offset_top = 0.0
		o.offset_right = sz.x
		o.offset_bottom = sz.y
		o.custom_minimum_size = sz


func _request_outline_visual_refresh() -> void:
	if not is_inside_tree():
		return
	if _refresh_task_running:
		return
	_refresh_task_running = true
	call_deferred("_deferred_outline_visual_refresh")


func _deferred_outline_visual_refresh() -> void:
	if not is_inside_tree():
		_refresh_task_running = false
		return
	# Esperar un frame garantiza layout final cuando el control acaba de hacerse visible.
	await get_tree().process_frame
	if not is_inside_tree():
		_refresh_task_running = false
		return
	_sync_outline_layout_from_parent()
	_sync_outline_geometry_from_parent()
	for o in _outline_layers():
		o.queue_redraw()
	queue_redraw()
	_refresh_task_running = false


# Called when the node enters the scene tree for the first time.
func _ready():
	setText(text)

	var text_font = get("default_font")
	var text_normal_font = get("theme_override_fonts/normal_font")
	var font_size = get("default_font_size")
	var font_color = get("theme_override_colors/default_color")
	var outline_color = get("theme_override_colors/font_shadow_color")

	for o in _outline_layers():
		o.set("default_font", text_font)
		o.set("default_font_size", font_size)
		o.set("theme_override_colors/default_color", font_color)
		o.set("theme_override_colors/font_shadow_color", outline_color)
	for o in _outline_layers():
		o.theme = theme
	for o in _outline_layers():
		o.set("theme_override_fonts/normal_font", text_normal_font)

	_sync_outline_layout_from_parent()
	_sync_outline_geometry_from_parent()

	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for o in _outline_layers():
		o.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_request_outline_visual_refresh()


## RT con BBCode trata `\n` como párrafo nuevo. `[br]` mantiene una sola línea visual; `\n\n` sigue siendo hueco entre bloques.
func _bbcode_normalize_newlines(s: String) -> String:
	if not bbcode_enabled:
		return s
	var t: String = s.replace("\r\n", "\n").replace("\r", "\n")
	const PARA_MARKER = "<<<NL2>>>"
	t = t.replace("\n\n", PARA_MARKER)
	t = t.replace("\n", "[br]")
	t = t.replace(PARA_MARKER, "\n\n")
	return t


## Normaliza `\n` → `[br]` y copia el mismo BBCode al RTL principal y a Outline/Outline2.
## Solo lo usa `setText()`: algunas rutas del motor no disparan `_set()` al escribir `text` directamente.
func _apply_full_richtext(raw: String) -> void:
	var normalized: String = _bbcode_normalize_newlines(raw)
	text = normalized
	for o in _outline_layers():
		o.text = normalized
	_sync_outline_layout_from_parent()
	_request_outline_visual_refresh()


## Fila compacta para menús lista (PauseMenu, ChoiceBox). Godot 4.7: line_separation>0 infla filas ~56px.
static func create_menu_row(text: String) -> LabelHGSS:
	var label := LabelHGSS.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_FILL
	label.custom_minimum_size = Vector2(0, MENU_ROW_HEIGHT)

	var custom_theme := Theme.new()
	var font: Font = load("res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf")
	var font_variation := FontVariation.new()
	font_variation.base_font = font
	font_variation.spacing_top = MENU_TEXT_RISE
	custom_theme.default_font = font_variation
	custom_theme.default_font_size = MENU_FONT_SIZE

	label.theme = custom_theme
	label.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	label.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	label.add_theme_constant_override("line_separation", 0)
	label.add_theme_constant_override("paragraph_separation", 0)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.clip_contents = false

	var outline1 := RichTextLabel.new()
	outline1.name = "Outline"
	outline1.bbcode_enabled = true
	outline1.fit_content = false
	outline1.scroll_active = false
	outline1.theme = custom_theme
	outline1.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	outline1.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	outline1.add_theme_constant_override("line_separation", 0)
	outline1.add_theme_constant_override("paragraph_separation", 0)
	outline1.add_theme_constant_override("shadow_offset_x", 0)
	outline1.add_theme_constant_override("shadow_offset_y", 2)
	outline1.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	outline1.clip_contents = false

	var outline2 := RichTextLabel.new()
	outline2.name = "Outline2"
	outline2.bbcode_enabled = true
	outline2.fit_content = false
	outline2.scroll_active = false
	outline2.theme = custom_theme
	outline2.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	outline2.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	outline2.add_theme_constant_override("line_separation", 0)
	outline2.add_theme_constant_override("paragraph_separation", 0)
	outline2.add_theme_constant_override("shadow_offset_x", 2)
	outline2.add_theme_constant_override("shadow_offset_y", 2)
	outline2.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	outline2.clip_contents = false

	label.add_child(outline1)
	label.add_child(outline2)
	label.setText(text)
	return label


func setText(_text):
	var prefix := "[left]"
	match align:
		1:
			prefix = "[center]"
		2:
			prefix = "[right]"
	_apply_full_richtext(prefix + str(_text))


func updateNextLine():
	nextLineStop += 1


func reset():
	lastLine = 0
	nextLineStop = 0
	# MessageBox controla visible_characters; no tocar visible_ratio aquí (desalinea las 3 capas).


func _set(_name, value) -> bool:
	match _name:
		"text":
			var normalized: String = _bbcode_normalize_newlines(str(value))
			text = normalized
			for o in _outline_layers():
				o.text = normalized
			_sync_outline_layout_from_parent()
			_request_outline_visual_refresh()
			return true
		"visible_characters":
			var next_line = 0
			visible_characters = value
			for o in _outline_layers():
				o.visible_characters = value
			actualLine = get_character_line(visible_characters) + 1
			next_line = get_character_line(visible_characters + 1) + 1
			if next_line == 0:
				next_line = actualLine
			if messageHasFinished or next_line != actualLine:
				line_displayed.emit()
				lastLine = actualLine
			return true
		"theme_override_colors/default_color":
			add_theme_color_override("default_color", value)
			for o in _outline_layers():
				o.add_theme_color_override("default_color", value)
			return true
		"theme_override_colors/font_shadow_color":
			add_theme_color_override("font_shadow_color", value)
			for o in _outline_layers():
				o.add_theme_color_override("font_shadow_color", value)
			return true
		_:
			return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_sync_outline_layout_from_parent()
		_request_outline_visual_refresh()
	elif what == NOTIFICATION_RESIZED:
		_request_outline_visual_refresh()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_request_outline_visual_refresh()
