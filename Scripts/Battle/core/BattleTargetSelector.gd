extends Control

signal target_chosen(spot: BattleSpot)

var spots: Array[BattleSpot] = []
var current_index := 0

func _ready():
	# Conectar a las señales de input del SignalManager
	SignalManager.input_left.connect(_on_input_left)
	SignalManager.input_right.connect(_on_input_right)
	SignalManager.input_accept.connect(_on_input_accept)


func show_targets(selectable_spots: Array[BattleSpot]) -> void:
	spots = selectable_spots
	current_index = 0
	visible = true
	
	# Verificar si ya está conectada antes de conectar
	if not SignalManager.input_cancel.is_connected(_on_input_cancel):
		SignalManager.input_cancel.connect(_on_input_cancel)
	
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
	
	# Verificar si está conectada antes de desconectar
	if SignalManager.input_cancel.is_connected(_on_input_cancel):
		SignalManager.input_cancel.disconnect(_on_input_cancel)
	
	visible = false
