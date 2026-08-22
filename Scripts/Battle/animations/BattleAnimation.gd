extends Resource
class_name BattleAnimation

## Recurso reutilizable de animación de combate.
## Contrato canónico: Docs/battle/BattleAnimationContract.md
##
## Proyectiles dirigidos: animar en +X de 0 a `authored_travel_length` (mismo valor en keys y export).
## Solo visualiza. El caller externo siempre hace: await battle_animation.play(...)

## Anchors del BattleSpot seleccionables en el inspector.
enum SpotAnchor {
	CENTER,
	HIT_CENTER,
	PROJECTILE_ORIGIN,
	STATUS_ICON,
	FEET,
	HEAD,
}

const MIN_AUTHORED_SPAN := 0.001

@export var animation_scene: PackedScene
@export var animation_name: String = "default"
## Reserva de API: hoy solo se soporta el path bloqueante (await hasta terminar).
@export var blocks_visualize: bool = true
## Si hay UserAnchor+TargetAnchor+VisualRoot (o spots), encaja VisualRoot al segmento real.
@export var fit_visual_to_anchors: bool = true
## Longitud authorada del viaje completo en +X local (debe coincidir con las keys del proyectil).
@export var authored_travel_length: float = 200.0
## Punto del spot del usuario al que se mapea UserAnchor / origen del VisualRoot.
@export var user_spot_anchor: SpotAnchor = SpotAnchor.PROJECTILE_ORIGIN
## Punto del spot del target al que se apunta el VisualRoot.
@export var target_spot_anchor: SpotAnchor = SpotAnchor.HIT_CENTER

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


## Prepara instancia: Hooks.bind, anchors y marco VisualRoot user→target.
func _prepare_instance(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	_bind_hooks(instance, user_spot, target_spots)
	_apply_scene_anchors_and_fit_visual(instance, user_spot, target_spots)


func _bind_hooks(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var hooks_node := instance.get_node_or_null("Hooks")
	if hooks_node == null or not hooks_node.has_method("bind"):
		return
	hooks_node.bind(user_spot, target_spots)


static func spot_anchor_name(anchor: SpotAnchor) -> String:
	match anchor:
		SpotAnchor.CENTER:
			return BattleSpot.ANCHOR_CENTER
		SpotAnchor.HIT_CENTER:
			return BattleSpot.ANCHOR_HIT_CENTER
		SpotAnchor.PROJECTILE_ORIGIN:
			return BattleSpot.ANCHOR_PROJECTILE_ORIGIN
		SpotAnchor.STATUS_ICON:
			return BattleSpot.ANCHOR_STATUS_ICON
		SpotAnchor.FEET:
			return BattleSpot.ANCHOR_FEET
		SpotAnchor.HEAD:
			return BattleSpot.ANCHOR_HEAD
		_:
			return BattleSpot.ANCHOR_CENTER


## Coloca anchors de escena (si existen) y encaja VisualRoot:
## - origen en el anchor de spot del user
## - +X local hacia el anchor de spot del target
## - scale.x = distancia_real / authored_travel_length
## Los proyectiles deben animarse en local de 0 a authored_travel_length en +X.
func _apply_scene_anchors_and_fit_visual(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var user_anchor := instance.get_node_or_null("UserAnchor") as Node2D
	var target_anchor := instance.get_node_or_null("TargetAnchor") as Node2D
	var user_anchor_name := spot_anchor_name(user_spot_anchor)
	var target_anchor_name := spot_anchor_name(target_spot_anchor)
	var first_target := _first_target(target_spots)

	var user_global := Vector2.ZERO
	var target_global := Vector2.ZERO
	var has_real_span := false
	if user_spot != null and is_instance_valid(user_spot) and first_target != null:
		user_global = user_spot.get_anchor_global_position(user_anchor_name)
		target_global = first_target.get_anchor_global_position(target_anchor_name)
		has_real_span = true

	if user_anchor != null and has_real_span:
		user_anchor.global_position = user_global
	if target_anchor != null and has_real_span:
		target_anchor.global_position = target_global

	if not fit_visual_to_anchors:
		# Status / VFX locales: VisualRoot en el spot afectado (target, o user si no hay target).
		_place_visual_on_affected_spot(instance, user_spot, target_spots)
		return
	if not has_real_span:
		return
	if authored_travel_length < MIN_AUTHORED_SPAN:
		push_warning("BattleAnimation: authored_travel_length inválido; no se escala VisualRoot.")
		return

	var visual := instance.get_node_or_null("VisualRoot") as Node2D
	if visual == null:
		return

	var real_vec := target_global - user_global
	var real_len := real_vec.length()

	visual.global_position = user_global
	# Eje authorado = +X local (viaje 0 → authored_travel_length).
	visual.rotation = real_vec.angle()
	var stretch := real_len / authored_travel_length
	var sy := absf(visual.scale.y)
	if sy < MIN_AUTHORED_SPAN:
		sy = 1.0
	visual.scale = Vector2(stretch, sy)


## Coloca VisualRoot en el anchor del spot afectado (sin rotar/estirar).
func _place_visual_on_affected_spot(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var visual := instance.get_node_or_null("VisualRoot") as Node2D
	if visual == null:
		return
	var spot := _first_target(target_spots)
	var anchor_name := spot_anchor_name(target_spot_anchor)
	if spot == null:
		spot = user_spot
		anchor_name = spot_anchor_name(user_spot_anchor)
	if spot == null or not is_instance_valid(spot):
		return
	visual.global_position = spot.get_anchor_global_position(anchor_name)
	visual.rotation = 0.0


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
