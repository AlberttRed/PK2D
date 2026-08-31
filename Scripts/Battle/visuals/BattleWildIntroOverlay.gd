class_name BattleWildIntroOverlay
extends Control
## Overlay de intro salvaje en BattleUI (Gen 3 / Essentials).
## Escena: Scenes/Battle/ui/BattleWildIntroOverlay.tscn


const WILD_INTRO_SCENE := preload("res://Scenes/Battle/ui/BattleWildIntroOverlay.tscn")
const DEFAULT_INTRO_DURATION := 1.786
const DEFAULT_PANEL_TOP_Y := 288.0
const SCROLL_SPEED_PX_PER_SEC := 540.0
## Duración mínima por defecto (ref. Gen 3). El wipe en dos fases deja ver el overlay en la pausa.
const DEFAULT_BASE_OVERLAP_FRACTION := 1.0
## Grass: scroll sin bajar / tiempo de bajada.
const DROP_DELAY_FRACTION := 0.52
const DROP_DURATION_FRACTION := 0.38
## Tall grass: baja a 40% al entrar bases; a mitad de slide baja hasta desaparecer.
const TALL_GRASS_START_SCREEN_HEIGHT_FRACTION := 0.6
const TALL_GRASS_MID_SCREEN_HEIGHT_FRACTION := 0.4
const TALL_GRASS_BASE_HALF_FRACTION := 0.5
## Mar: crece desde abajo (estira hacia arriba) y hace fade (ref. frames ~7–31).
const SEA_MIN_SCALE_Y := 0.38
const SEA_RISE_END_FRACTION := 0.68
const SEA_FADE_START_FRACTION := 0.68
## Agua quieta (48px): altura fija, scroll y bajada tras el panel (ref. frames ~10–33).
const STILL_WATER_DISPLAY_SCALE_Y := 2.0
## Arena / underwater: altura fija, scroll y fade (ref. frames ~7–38).
const SCROLL_FADE_START_FRACTION := 0.68
## Underwater (196px): ~58px vacíos bajo las burbujas; alinear contenido con el panel.
const UNDERWATER_BOTTOM_TRIM_PX := 58.0
## Cueva: scroll y bajada progresiva tras el panel (ref. frames ~7–35).
const CAVE_DROP_DELAY_FRACTION := 0.35
const CAVE_DROP_DURATION_FRACTION := 0.6
## Debajo del MessageBox (6), encima del campo y bases.
const BATTLE_Z_INDEX := 5

signal finished_playing


@onready var _strip_row: Control = $GrassRow

var _intro_type: BattleWildIntroEnum.Values = BattleWildIntroEnum.Values.NONE
var _texture: Texture2D
var _texture_width: float = 1.0
var _texture_height: float = 1.0
var _scroll_x: float = 0.0
var _drop_progress: float = 0.0
var _rise_progress: float = 0.0
var _fade_progress: float = 0.0
var _tall_grass_height_fraction: float = TALL_GRASS_START_SCREEN_HEIGHT_FRACTION
var _reveal_duration: float = 0.4
var _panel_top_y: float = DEFAULT_PANEL_TOP_Y
var _strip_start_y: float = 0.0
var _strip_drop_distance: float = 0.0
var _has_finished: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	z_as_relative = false
	z_index = BATTLE_Z_INDEX


func configure(intro_type: BattleWildIntroEnum.Values) -> bool:
	_intro_type = intro_type
	_ensure_strip_row()
	var texture_path := BattleWildIntroEnum.get_texture_path(intro_type)
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		push_warning("BattleWildIntroOverlay: sin textura para %s" % BattleWildIntroEnum.get_type_name(intro_type))
		return false
	_texture = load(texture_path) as Texture2D
	if _texture == null:
		return false
	_texture_width = maxf(float(_texture.get_width()), 1.0)
	_texture_height = maxf(float(_texture.get_height()), 1.0)
	_apply_strip_layout()
	return true


func _ensure_strip_row() -> void:
	if _strip_row == null:
		_strip_row = get_node_or_null("GrassRow") as Control


func is_configured() -> bool:
	return _texture != null and _strip_row != null


