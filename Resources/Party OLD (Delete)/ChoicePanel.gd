extends Panel

class_name ChoicePanel

var styleSelected: StyleBox
var styleUnselected: StyleBox

@onready var arrow:Panel = $Arrow
@onready var selected:bool = false

@onready var added:bool = false

var index:int
@export_multiline var text:String:
	get:
		if $Text.text != "":
			return $Text.text
		return text
	set(text):
		$Text.setText(text)

func _ready():
	pass
	focus_entered.connect(Callable(self, "_on_focus_entered"))
	focus_exited.connect(Callable(self, "_on_focus_exited"))

func select():
	print(name)
	arrow.add_theme_stylebox_override("panel", styleSelected)
	selected = true
	
func unselect():
	arrow.add_theme_stylebox_override("panel", styleUnselected)
	selected = false


func _on_focus_entered():
	print("select " + name)
	select()

func _on_focus_exited():
	print("unselect " + name)
	unselect()
