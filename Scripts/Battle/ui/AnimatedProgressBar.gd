extends Node2D
class_name AnimatedProgressBar

signal updated

@export var show_label: bool = true
@export var animate_duration := 1.0

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var lbl_value: RichTextLabel = $Label

var current_value: int = 0
var max_value: int = 0


func _ready() -> void:
	pass
	#set_values(100, 100)  # HP actual, HP total
	#await get_tree().create_timer(1.0).timeout  # Espera 1 segundo
	#await animate_to(35)  # Baja a 35, con animación
	#await get_tree().create_timer(1.0).timeout
	#await animate_to(80)
	
func set_values(current: int, max: int) -> void:
	current_value = current
	max_value = max
	progress_bar.max_value = max
	progress_bar.value = current
	if show_label:
		lbl_value.setText("%d/%d" % [current, max])
	update_color()

func update_color() -> void:
	var percentage = float(progress_bar.value) / float(progress_bar.max_value)
	if percentage > 0.5:
		progress_bar.tint_progress = CONST.BATTLE.HPCOLORGREEN
	elif percentage >= 0.2:
		progress_bar.tint_progress = CONST.BATTLE.HPCOLORYELLOW
	else:
		progress_bar.tint_progress = CONST.BATTLE.HPCOLORRED

func animate_to(new_value: int) -> void:
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", new_value, animate_duration)
	if show_label:
		tween.tween_method(set_label_value , current_value, new_value, animate_duration)
	current_value = new_value
	#tween.finished.connect(func(): updated.emit())
	await tween.finished
	
func set_label_value(value: float) -> void:
	lbl_value.setText("%d/%d" % [round(value), max_value])
	update_color()
	
func set_value_visible(state:bool):
	$Label.visible = state

func clear() -> void:
	progress_bar.value = 0
	progress_bar.max_value = 0
	lbl_value.setText("")
	current_value = 0
	max_value = 0
