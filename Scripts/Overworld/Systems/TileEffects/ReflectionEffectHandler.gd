extends TileEffectHandler
class_name ReflectionEffectHandler

## Handler para efectos de reflejo en agua
## El reflejo se muestra cuando el tile INFERIOR es agua
## NO controla la máscara (eso lo hace el mapa)
## NO controla el recorte (eso lo hace el shader)

func _init(p_effect_system: TileEffectSystem) -> void:
	super._init("water", p_effect_system)

## Se llama cuando un actor EMPIEZA a moverse hacia un tile
func on_step_started_to_tile(grid: OverworldGrid, destination_tile: Vector2i, actor: Node2D) -> void:
	# Verificar el tile inferior del destino
	_check_bottom_tile_reflection(grid, destination_tile, actor)

## Se llama cuando un actor TERMINA un paso
func on_step_finished_on_tile(grid: OverworldGrid, tile: Vector2i, actor: Node2D, _had_collision: bool) -> void:
	# Verificar el tile inferior del tile actual
	_check_bottom_tile_reflection(grid, tile, actor)

## Se llama cuando un actor SALE de un tile
func on_step_exited_tile(grid: OverworldGrid, tile: Vector2i, actor: Node2D) -> void:
	# Verificar el tile inferior después de salir
	_check_bottom_tile_reflection(grid, tile, actor)

## Verifica si el tile inferior es agua y activa/desactiva el reflejo
func _check_bottom_tile_reflection(grid: OverworldGrid, current_tile: Vector2i, actor: Node2D) -> void:
	# El tile inferior es el tile debajo (Y+1)
	var bottom_tile := current_tile + Vector2i(0, 1)
	var bottom_tile_info := grid.get_tile_info(bottom_tile)
	var is_water: bool = (bottom_tile_info.terrain == "water")

	var reflection_sprite := actor.get_node_or_null("ReflectionSprite")
	if reflection_sprite:
		reflection_sprite.visible = is_water

