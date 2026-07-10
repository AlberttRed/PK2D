extends BattleMoveEffect
class_name PerishSongMoveEffect


func visualize(ui: BattleUI) -> void:
	await ui.show_message_from_dict({
		"type": "wait",
		"text": "¡Los Pokémon que oigan la canción se debilitarán dentro de 3 turnos!",
		"wait_time": 2.0,
	})
