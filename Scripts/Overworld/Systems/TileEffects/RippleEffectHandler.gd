extends TileEffectHandler
class_name RippleEffectHandler

## Handler para efectos de agua (ripple)
## Maneja la animación de ripple cuando se pisa agua

# Escena de efecto
var ripple_effect_scene: PackedScene

# Estado del último efecto
var _last_effect_tile: Vector2i = Vector2i(-9999, -9999)


func _init(p_effect_system: TileEffectSystem) -> void:
	super._init("water", p_effect_system)  # "water" es el terrain type para agua


## Configura la escena de efecto
func setup_effects(ripple_effect: PackedScene) -> void:
	ripple_effect_scene = ripple_effect


func on_step_started_to_tile(grid: OverworldGrid, _destination_tile: Vector2i, actor: Node2D) -> void:
	# Mostrar ripple en el tile de origen (donde empieza el movimiento)
	# cuando el destino es agua
	pass
	# var from_tile = grid.world_to_tile(actor.global_position)
	# if from_tile != _last_effect_tile:
	# 	var from_world_pos = grid.tile_to_world_center(from_tile)
	# 	_show_ripple_effect(from_world_pos)
	# 	_last_effect_tile = from_tile


func on_step_finished_on_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D, _had_collision: bool) -> void:
	# El ripple ya se mostró en step_started, no hacer nada aquí
	pass


func on_step_exited_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D) -> void:
	if _tile != _last_effect_tile:
		var from_world_pos = _grid.tile_to_world_center(_tile)
		_show_ripple_effect(from_world_pos)
		_last_effect_tile = _tile


func clear_state() -> void:
	_last_effect_tile = Vector2i(-9999, -9999)


func _show_ripple_effect(position: Vector2) -> void:
	if not ripple_effect_scene:
		return
	var effect = ripple_effect_scene.instantiate() as Node2D
	effect.global_position = position
	effect_system._add_effect_to_scene(effect)
