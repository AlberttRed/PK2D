extends RefCounted
class_name PokeballFailSpriteFrames

## Spritesheet `{ball_id}_fail.png`: explosión de la ball al escapar el Pokémon.

const FRAME_SIZE := Vector2i(128, 128)
const TOTAL_FRAMES := 7

static var _sheets: Dictionary = {}
static var _frames_by_id: Dictionary = {}


static func get_frame(ball_id: String, index: int) -> Texture2D:
	_ensure_frames(ball_id)
	var id := _resolved_id(ball_id)
	var frames: Array = _frames_by_id.get(id, [])
	if frames.is_empty():
		return null
	return frames[clampi(index, 0, TOTAL_FRAMES - 1)]


static func _resolved_id(ball_id: String) -> String:
	var id := PokeballItemEffect.normalize_ball_sprite_id(ball_id)
	if _frames_by_id.has(id) and not (_frames_by_id[id] as Array).is_empty():
		return id
	var path := PokeballItemEffect.get_battle_fail_sheet_path(id)
	if ResourceLoader.exists(path):
		return id
	if id != PokeballItemEffect.DEFAULT_BALL_SPRITE_ID:
		push_warning("PokeballFailSpriteFrames: no se encontró %s, usando ball00_fail." % path)
		return PokeballItemEffect.DEFAULT_BALL_SPRITE_ID
	return id


static func _ensure_frames(ball_id: String) -> void:
	var id := _resolved_id(ball_id)
	if _frames_by_id.has(id) and not (_frames_by_id[id] as Array).is_empty():
		return
	var path := PokeballItemEffect.get_battle_fail_sheet_path(id)
	var sheet := load(path) as Texture2D
	if sheet == null:
		return
	_sheets[id] = sheet
	var frames: Array[Texture2D] = []
	for i in TOTAL_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0, i * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.append(atlas)
	_frames_by_id[id] = frames
