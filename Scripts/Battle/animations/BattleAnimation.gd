extends Resource
class_name BattleAnimation

## Recurso reutilizable de animación de combate.
## Contrato canónico: Docs/battle/BattleAnimationContract.md
##
## Solo visualiza. Nunca modifica HP, estados, turnos ni resultados lógicos.
## El caller externo siempre hace: await battle_animation.play(...)

const USER_ANCHOR_SPOT_NAME := "ProjectileOrigin"
const TARGET_ANCHOR_SPOT_NAME := "HitCenter"

@export var animation_scene: PackedScene
@export var animation_name: String = "default"
## Reserva de API: hoy solo se soporta el path bloqueante (await hasta terminar).
@export var blocks_visualize: bool = true

## Punto de entrada único. Coroutine: el caller debe usar `await`.
func play(
	animation_layer: Node2D,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	if animation_layer == null or not is_instance_valid(animation_layer):
		push_warning("BattleAnimation.play: animation_layer inválido; se omite la animación.")
		return
	if animation_scene == null:
		push_warning("BattleAnimation.play: animation_scene es null; se omite la animación.")
		return

	var instance: Node = animation_scene.instantiate()
	if instance == null:
		push_warning("BattleAnimation.play: no se pudo instanciar animation_scene.")
		return

	animation_layer.add_child(instance)
	_prepare_instance(instance, user_spot, target_spots)

	var player := _find_animation_player(instance)
	if player == null:
		push_warning("BattleAnimation.play: no hay AnimationPlayer en la escena; cleanup y continue.")
		_cleanup_instance(instance)
		return

	var resolved_name := _resolve_animation_name(player)
	if resolved_name.is_empty():
		push_warning("BattleAnimation.play: no hay clips reproducibles en AnimationPlayer.")
		_cleanup_instance(instance)
		return

	# blocks_visualize == false queda reservado; este PBI siempre espera la animación principal.
	player.play(resolved_name)
	if player.is_playing():
		await player.animation_finished

	_cleanup_instance(instance)


## Prepara instancia: Hooks.bind, anchors y orientación. Seguro si faltan nodos.
func _prepare_instance(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	_bind_hooks(instance, user_spot, target_spots)
	_apply_scene_anchors(instance, user_spot, target_spots)
	_apply_orientation(instance, user_spot, target_spots)


func _bind_hooks(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var hooks_node := instance.get_node_or_null("Hooks")
	if hooks_node == null or not hooks_node.has_method("bind"):
		return
	hooks_node.bind(user_spot, target_spots)


func _apply_scene_anchors(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var user_anchor := instance.get_node_or_null("UserAnchor") as Node2D
	if user_anchor != null and user_spot != null and is_instance_valid(user_spot):
		user_anchor.global_position = user_spot.get_anchor_global_position(USER_ANCHOR_SPOT_NAME)

	var target_anchor := instance.get_node_or_null("TargetAnchor") as Node2D
	var first_target := _first_target(target_spots)
	if target_anchor != null and first_target != null:
		target_anchor.global_position = first_target.get_anchor_global_position(TARGET_ANCHOR_SPOT_NAME)


func _apply_orientation(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var first_target := _first_target(target_spots)
	if user_spot == null or first_target == null:
		return
	if not is_instance_valid(user_spot) or not is_instance_valid(first_target):
		return

	var from: Vector2 = user_spot.get_anchor_global_position("Center")
	var to: Vector2 = first_target.get_anchor_global_position("Center")
	var dir_x: float = to.x - from.x
	if is_zero_approx(dir_x):
		return

	var visual := instance.get_node_or_null("VisualRoot") as Node2D
	if visual == null and instance is Node2D:
		visual = instance as Node2D
	if visual == null:
		return

	var sx := absf(visual.scale.x)
	if sx < 0.0001:
		sx = 1.0
	visual.scale.x = sx if dir_x >= 0.0 else -sx


func _first_target(target_spots: Array[BattleSpot]) -> BattleSpot:
	if target_spots == null or target_spots.is_empty():
		return null
	var spot: BattleSpot = target_spots[0]
	if spot == null or not is_instance_valid(spot):
		return null
	return spot


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	return _find_animation_player_recursive(root)


func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
		var nested := _find_animation_player_recursive(child)
		if nested != null:
			return nested
	return null


func _resolve_animation_name(player: AnimationPlayer) -> String:
	if player.has_animation(animation_name):
		return animation_name
	var namespaced := "default/%s" % animation_name
	if player.has_animation(namespaced):
		return namespaced
	if player.has_animation("default"):
		return "default"
	if player.has_animation("default/default"):
		return "default/default"
	var list := player.get_animation_list()
	if list.is_empty():
		return ""
	push_warning(
		"BattleAnimation.play: clip '%s' no encontrado; se usa '%s'."
		% [animation_name, list[0]]
	)
	return list[0]


func _cleanup_instance(instance: Node) -> void:
	if instance == null:
		return
	if is_instance_valid(instance):
		instance.queue_free()
