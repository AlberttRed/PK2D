
extends Node

@onready var ui_down = get_node("ui_down")
@onready var ui_up = get_node("ui_up")
@onready var ui_left = get_node("ui_left")
@onready var ui_right = get_node("ui_right")
@onready var ui_accept = get_node("ui_accept")
@onready var ui_cancel = get_node("ui_cancel")
@onready var ui_start = get_node("ui_start")
@onready var ui_select = get_node("ui_select")
@onready var timer = $Timer

var ui_accept_input = false

var evento = null

func remote_action(action, time = 0.2):
	if evento != null:
		evento.pressed = false
		Input.parse_input_event(evento)
	evento = InputEventAction.new()
	evento.action = action
	evento.pressed = true
	Input.parse_input_event(evento)
	timer.wait_time = time
	timer.start()
	await timer.timeout
	
func remote_release(action, time = 0.1):
	evento = InputEventAction.new()
	evento.action = action
	evento.pressed = false
	Input.parse_input_event(evento)
	timer.wait_time = time
	timer.start()
	await timer.timeout

func is_action_player_pressed(action):
	if GLOBAL.PLAYER.move_from_event:
		return Input.is_action_pressed(action+"_event")
	else:
		return Input.is_action_pressed(action)

func _on_timer_timeout():
	evento.pressed = false
	Input.parse_input_event(evento)

func wait_for_input(_input):
	while (!ui_accept_input):# and options == []):#(!Input.is_action_pressed("ui_accept")):
		pass
		#print("lolol")
		#await get_tree().process_frame
#
#
#func _input(event):
#		if event.is_action_pressed("ui_accept"):
#			#Input.action_release("ui_accept")
#			print("si")
#			ui_accept_input = true
#
#		if event.is_action_released("ui_accept"):
#			print("no")
#			ui_accept_input = false
#
