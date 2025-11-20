extends TileEffectHandler
class_name GrassEffectHandler

## Handler para efectos de hierba (tall grass)
## Maneja la animación de hierba agitándose, overlay de hierba alta, y efectos visuales

# Escenas de efectos
var grass_effect_scene: PackedScene
var tall_grass_overlay_scene: PackedScene
var grass_stepped_effect_scene: PackedScene

# Estado del overlay
var _active_overlay: Sprite2D = null
var _last_overlay_tile: Vector2i = Vector2i(-9999, -9999)
var _last_effect_tile: Vector2i = Vector2i(-9999, -9999)

const OVERLAY_Z_LOW := 0
const OVERLAY_Z_HIGH := 5


func _init(p_effect_system: TileEffectSystem) -> void:
	super._init("grass", p_effect_system)  # "grass" es el terrain type para hierba


## Configura las escenas de efectos
func setup_effects(grass_effect: PackedScene, overlay: PackedScene, stepped: PackedScene) -> void:
	grass_effect_scene = grass_effect
	tall_grass_overlay_scene = overlay
	grass_stepped_effect_scene = stepped


func on_step_started_to_tile(grid: OverworldGrid, destination_tile: Vector2i, _actor: Node2D) -> void:
	_hide_overlay()
	_last_overlay_tile = Vector2i(-9999, -9999)

	var destination_pos = grid.tile_to_world_center(destination_tile)
	_show_grass_stepped_effect(grid, destination_tile)
	_show_overlay_at_position(destination_pos, OVERLAY_Z_LOW)
	_last_overlay_tile = destination_tile


func on_step_finished_on_tile(grid: OverworldGrid, tile: Vector2i, actor: Node2D, had_collision: bool) -> void:
	if had_collision:
		_ensure_overlay_z_index(OVERLAY_Z_HIGH)
		if not _active_overlay:
			_ensure_overlay_at_position(grid, tile, OVERLAY_Z_HIGH)
	else:
		if tile != _last_effect_tile:
			_show_grass_effect(actor.global_position)
			_last_effect_tile = tile
		_ensure_overlay_at_position(grid, tile, OVERLAY_Z_HIGH)


func on_step_exited_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D) -> void:
	_clear_state()


func _clear_state() -> void:
	_hide_overlay()
	_last_effect_tile = Vector2i(-9999, -9999)
	_last_overlay_tile = Vector2i(-9999, -9999)


func _ensure_overlay_at_position(grid: OverworldGrid, tile: Vector2i, z_idx: int) -> void:
	var target_pos = grid.tile_to_world_center(tile)

	if _active_overlay and is_instance_valid(_active_overlay):
		if _active_overlay.global_position.distance_to(target_pos) > 1.0:
			_hide_overlay()
			_show_overlay_at_position(target_pos, z_idx)
			_last_overlay_tile = tile
		else:
			_active_overlay.z_index = z_idx
	else:
		_show_overlay_at_position(target_pos, z_idx)
		_last_overlay_tile = tile


func _ensure_overlay_z_index(z_idx: int) -> void:
	if _active_overlay and is_instance_valid(_active_overlay):
		_active_overlay.z_index = z_idx


func _show_grass_effect(position: Vector2) -> void:
	if not grass_effect_scene:
		return
	var effect = grass_effect_scene.instantiate() as Node2D
	effect.global_position = position
	effect_system._add_effect_to_scene(effect)


func _show_grass_stepped_effect(grid: OverworldGrid, tile: Vector2i) -> void:
	if not grass_stepped_effect_scene:
		return
	var effect = grass_stepped_effect_scene.instantiate() as AnimatedSprite2D
	effect.global_position = grid.tile_to_world_center(tile)
	effect_system._add_effect_to_scene(effect)


func _show_overlay_at_position(world_position: Vector2, z_idx: int) -> void:
	if _active_overlay and is_instance_valid(_active_overlay):
		return
	if not tall_grass_overlay_scene:
		return

	var overlay = tall_grass_overlay_scene.instantiate() as Sprite2D
	overlay.global_position = world_position
	overlay.z_index = z_idx
	effect_system._add_effect_to_scene(overlay)
	_active_overlay = overlay


func _hide_overlay() -> void:
	if _active_overlay != null and is_instance_valid(_active_overlay):
		_active_overlay.queue_free()
		_active_overlay = null

