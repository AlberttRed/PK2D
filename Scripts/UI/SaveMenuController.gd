extends RefCounted
class_name SaveMenuController

var _context: OverworldContext = null
var _slot_id: int = 0


func _init(context: OverworldContext = null, slot_id: int = 0) -> void:
	_context = context
	_slot_id = maxi(0, slot_id)


func get_slot_id() -> int:
	return _slot_id


func has_existing_save() -> bool:
	return GameStateService.has_valid_save(_slot_id)


func build_view_model() -> Dictionary:
	var map_label := "—"
	var map_id := GameStateService.get_current_map_id()
	if not map_id.is_empty():
		map_label = map_id.replace("_", " ")
	var player_name := get_player_name()
	var play_time := _build_session_time_text()
	var badge_count := int(GameStateService.get_variable("BADGE_COUNT", 0))
	return {
		"route_text": map_label,
		"player_text": player_name,
		"time_text": play_time,
		"badges_text": str(maxi(0, badge_count)),
	}


func get_player_name() -> String:
	var raw_name := str(GameStateService.get_variable("PLAYER_NAME", "PLAYER")).strip_edges()
	if raw_name.is_empty():
		return "PLAYER"
	return raw_name


func sync_runtime_before_save() -> void:
	if _context == null:
		return
	var world_system := _context.get_world_system()
	if world_system != null and world_system.has_method("sync_position_for_save"):
		world_system.sync_position_for_save()


func save_game() -> Dictionary:
	sync_runtime_before_save()
	return GameStateService.save_game(_slot_id)


func _build_session_time_text() -> String:
	var secs := int(floor(float(Time.get_ticks_msec()) / 1000.0))
	var h := int(floor(float(secs) / 3600.0))
	var m := int(floor(float(secs % 3600) / 60.0))
	return "%02d:%02d" % [h, m]
