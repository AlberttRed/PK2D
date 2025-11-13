extends Control
class_name OverlayLayer

## OverlayLayer - Capa de efectos globales para el overworld
## Gestiona oscurecimiento general, efectos climáticos y máscara de iluminación.

const WEATHER_NONE := "none"
const WEATHER_RAIN := "rain"
const WEATHER_SNOW := "snow"
const WEATHER_FOG := "fog"
const WEATHER_STORM := "storm"

const SUPPORTED_WEATHER_TYPES := [
	WEATHER_NONE,
	WEATHER_RAIN,
	WEATHER_SNOW,
	WEATHER_FOG,
	WEATHER_STORM,
]

signal darkness_changed(level: float)
signal weather_changed(weather_type: String)
signal flashlight_toggled(enabled: bool)

@export_range(0.0, 1.0, 0.01)
var default_darkness: float = 0.0

@export_enum("none", "rain", "snow", "fog", "storm")
var default_weather: String = WEATHER_NONE

const FLASHLIGHT_DEFAULT_RADIUS: float = 0.14
const FLASHLIGHT_DEFAULT_SOFTNESS: float = 0.02
const FLASH_ANIM_START_RADIUS: float = FLASHLIGHT_DEFAULT_RADIUS
const FLASH_ANIM_END_RADIUS: float = 1.0
const FLASH_ANIM_DURATION: float = 3.0

var context: OverworldContext = null

var current_darkness: float = 0.0
var target_darkness: float = 0.0
var darkness_tween: Tween = null

var current_weather: String = WEATHER_NONE
var flashlight_enabled: bool = false
var flashlight_radius: float = FLASHLIGHT_DEFAULT_RADIUS
var flashlight_softness: float = FLASHLIGHT_DEFAULT_SOFTNESS
var flashlight_center: Vector2 = Vector2(0.5, 0.5)
var viewport_size: Vector2 = Vector2(1, 1)
var flash_animation_tween: Tween = null

@onready var darkness_rect: ColorRect = $DarknessRect
@onready var weather_container: Control = $WeatherContainer
@onready var rain_overlay: ColorRect = $WeatherContainer/RainOverlay
@onready var snow_overlay: ColorRect = $WeatherContainer/SnowOverlay
@onready var fog_overlay: ColorRect = $WeatherContainer/FogOverlay
@onready var storm_overlay: ColorRect = $WeatherContainer/StormOverlay
@onready var flashlight_mask: ColorRect = $FlashlightMask

func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_viewport_size()

	current_darkness = clampf(default_darkness, 0.0, 1.0)
	target_darkness = current_darkness
	_apply_darkness_immediate(current_darkness)

	_reset_weather_nodes()
	set_weather(default_weather, true)

	set_flashlight_enabled(false)

	get_viewport().size_changed.connect(_update_viewport_size)


func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context


func reset_to_defaults() -> void:
	set_darkness(default_darkness, 0.0)
	set_weather(default_weather, true)
	set_flashlight_enabled(false)


func set_darkness(level: float, duration: float = 0.2) -> void:
	var clamped_level := clampf(level, 0.0, 1.0)
	target_darkness = clamped_level

	if darkness_tween:
		darkness_tween.kill()
		darkness_tween = null

	if duration <= 0.0 or is_equal_approx(current_darkness, clamped_level):
		_apply_darkness_immediate(clamped_level)
		darkness_changed.emit(clamped_level)
		return

	darkness_tween = create_tween()
	darkness_tween.tween_method(_apply_darkness_progress, current_darkness, clamped_level, duration)
	darkness_tween.finished.connect(func() -> void:
		darkness_tween = null
		darkness_changed.emit(target_darkness)
	, CONNECT_ONE_SHOT)


func get_darkness() -> float:
	return current_darkness


func set_weather(weather_type: String, disable_transition: bool = false) -> void:
	var normalized_weather := weather_type.to_lower()
	if not SUPPORTED_WEATHER_TYPES.has(normalized_weather):
		push_warning("OverlayLayer: Tipo de clima desconocido '%s'. Usando 'none'." % weather_type)
		normalized_weather = WEATHER_NONE

	if current_weather == normalized_weather:
		return

	_hide_all_weather()
	current_weather = normalized_weather

	match normalized_weather:
		WEATHER_RAIN:
			_enable_weather_overlay(rain_overlay, disable_transition)
		WEATHER_SNOW:
			_enable_weather_overlay(snow_overlay, disable_transition)
		WEATHER_FOG:
			_enable_weather_overlay(fog_overlay, disable_transition)
		WEATHER_STORM:
			_enable_weather_overlay(storm_overlay, disable_transition)
		_:
			pass

	weather_changed.emit(current_weather)


func get_weather() -> String:
	return current_weather


func set_flashlight_enabled(enabled: bool, _radius: float = -1.0, _softness: float = -1.0) -> void:
	flashlight_enabled = enabled
	flashlight_radius = FLASHLIGHT_DEFAULT_RADIUS
	flashlight_softness = FLASHLIGHT_DEFAULT_SOFTNESS

	_update_flashlight_material()
	flashlight_mask.visible = flashlight_enabled
	flashlight_toggled.emit(flashlight_enabled)


