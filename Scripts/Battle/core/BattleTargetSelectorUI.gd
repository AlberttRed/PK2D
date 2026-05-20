extends Control
class_name BattleTargetSelectorUI

signal target_chosen(spot: BattleSpot)

var _grid: TargetSelectionGrid = null


func _ready() -> void:
	call_deferred("_connect_display_manager_inputs")


func show_selection(grid: TargetSelectionGrid) -> void:
	_grid = grid
	visible = true
	var dm := DisplayManager.instance
	if dm and not dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.connect(_on_input_cancel)
	_refresh_highlight()


func _refresh_highlight() -> void:
	if _grid == null:
		return
	var current := _grid.current_spot()
	for spot in _grid.all_spots():
		spot.highlight(spot == current)


func hide_selector() -> void:
	if _grid != null:
		for spot in _grid.all_spots():
			spot.highlight(false)
	var dm := DisplayManager.instance
	if dm and dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.disconnect(_on_input_cancel)
	_grid = null
	visible = false


func _on_input_left() -> void:
	_nav_column(-1)


func _on_input_right() -> void:
	_nav_column(1)


func _on_input_up() -> void:
	_nav_row(-1)


func _on_input_down() -> void:
	_nav_row(1)


func _nav_column(delta: int) -> void:
	if not visible or _grid == null:
		return
	_grid.move_column(delta)
	_refresh_highlight()


func _nav_row(delta: int) -> void:
	if not visible or _grid == null or not _grid.can_switch_row():
		return
	_grid.move_row(delta)
	_refresh_highlight()


func _on_input_accept() -> void:
	if not visible or _grid == null:
		return
	var chosen := _grid.current_spot()
	if chosen == null:
		return
	target_chosen.emit(chosen)
	hide_selector()


func _on_input_cancel() -> void:
	if not visible:
		return
	hide_selector()
	target_chosen.emit(null)


func _connect_display_manager_inputs() -> void:
	var dm := DisplayManager.instance
	if not dm:
		call_deferred("_connect_display_manager_inputs")
		return
	for sig: Dictionary in [
		{"signal": dm.input_left, "callable": _on_input_left},
		{"signal": dm.input_right, "callable": _on_input_right},
		{"signal": dm.input_up, "callable": _on_input_up},
		{"signal": dm.input_down, "callable": _on_input_down},
		{"signal": dm.input_accept, "callable": _on_input_accept},
	]:
		if not sig.signal.is_connected(sig.callable):
			sig.signal.connect(sig.callable)
