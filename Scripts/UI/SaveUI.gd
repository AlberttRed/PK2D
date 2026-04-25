extends Control
class_name SaveMenuUI

signal closed()

@onready var _route_label = $Panel/MarginContainer/StatsList/Route/LabelHGSS
@onready var _player_data_label = $Panel/MarginContainer/StatsList/Player/Data
@onready var _time_data_label = $Panel/MarginContainer/StatsList/Time/Data
@onready var _medals_data_label = $Panel/MarginContainer/StatsList/Medals/Data

var _controller = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func setup(controller) -> void:
	_controller = controller
	_refresh_view()


func open() -> void:
	_refresh_view()
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _refresh_view() -> void:
	if _controller == null:
		return
	var vm: Dictionary = _controller.build_view_model()
	_set_label_text(_route_label, str(vm.get("route_text", "—")))
	_set_label_text(_player_data_label, str(vm.get("player_text", "PLAYER")))
	_set_label_text(_time_data_label, str(vm.get("time_text", "00:00")))
	_set_label_text(_medals_data_label, str(vm.get("badges_text", "0")))


func _set_label_text(node: Node, text: String) -> void:
	if node == null:
		return
	if node.has_method("setText"):
		node.setText(text)
	elif node is Label:
		(node as Label).text = text
