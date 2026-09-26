extends RefCounted
class_name HGSSMenuTypography

## Métricas de filas de menú (PauseMenu, ChoiceBox, BAG, etc.).
const ROW_HEIGHT := 34.0
const TEXT_RISE := -6
const FONT_SIZE := 26

const FONT_PATH := "res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf"

const COLOR_TEXT := Color(0.317647, 0.317647, 0.34902, 1)
const COLOR_SHADOW := Color(0.65098, 0.65098, 0.682353, 1)


static func create_menu_settings(
	font_color: Color = COLOR_TEXT,
	shadow_color: Color = COLOR_SHADOW,
	spacing_top: int = TEXT_RISE,
	font_size: int = FONT_SIZE,
	font_path: String = FONT_PATH
) -> LabelSettings:
	var font_variation := FontVariation.new()
	font_variation.base_font = load(font_path) as Font
	font_variation.spacing_top = spacing_top

	var settings := LabelSettings.new()
	settings.font = font_variation
	settings.font_size = font_size
	settings.font_color = font_color
	settings.stacked_shadow_count = 3
	settings.set("stacked_shadow_0/offset", Vector2(2, 0))
	settings.set("stacked_shadow_0/color", shadow_color)
	settings.set("stacked_shadow_1/offset", Vector2(0, 2))
	settings.set("stacked_shadow_1/color", shadow_color)
	settings.set("stacked_shadow_2/offset", Vector2(2, 2))
	settings.set("stacked_shadow_2/color", shadow_color)
	return settings


static func create_menu_label(text: String) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.clip_text = false
	label.text = text
	label.label_settings = create_menu_settings()
	return label