func set_panel_top_y(panel_top_y: float) -> void:
	_panel_top_y = maxf(panel_top_y, 0.0)


func play(duration: float = DEFAULT_INTRO_DURATION, reveal_duration: float = 0.4) -> void:
	_has_finished = false
	if not is_configured():
		_mark_finished()
		return
	_reveal_duration = reveal_duration
	visible = true
	modulate.a = 1.0
	_scroll_x = 0.0
	_drop_progress = 0.0
	_rise_progress = 0.0
	_fade_progress = 0.0
	_tall_grass_height_fraction = TALL_GRASS_START_SCREEN_HEIGHT_FRACTION
	if BattleWildIntroEnum.uses_water_rise_fade_motion(_intro_type):
		await _play_sea_motion(duration)
	elif BattleWildIntroEnum.uses_still_water_motion(_intro_type):
		await _play_still_water_motion(duration)
	elif BattleWildIntroEnum.uses_scroll_fade_motion(_intro_type):
		await _play_scroll_fade_motion(duration)
	elif BattleWildIntroEnum.uses_tall_grass_motion(_intro_type):
		await _play_tall_grass_motion(duration)
	elif BattleWildIntroEnum.uses_cave_motion(_intro_type):
		await _play_cave_motion(duration)
	elif BattleWildIntroEnum.uses_grass_drop_motion(_intro_type):
		await _play_grass_drop_motion(duration)
	else:
		_mark_finished()
		return
	visible = false
	modulate.a = 1.0
	_mark_finished()


func _play_grass_drop_motion(duration: float) -> void:
	_strip_start_y = _panel_top_y - _texture_height
	_strip_drop_distance = _texture_height
	_apply_strip_position()
	var drop_delay := duration * DROP_DELAY_FRACTION
	var drop_duration := duration * DROP_DURATION_FRACTION
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_scroll_progress, 0.0, duration * SCROLL_SPEED_PX_PER_SEC, duration)
	tween.tween_method(_set_drop_progress, 0.0, 1.0, drop_duration).set_delay(drop_delay).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tween.finished


func _play_tall_grass_motion(duration: float) -> void:
	_apply_strip_position()
	var base_half_time := _reveal_duration + (
		BattleFieldAnimations.BASE_ENTER_DURATION * TALL_GRASS_BASE_HALF_FRACTION
	)
	var drop_duration := maxf(duration - base_half_time, 0.01)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_scroll_progress, 0.0, duration * SCROLL_SPEED_PX_PER_SEC, duration)
	tween.tween_method(
		_set_tall_grass_height_fraction,
		TALL_GRASS_START_SCREEN_HEIGHT_FRACTION,
		TALL_GRASS_MID_SCREEN_HEIGHT_FRACTION,
		_reveal_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_drop_progress, 0.0, 1.0, drop_duration).set_delay(base_half_time).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tween.finished


func _play_still_water_motion(duration: float) -> void:
	var display_height := _still_water_display_height()
	_strip_start_y = _panel_top_y - display_height
	_strip_drop_distance = display_height
	_apply_strip_position()
	var drop_delay := duration * DROP_DELAY_FRACTION
	var drop_duration := duration * DROP_DURATION_FRACTION
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_scroll_progress, 0.0, duration * SCROLL_SPEED_PX_PER_SEC, duration)
	tween.tween_method(_set_drop_progress, 0.0, 1.0, drop_duration).set_delay(drop_delay).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tween.finished


func _play_scroll_fade_motion(duration: float) -> void:
	_strip_start_y = _scroll_fade_strip_y()
	_apply_strip_position()
	var fade_duration := duration * (1.0 - SCROLL_FADE_START_FRACTION)
	var fade_delay := duration * SCROLL_FADE_START_FRACTION
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_scroll_progress, 0.0, duration * SCROLL_SPEED_PX_PER_SEC, duration)
	tween.tween_method(_set_fade_progress, 0.0, 1.0, fade_duration).set_delay(fade_delay).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tween.finished


