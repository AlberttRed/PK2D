extends Control

signal target_chosen(spot: BattleSpot)

var spots: Array[BattleSpot] = []
var current_index := 0

func show_targets(selectable_spots: Array[BattleSpot]) -> void:
	spots = selectable_spots
	current_index = 0
	visible = true

	_update_selector()

func _process(_delta):
	if not visible or spots.is_empty():
		return

	if Input.is_action_just_pressed("ui_right"):
		current_index = (current_index + 1) % spots.size()
		_update_selector()

	elif Input.is_action_just_pressed("ui_left"):
		current_index = (current_index - 1 + spots.size()) % spots.size()
		_update_selector()

	elif Input.is_action_just_pressed("ui_accept"):
		var chosen_spot = spots[current_index]
		emit_signal("target_chosen", chosen_spot)
		hide_selector()

func _update_selector():
	for i in spots.size():
		spots[i].highlight(i == current_index)

func hide_selector():
	for spot in spots:
		spot.highlight(false)
	visible = false
