extends Resource
class_name BattleAnimation

## Recurso reutilizable de animación de combate.
## Contrato canónico: Docs/battle/BattleAnimationContract.md
##
## Solo visualiza. Nunca modifica HP, estados, turnos ni resultados lógicos.
## El caller externo siempre hace: await battle_animation.play(...)

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


## Hook para subclases / PBI 671 (anchors, flip). Base: no-op.
func _prepare_instance(
	_instance: Node,
	_user_spot: BattleSpot,
	_target_spots: Array[BattleSpot]
) -> void:
	pass


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