func set_flashlight_center_screen(normalized_pos: Vector2) -> void:
	flashlight_center = normalized_pos.clamp(Vector2.ZERO, Vector2.ONE)
	_update_flashlight_material()


func get_flashlight_state() -> Dictionary:
	return {
		"enabled": flashlight_enabled,
		"radius": flashlight_radius,
		"softness": flashlight_softness,
		"center": flashlight_center,
	}


func _apply_darkness_immediate(level: float) -> void:
	current_darkness = clampf(level, 0.0, 1.0)
	darkness_rect.color = Color(0, 0, 0, current_darkness)


func _apply_darkness_progress(value: float) -> void:
	_apply_darkness_immediate(value)


func _hide_all_weather() -> void:
	for child in weather_container.get_children():
		if child is CanvasItem:
			var canvas_item := child as CanvasItem
			canvas_item.visible = false
			canvas_item.modulate = _color_with_alpha(canvas_item.modulate, 0.0)


func _enable_weather_overlay(node: Node, disable_transition: bool) -> void:
	if node is CanvasItem:
		var canvas_item := node as CanvasItem
		canvas_item.visible = true
		if disable_transition:
			canvas_item.modulate = _color_with_alpha(canvas_item.modulate, 1.0)
		else:
			var tween := create_tween()
			tween.tween_property(node, "modulate:a", 1.0, 0.35)


func _reset_weather_nodes() -> void:
	# Colores base para overlays simples. Se pueden sustituir por escenas específicas en el futuro.
	rain_overlay.visible = false
	rain_overlay.color = Color(0.6, 0.7, 0.9, 0.4)
	rain_overlay.modulate = Color(1, 1, 1, 0)

	snow_overlay.visible = false
	snow_overlay.color = Color(0.9, 0.9, 1.0, 0.45)
	snow_overlay.modulate = Color(1, 1, 1, 0)

	fog_overlay.visible = false
	fog_overlay.color = Color(0.8, 0.85, 0.95, 0.35)
	fog_overlay.modulate = Color(1, 1, 1, 0)

	storm_overlay.visible = false
	storm_overlay.color = Color(0.3, 0.35, 0.45, 0.55)
	storm_overlay.modulate = Color(1, 1, 1, 0)


func _update_flashlight_material() -> void:
	var mat := flashlight_mask.material
	if mat is ShaderMaterial:
		mat.set_shader_parameter("radius", flashlight_radius)
		mat.set_shader_parameter("softness", flashlight_softness)
		mat.set_shader_parameter("center", flashlight_center)
		mat.set_shader_parameter("viewport_size", viewport_size)
		mat.set_shader_parameter("pixel_snap", 1.0)
		var hardness := clampf(1.0 - flashlight_softness * 4.0, 0.0, 1.0)
		var min_softness_px: float = lerp(1.25, 0.08, hardness)
		mat.set_shader_parameter("min_softness_px", min_softness_px)

		var pixel_block: float = 1.0
		if hardness > 0.95:
			pixel_block = 3.0
		elif hardness > 0.85:
			pixel_block = 2.0
		mat.set_shader_parameter("pixel_block_size", pixel_block)

		var edge_sharpness: float = 1.0 + pow(hardness, 3.2) * 55.0
		mat.set_shader_parameter("edge_sharpness", edge_sharpness)

		var alpha_steps: float = 0.0
		if hardness > 0.92:
			alpha_steps = 3.0
		elif hardness > 0.8:
			alpha_steps = 2.0
		mat.set_shader_parameter("alpha_steps", alpha_steps)


func _update_viewport_size() -> void:
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	viewport_size = viewport_rect.size
	set_custom_minimum_size(viewport_rect.size)
	darkness_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flashlight_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_flashlight_material()


func _color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func play_flash_reveal(_desired_darkness: float, duration: float = FLASH_ANIM_DURATION) -> void:
	if flash_animation_tween:
		flash_animation_tween.kill()
		flash_animation_tween = null

	var original_darkness := current_darkness

	flashlight_enabled = true
	flashlight_radius = FLASH_ANIM_START_RADIUS
	flashlight_mask.visible = true
	_update_flashlight_material()

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flash_animation_tween = tween
	var shader_mat := flashlight_mask.material as ShaderMaterial
	if shader_mat:
		shader_mat.set_shader_parameter("radius", FLASH_ANIM_START_RADIUS)
		tween.parallel().tween_property(shader_mat, "shader_parameter/radius", FLASH_ANIM_END_RADIUS, duration)
	else:
		tween.parallel().tween_method(_set_flash_radius, FLASH_ANIM_START_RADIUS, FLASH_ANIM_END_RADIUS, duration)

	await tween.finished
	flash_animation_tween = null

	flashlight_enabled = false
	flashlight_mask.visible = false
	if shader_mat:
		shader_mat.set_shader_parameter("radius", FLASHLIGHT_DEFAULT_RADIUS)
	else:
		_set_flash_radius(FLASHLIGHT_DEFAULT_RADIUS)

	_apply_darkness_immediate(original_darkness)


func _set_flash_radius(value: float) -> void:
	flashlight_radius = value
	_update_flashlight_material()
