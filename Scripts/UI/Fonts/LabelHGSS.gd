extends RichTextLabel

class_name LabelHGSS

signal line_displayed
signal lines_displayed
signal text_completed

const LINE_CHARS = 36
const VISIBLE_CHARS_LIMIT = 72

var lastLine: int = 0
var nextLineStop:int = 2
var actualLine:int = 0

var isLastLine:bool:
	get:
		return actualLine == get_line_count()
		
var messageHasFinished:bool:
	get:
		return visible_characters == -1 or visible_characters == get_total_character_count()
 
@export_enum("Left", "Center", "Right") var align: int
#@export var font_color : Color
#@export var outline_color : Color
#@export var text_font :Font #DynamicFont
#@export var block_outline : bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	setText(text)
	var textFont = get("default_font")# get("theme_override_fonts/normal_font")
	var textNormalFont = get("theme_override_fonts/normal_font")
	var fontSize = get("default_font_size")# get("theme_override_font_sizes/normal_font_size")
	var fontColor = get("theme_override_colors/default_color")
	var outlineColor = get("theme_override_colors/font_shadow_color")
	var lineSeparation: int = get("theme_override_constants/line_separation")
	var topSpacing = get("spacing_top")

	$Outline.set("default_font", textFont)#.set("theme_override_fonts/normal_font", textFont)
	$Outline2.set("default_font", textFont)#.set("theme_override_fonts/normal_font", textFont)

	$Outline.set("default_font_size", fontSize)#.set("theme_override_font_sizes/normal_font_size", fontSize)
	$Outline2.set("default_font_size", fontSize)#.set("theme_override_font_sizes/normal_font_size", fontSize)

	$Outline.set("theme_override_colors/default_color", fontColor)
	$Outline2.set("theme_override_colors/default_color", fontColor)

	$Outline.set("theme_override_colors/font_shadow_color", outlineColor)
	$Outline2.set("theme_override_colors/font_shadow_color", outlineColor)
	
	$Outline.set("theme_override_constants/line_separation", lineSeparation)
	$Outline2.set("theme_override_constants/line_separation", lineSeparation)
	
	$Outline.set("spacing_top", topSpacing)
	$Outline2.set("spacing_top", topSpacing)
	
	$Outline.theme = theme
	$Outline2.theme = theme
	
	$Outline.set("theme_override_fonts/normal_font", textNormalFont)
	$Outline2.set("theme_override_fonts/normal_font", textNormalFont)

func _draw() -> void:
	$Outline.position = Vector2(0, 0)
	$Outline.size = self.size
	$Outline.custom_minimum_size = self.size
	$Outline2.position = Vector2(0, 0)
	$Outline2.size = self.size
	$Outline2.custom_minimum_size = self.size
	
func setText(_text):
	var algn = ""
	match align:
		0:
			algn = "[left]"
		1:
			algn = "[center]"
		2:
			algn = "[right]"
	self.text = algn+str(_text)
func updateNextLine():
	nextLineStop += 1
	
func reset():
	lastLine = 0
	nextLineStop = 0
	visible_ratio = 0
	
func _set(name, value):
	match name:
		"text":
			#var algn = ""
			#match align:
				#0:
					#algn = "[left]"
				#1:
					#algn = "[center]"
				#2:
					#algn = "[right]"
			text = str(value)
			$Outline.text = str(value)
			$Outline2.text = str(value)
		"visible_characters":
			var nextLine = 0
			visible_characters = value
			$Outline.visible_characters = value
			$Outline2.visible_characters = value
			actualLine = get_character_line(visible_characters) + 1
			nextLine = get_character_line(visible_characters+1) + 1
			if nextLine == 0:
				nextLine = actualLine
			if messageHasFinished or nextLine != actualLine:
				line_displayed.emit()
				lastLine = actualLine
		"theme_override_colors/default_color":
				$Outline.set("theme_override_colors/default_color", value)
				$Outline2.set("theme_override_colors/default_color", value)
		"theme_override_colors/font_shadow_color":
				$Outline.set("theme_override_colors/font_shadow_color", value)
				$Outline2.set("theme_override_colors/font_shadow_color", value)
