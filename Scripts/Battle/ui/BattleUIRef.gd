extends Resource
class_name BattleUIRef

var message_box
var result_display

func show_message(text: String) -> void:
	if message_box:
		await message_box.show_message(text)

func play_status_animation(name: String, target):
	if result_display:
		await result_display.play_status_animation(name, target)
