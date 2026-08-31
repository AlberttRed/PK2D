extends RefCounted
class_name PokeballThrowSpriteFrames

## Spritesheet `{ball_id}_throw.png`: columna 128×128.
## Frames 0–3: vuelo / giro. Frame 3 (4.º): cerrada horizontal (como ballXX).
## Frames 3–7: apertura + energía (sustituye ballXX_open; sin anillos finales).

const FRAME_SIZE := Vector2i(128, 128)
const FLY_FRAME_COUNT := 4
const OPEN_START_FRAME := 3
const OPEN_END_FRAME := 7
const TOTAL_FRAMES := 15

static var _sheets: Dictionary = {}
static var _frames_by_id: Dictionary = {}


static func get_frame(ball_id: String, index: int) -> Texture2D:
	_ensure_frames(ball_id)
	var id := _resolved_id(ball_id)
	var frames: Array = _frames_by_id.get(id, [])
	if frames.is_empty():
		return null
	return frames[clampi(index, 0, TOTAL_FRAMES - 1)]


static func get_fly_frame(ball_id: String, index: int) -> Texture2D:
	return get_frame(ball_id, clampi(index, 0, FLY_FRAME_COUNT - 1))


static func get_open_frame_count() -> int:
	return OPEN_END_FRAME - OPEN_START_FRAME + 1


static func apply_field_scale(sprite: Sprite2D) -> void:
	if sprite == null:
		return
	sprite.scale = Vector2.ONE


static func setup_sprite_sheet_mode(sprite: Sprite2D, ball_id: String = PokeballItemEffect.DEFAULT_BALL_SPRITE_ID) -> void:
	if sprite == null:
		return
	var id := _resolved_id(ball_id)
	_ensure_frames(id)
	var sheet: Texture2D = _sheets.get(id)
	if sheet == null:
		return
	sprite.texture = sheet
	sprite.hframes = 1
	sprite.vframes = TOTAL_FRAMES
	sprite.frame = 0
	apply_field_scale(sprite)


static func _resolved_id(ball_id: String) -> String:
	var id := PokeballItemEffect.normalize_ball_sprite_id(ball_id)
	if _frames_by_id.has(id) and not (_frames_by_id[id] as Array).is_empty():
		return id
	var path := PokeballItemEffect.get_battle_throw_sheet_path(id)
	if ResourceLoader.exists(path):
		return id
	if id != PokeballItemEffect.DEFAULT_BALL_SPRITE_ID:
		push_warning("PokeballThrowSpriteFrames: no se encontró %s, usando ball00_throw." % path)
		return PokeballItemEffect.DEFAULT_BALL_SPRITE_ID
	return id


static func _ensure_frames(ball_id: String) -> void:
	var id := _resolved_id(ball_id)
	if _frames_by_id.has(id) and not (_frames_by_id[id] as Array).is_empty():
		return
	var path := PokeballItemEffect.get_battle_throw_sheet_path(id)
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
