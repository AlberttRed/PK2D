extends RichTextLabel

class_name LabelHGSS

signal line_displayed
signal lines_displayed
signal text_completed

const LINE_CHARS = 36
const VISIBLE_CHARS_LIMIT = 72

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


func _sync_outline_geometry_from_parent() -> void:
	if not is_inside_tree():
		return
	for o in _outline_layers():
		o.position = Vector2.ZERO
		o.size = size
		o.custom_minimum_size = size


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


func _draw() -> void:
	_sync_outline_geometry_from_parent()


## Normaliza `\n` → `[br]` y copia el mismo BBCode al RTL principal y a Outline/Outline2.
## Solo lo usa `setText()`: algunas rutas del motor no disparan `_set()` al escribir `text` directamente.
func _apply_full_richtext(raw: String) -> void:
	var normalized: String = _bbcode_normalize_newlines(raw)
	text = normalized
	for o in _outline_layers():
		o.text = normalized
	_sync_outline_layout_from_parent()
	queue_redraw()


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


func _set(_name, value):
	match _name:
		"text":
			var normalized: String = _bbcode_normalize_newlines(str(value))
			text = normalized
			for o in _outline_layers():
				o.text = normalized
			_sync_outline_layout_from_parent()
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
		"theme_override_colors/default_color":
			for o in _outline_layers():
				o.set("theme_override_colors/default_color", value)
		"theme_override_colors/font_shadow_color":
			for o in _outline_layers():
				o.set("theme_override_colors/font_shadow_color", value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_sync_outline_layout_from_parent()
		_request_outline_visual_refresh()
	elif what == NOTIFICATION_RESIZED:
		_request_outline_visual_refresh()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_request_outline_visual_refresh()
