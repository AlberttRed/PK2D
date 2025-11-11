extends Control
class_name BattleTargetSelectorUI

signal target_chosen(spot: BattleSpot)

var spots: Array[BattleSpot] = []
var current_index := 0

func _ready():
	call_deferred("_connect_display_manager_inputs")

func show_targets(selectable_spots: Array[BattleSpot]) -> void:
	spots = selectable_spots
	current_index = 0
	visible = true
	var dm := DisplayManager.instance
	if dm and not dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.connect(_on_input_cancel)

	_update_selector()

func _on_input_left():
	if not visible or spots.is_empty():
		return
	current_index = (current_index - 1 + spots.size()) % spots.size()
	_update_selector()

func _on_input_right():
	if not visible or spots.is_empty():
		return
	current_index = (current_index + 1) % spots.size()
	_update_selector()

func _on_input_accept():
	if not visible or spots.is_empty():
		return
	var chosen_spot = spots[current_index]
	emit_signal("target_chosen", chosen_spot)
	hide_selector()

func _on_input_cancel():
	if not visible or spots.is_empty():
		return
	hide_selector()
	emit_signal("target_chosen", null)

func _update_selector():
	for i in spots.size():
		spots[i].highlight(i == current_index)

func hide_selector():
	for spot in spots:
		spot.highlight(false)
	var dm := DisplayManager.instance
	if dm and dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.disconnect(_on_input_cancel)
	visible = false

func _connect_display_manager_inputs() -> void:
	var dm := DisplayManager.instance
	if not dm:
		call_deferred("_connect_display_manager_inputs")
		return

	if not dm.input_left.is_connected(_on_input_left):
		dm.input_left.connect(_on_input_left)
	if not dm.input_right.is_connected(_on_input_right):
		dm.input_right.connect(_on_input_right)
	if not dm.input_accept.is_connected(_on_input_accept):
		dm.input_accept.connect(_on_input_accept)