func _play_cave_motion(duration: float) -> void:
	_strip_start_y = _panel_top_y - _texture_height
	_strip_drop_distance = _texture_height
	_apply_strip_position()
	var drop_delay := duration * CAVE_DROP_DELAY_FRACTION
	var drop_duration := duration * CAVE_DROP_DURATION_FRACTION
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_scroll_progress, 0.0, duration * SCROLL_SPEED_PX_PER_SEC, duration)
	tween.tween_method(_set_drop_progress, 0.0, 1.0, drop_duration).set_delay(drop_delay).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tween.finished


func _play_sea_motion(duration: float) -> void:
	_apply_strip_position()
	var rise_duration := duration * SEA_RISE_END_FRACTION
	var fade_duration := duration * (1.0 - SEA_FADE_START_FRACTION)
	var fade_delay := duration * SEA_FADE_START_FRACTION
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_scroll_progress, 0.0, duration * SCROLL_SPEED_PX_PER_SEC, duration)
	tween.tween_method(_set_rise_progress, 0.0, 1.0, rise_duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_method(_set_fade_progress, 0.0, 1.0, fade_duration).set_delay(fade_delay).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tween.finished


func _mark_finished() -> void:
	if _has_finished:
		return
	_has_finished = true
	finished_playing.emit()


func has_finished() -> bool:
	return _has_finished


static func duration_for_base_intro(
	reveal_duration: float,
	intro_type: BattleWildIntroEnum.Values = BattleWildIntroEnum.Values.NONE,
	base_enter_duration: float = BattleFieldAnimations.BASE_ENTER_DURATION,
	base_overlap_fraction: float = DEFAULT_BASE_OVERLAP_FRACTION
) -> float:
	var synced := reveal_duration + base_enter_duration * base_overlap_fraction
	if intro_type == BattleWildIntroEnum.Values.TALL_GRASS:
		var base_half_time := reveal_duration + base_enter_duration * TALL_GRASS_BASE_HALF_FRACTION
		var drop_time := base_enter_duration * (1.0 - TALL_GRASS_BASE_HALF_FRACTION)
		synced = base_half_time + drop_time
	return maxf(synced, BattleWildIntroEnum.min_intro_duration(intro_type))


static func play_for_ui(ui: BattleUI, rules: BattleRules, reveal_duration: float = 0.4) -> void:
	if ui == null:
		return
	var intro_type := BattleWildIntroEnum.resolve_from_rules(rules)
	var duration := duration_for_base_intro(reveal_duration, intro_type)
	if ui.field_ui != null:
		ui.field_ui.start_intro_background_scroll(duration)
	if intro_type == BattleWildIntroEnum.Values.NONE:
		return
	var overlay := WILD_INTRO_SCENE.instantiate() as BattleWildIntroOverlay
	if overlay == null:
		return
	ui.add_child(overlay)
	if ui.message_box != null:
		ui.move_child(overlay, ui.message_box.get_index())
	if not overlay.configure(intro_type):
		overlay.queue_free()
		return
	overlay.set_panel_top_y(_resolve_panel_top_y(ui))
	overlay.play(duration, reveal_duration)
	overlay.finished_playing.connect(_queue_free_overlay.bind(overlay), CONNECT_ONE_SHOT)


static func _resolve_panel_top_y(ui: BattleUI) -> float:
	if ui.message_box == null:
		return DEFAULT_PANEL_TOP_Y
	var top_y := ui.message_box.position.y
	if top_y <= 0.0 and ui.message_box.size.y > 0.0:
		top_y = ui.size.y - ui.message_box.size.y
	if top_y <= 0.0:
		return DEFAULT_PANEL_TOP_Y
	return top_y


static func _queue_free_overlay(overlay: BattleWildIntroOverlay) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()


func _apply_strip_layout() -> void:
	if _strip_row == null:
		return
	for strip_index in range(_strip_row.get_child_count()):
		var strip := _strip_row.get_child(strip_index) as TextureRect
		if strip == null:
			continue
		strip.texture = _texture
		strip.stretch_mode = TextureRect.STRETCH_KEEP
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.position = Vector2(strip_index * _texture_width, 0.0)
		strip.custom_minimum_size = Vector2(_texture_width, _texture_height)
		strip.size = Vector2(_texture_width, _texture_height)


func _set_scroll_progress(scroll_offset: float) -> void:
	_scroll_x = scroll_offset
	_apply_strip_position()


func _set_drop_progress(progress: float) -> void:
	_drop_progress = clampf(progress, 0.0, 1.0)
	_apply_strip_position()


func _set_rise_progress(progress: float) -> void:
	_rise_progress = clampf(progress, 0.0, 1.0)
	_apply_strip_position()


func _set_tall_grass_height_fraction(height_fraction: float) -> void:
	_tall_grass_height_fraction = clampf(height_fraction, 0.0, 1.0)
	_apply_strip_position()


func _set_fade_progress(progress: float) -> void:
	_fade_progress = clampf(progress, 0.0, 1.0)
	modulate.a = 1.0 - _fade_progress
	_apply_strip_position()


func _apply_strip_position() -> void:
	if _strip_row == null:
		return
	var wrapped_scroll := fposmod(_scroll_x, _texture_width)
	var scroll_x := -wrapped_scroll
	if BattleWildIntroEnum.uses_water_rise_fade_motion(_intro_type):
		var scale_y := lerpf(SEA_MIN_SCALE_Y, 1.0, _rise_progress)
		var display_height := _texture_height * scale_y
		for strip_index in range(_strip_row.get_child_count()):
			var strip := _strip_row.get_child(strip_index) as TextureRect
			if strip == null:
				continue
			strip.stretch_mode = TextureRect.STRETCH_SCALE
			strip.custom_minimum_size = Vector2(_texture_width, display_height)
			strip.size = Vector2(_texture_width, display_height)
		_strip_row.position = Vector2(scroll_x, _panel_top_y - display_height)
	elif BattleWildIntroEnum.uses_still_water_motion(_intro_type):
		var display_height := _still_water_display_height()
		for strip_index in range(_strip_row.get_child_count()):
			var strip := _strip_row.get_child(strip_index) as TextureRect
			if strip == null:
				continue
			strip.stretch_mode = TextureRect.STRETCH_SCALE
			strip.custom_minimum_size = Vector2(_texture_width, display_height)
			strip.size = Vector2(_texture_width, display_height)
		_strip_row.position = Vector2(scroll_x, _strip_start_y + _drop_progress * _strip_drop_distance)
	elif BattleWildIntroEnum.uses_scroll_fade_motion(_intro_type):
		_strip_row.position = Vector2(scroll_x, _strip_start_y)
	elif BattleWildIntroEnum.uses_cave_motion(_intro_type):
		_strip_row.position = Vector2(scroll_x, _strip_start_y + _drop_progress * _strip_drop_distance)
	elif BattleWildIntroEnum.uses_tall_grass_motion(_intro_type):
		var display_height := _viewport_height() * _tall_grass_height_fraction
		for strip_index in range(_strip_row.get_child_count()):
			var strip := _strip_row.get_child(strip_index) as TextureRect
			if strip == null:
				continue
			strip.stretch_mode = TextureRect.STRETCH_SCALE
			strip.custom_minimum_size = Vector2(_texture_width, display_height)
			strip.size = Vector2(_texture_width, display_height)
		var rest_y := _panel_top_y - display_height
		_strip_row.position = Vector2(scroll_x, rest_y + _drop_progress * display_height)
	elif BattleWildIntroEnum.uses_grass_drop_motion(_intro_type):
		_strip_row.position = Vector2(scroll_x, _strip_start_y + _drop_progress * _strip_drop_distance)


func _viewport_height() -> float:
	var height := get_viewport_rect().size.y
	if height <= 0.0:
		return 384.0
	return height


func _still_water_display_height() -> float:
	return _texture_height * STILL_WATER_DISPLAY_SCALE_Y


func _scroll_fade_strip_y() -> float:
	if _intro_type == BattleWildIntroEnum.Values.UNDERWATER:
		return _panel_top_y - _texture_height + UNDERWATER_BOTTOM_TRIM_PX
	return _panel_top_y - _texture_height
