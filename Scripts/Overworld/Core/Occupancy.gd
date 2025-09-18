extends Node
class_name Occupancy

@onready var actor := get_parent() as Node2D
@onready var grid: OverworldGrid = get_tree().get_first_node_in_group("OverworldGrid")

func _ready() -> void:
	# Snap al centro de tile y registra ocupación inicial
	var tile := grid.world_to_tile(actor.global_position)
	#actor.global_position = grid.tile_to_world_center(tile)
	if actor is Event:
		# Registrar siempre en events
		grid.register_event(tile, actor)

		# Para eventos, esperar a que se configure current_page
		call_deferred("register_event_occupancy", tile)
	else:
		# Cualquier otro actor (Player, NPC, etc.)
		grid.occupy(tile, actor)

func current_tile() -> Vector2i:
	return grid.world_to_tile(actor.global_position)

## Registra la ocupación del evento después de que se haya configurado current_page
func register_event_occupancy(tile: Vector2i) -> void:
	if actor is Event:
		# Registrar en occ solo si NO es through (bloquea el paso)
		if not actor.current_page or not actor.current_page.through:
			grid.occupy(tile, actor)

## Si en algún momento teletransportas:
func teleport_to_tile(t: Vector2i) -> void:
	var cur := grid.world_to_tile(actor.global_position)
	# Limpiar registros previos
	if actor is Event:
		grid.unregister_event(cur, actor)
		if not actor.current_page or not actor.current_page.through:
			grid.vacate(cur, actor)
	else:
		grid.vacate(cur, actor)

	# Reubicar
	actor.global_position = grid.tile_to_world_center(t)

	# Registrar de nuevo
	if actor is Event:
		grid.register_event(t, actor)
		if not actor.current_page or not actor.current_page.through:
			grid.occupy(t, actor)
	else:
		grid.occupy(t, actor)
