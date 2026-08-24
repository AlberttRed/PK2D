extends Node2D
class_name BattleSpot

## Se emite al asignar un Pokémon al terreno (`load_active_pokemon`). Escucha `BattleController` (u otro orquestador), no lógica de EXP aquí.
signal active_pokemon_loaded(pokemon: BattlePokemon)

var index = null
var pokemon: BattlePokemon = null
var side: BattleSide
var tween: Tween
var _selection_bounce_sprite_rest_y: float = 0.0
var _selection_bounce_hp_rest_y: float = 0.0
var _selection_bounce_hp_active: bool = false
var _selection_bounce_active: bool = false
var _selection_bounce_elapsed: float = 0.0

## Resaltado mientras eliges acción/movimiento (estilo juegos originales).
const SELECTION_BOUNCE_OFFSET := 3.0
const SELECTION_BOUNCE_CYCLE_SEC := 0.9

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

@onready var hp_bar: HPBar = $HPBar
@onready var hp_bar_pos_single: Marker2D = $Positions/HPBarPos_Single
@onready var hp_bar_pos_double: Marker2D = $Positions/HPBarPos_Double
@onready var anchors_root: Node2D = $Positions/Anchors

## Nombres estables de anchors visuales (PBI 671).
const ANCHOR_CENTER := "Center"
const ANCHOR_HIT_CENTER := "HitCenter"
const ANCHOR_PROJECTILE_ORIGIN := "ProjectileOrigin"
const ANCHOR_STATUS_ICON := "StatusIcon"
const ANCHOR_FEET := "Feet"
const ANCHOR_HEAD := "Head"
## Suelo del spot (sombra / campo): reposo de Poké Ball rival, distinto del bbox Feet.
const ANCHOR_BALL_GROUND := "BallGround"

const _OPAQUE_ALPHA_THRESHOLD := 0.06


func get_anchor_node(anchor_name: String) -> Node2D:
	if anchors_root == null:
		return null
	var node := anchors_root.get_node_or_null(anchor_name) as Node2D
	if node != null:
		return node
	if anchor_name != ANCHOR_CENTER:
		return anchors_root.get_node_or_null(ANCHOR_CENTER) as Node2D
	return null


func get_anchor_global_position(anchor_name: String) -> Vector2:
	var node := get_anchor_node(anchor_name)
	if node != null:
		return node.global_position
	return global_position


## Recalcula Markers de Anchors según el bbox opaco del sprite actual.
## Spot-local: Feet abajo, Head arriba, Center/HitCenter en el cuerpo.
func refresh_visual_anchors() -> void:
	if anchors_root == null:
		return
	var mid_x := 0.0
	if sprite == null:
		_refresh_ball_ground_anchor(mid_x)
		return
	var opaque := _get_sprite_opaque_rect_in_spot()
	if opaque.size.x <= 0.0 or opaque.size.y <= 0.0:
		_refresh_ball_ground_anchor(mid_x)
		return

	mid_x = opaque.position.x + opaque.size.x * 0.5
	var top_y := opaque.position.y
	var bottom_y := opaque.position.y + opaque.size.y
	var center_y := opaque.position.y + opaque.size.y * 0.5
	## Un poco por encima del centro geométrico (torso / zona de impacto).
	var hit_y := opaque.position.y + opaque.size.y * 0.42

	_set_anchor_position(ANCHOR_FEET, Vector2(mid_x, bottom_y))
	_set_anchor_position(ANCHOR_HEAD, Vector2(mid_x, top_y))
	_set_anchor_position(ANCHOR_CENTER, Vector2(mid_x, center_y))
	_set_anchor_position(ANCHOR_HIT_CENTER, Vector2(mid_x, hit_y))

	var toward_enemy := 1.0
	if side != null and side.type == BattleSide.Types.ENEMY:
		toward_enemy = -1.0
	elif pokemon != null and pokemon.side != null and pokemon.side.type == BattleSide.Types.ENEMY:
		toward_enemy = -1.0

	_set_anchor_position(
		ANCHOR_PROJECTILE_ORIGIN,
		Vector2(mid_x + toward_enemy * opaque.size.x * 0.22, hit_y - opaque.size.y * 0.05)
	)
	var status_x := opaque.position.x - 8.0
	if toward_enemy < 0.0:
		status_x = opaque.position.x + opaque.size.x + 8.0
	_set_anchor_position(ANCHOR_STATUS_ICON, Vector2(status_x, top_y))

	_refresh_ball_ground_anchor(mid_x)


## Suelo visual del spot (línea de sombra). No usar Feet dinámico: el bbox del sprite queda más arriba.
const BALL_GROUND_SPOT_A_Y_NUDGE := -10.0
const BALL_GROUND_SPOT_B_Y_NUDGE := -5.0


func _refresh_ball_ground_anchor(mid_x: float) -> void:
	var ground_y := 88.0
	if shadow != null:
		ground_y = shadow.position.y
	if index == 1:
		ground_y += BALL_GROUND_SPOT_A_Y_NUDGE
	elif index == 2:
		ground_y += BALL_GROUND_SPOT_B_Y_NUDGE
	_set_anchor_position(ANCHOR_BALL_GROUND, Vector2(mid_x, ground_y))


func _set_anchor_position(anchor_name: String, spot_local: Vector2) -> void:
	var node := anchors_root.get_node_or_null(anchor_name) as Node2D
	if node == null:
		return
	# Anchors cuelgan de Positions/Anchors; convertir desde espacio del spot.
	node.position = anchors_root.to_local(to_global(spot_local))


## Rect del contenido opaco del sprite en coordenadas locales del BattleSpot.
## Respeta el centrado de Sprite2D y el margin de AtlasTexture (región inset en el frame).
func _get_sprite_opaque_rect_in_spot() -> Rect2:
	var tex: Texture2D = sprite.texture
	if tex == null:
		return Rect2()

	var frame_size := tex.get_size()
	var region_origin := Vector2.ZERO
	var region_size := frame_size
	if tex is AtlasTexture:
		var atlas_tex := tex as AtlasTexture
		region_size = atlas_tex.region.size
		region_origin = Vector2(atlas_tex.margin.position.x, atlas_tex.margin.position.y)

	var img: Image = tex.get_image()
	var min_x := 0
	var min_y := 0
	var max_x := 0
	var max_y := 0

	if img != null and not img.is_empty():
		var w := img.get_width()
		var h := img.get_height()
		min_x = w
		min_y = h
		max_x = -1
		max_y = -1
		var found := false
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a > _OPAQUE_ALPHA_THRESHOLD:
					min_x = mini(min_x, x)
					min_y = mini(min_y, y)
					max_x = maxi(max_x, x)
					max_y = maxi(max_y, y)
					found = true
		if not found:
			min_x = 0
			min_y = 0
			max_x = w - 1
			max_y = h - 1
		# get_image() a veces es solo la región; a veces el frame ya con padding.
		# Solo sumar margin si los píxeles están en espacio de región.
		var image_is_region_space := (
			tex is AtlasTexture
			and absf(float(w) - region_size.x) < 0.5
			and absf(float(h) - region_size.y) < 0.5
		)
		if not image_is_region_space:
			region_origin = Vector2.ZERO
	else:
		# Sin imagen legible: usar el frame completo (incluye margins).
		max_x = int(frame_size.x) - 1
		max_y = int(frame_size.y) - 1
		region_origin = Vector2.ZERO

	var top_left := Vector2.ZERO
	if sprite.centered:
		top_left = -frame_size * 0.5
	top_left += sprite.offset
	top_left += region_origin

	var opaque_pos := sprite.position + top_left + Vector2(min_x, min_y)
	var opaque_size := Vector2(max_x - min_x + 1, max_y - min_y + 1)
	return Rect2(opaque_pos, opaque_size)


## Alinea el bbox opaco sobre la sombra del spot (centro X + contacto Y).
## BallGround no se usa aquí: tiene nudge de pokéball distinto al contacto visual.
## Luego aplica battlerPlayerY / battlerEnemyY y resta battlerAltitude.
const SPRITE_SHADOW_CONTACT_Y_NUDGE := 6.0

func _align_sprite_to_ground() -> void:
	if sprite == null or sprite.texture == null:
		return

	sprite.position = Vector2.ZERO
	var ground_x := 0.0
	var ground_y := 88.0
	if shadow != null:
		ground_x = shadow.position.x
		# Centro de la sombra + nudge: el oval queda bajo los pies, no flotando encima.
		ground_y = shadow.position.y + SPRITE_SHADOW_CONTACT_Y_NUDGE

	var opaque := _get_sprite_opaque_rect_in_spot()
	if opaque.size.y <= 0.0:
		return

	var opaque_bottom := opaque.position.y + opaque.size.y
	var opaque_mid_x := opaque.position.x + opaque.size.x * 0.5
	sprite.position.x += ground_x - opaque_mid_x
	sprite.position.y += ground_y - opaque_bottom
	sprite.position.y += _species_battler_y_nudge()


func _species_battler_y_nudge() -> float:
	if pokemon == null or pokemon.base_data == null or pokemon.base_data.base == null:
		return 0.0
	var data: PokemonData = pokemon.base_data.base
	var is_player := false
	if side != null:
		is_player = side.type == BattleSide.Types.PLAYER
	elif pokemon.side != null:
		is_player = pokemon.side.type == BattleSide.Types.PLAYER
	var nudge := float(data.battlerPlayerY if is_player else data.battlerEnemyY)
	# Altitude sube el sprite (vuelo / flotación).
	nudge -= float(data.battlerAltitude)
	return nudge


func _ready() -> void:
	index = 1 if name.contains("SpotA") else 2
	_refresh_ball_ground_anchor(0.0)
	set_process(false)

func load_active_pokemon(_pokemon: BattlePokemon, rules: BattleRules) -> void:
	self.pokemon = _pokemon
	self.pokemon.set_battle_spot(self)
	self.pokemon.in_battle = true

	# Asignar sprite
	if self.pokemon.side.type == BattleSide.Types.PLAYER:
		sprite.texture = self.pokemon.get_back_sprite()
	else:
		sprite.texture = self.pokemon.get_front_sprite()

	_align_sprite_to_ground()
	refresh_visual_anchors()

	if not pokemon.status_changed.is_connected(_on_status_changed):
		pokemon.status_changed.connect(_on_status_changed)
	# Mostrar sombra si es salvaje
	shadow.visible = self.pokemon.is_wild

	# Mostrar sprite
	sprite.visible = true

	# Inicializar y posicionar HPBar
	hp_bar.init(self.pokemon)
	hp_bar.setup_for(self.pokemon.side.type, rules.mode)
	hp_bar.set_status_icon(pokemon.status.icon if pokemon.status else null)
	position_hp_bar(rules.mode)
	ensure_hp_bar_display_z()
	hp_bar.visible = true

	# Mostrar el spot completo
	self.visible = true
	if _pokemon.ability and _pokemon.ability.effect_resource:
		var effect = _pokemon.ability.effect_resource.new(_pokemon.ability)
		BattleEffectController.add_pokemon_effect(_pokemon, effect)

	_register_persistent_ailment_effect_if_needed(_pokemon)

	active_pokemon_loaded.emit(_pokemon)


func get_active_pokemon() -> BattlePokemon:
	return pokemon

func set_pokemon_sprite_visible(is_visible: bool) -> void:
	if pokemon == null:
		return
	sprite.visible = is_visible
	shadow.visible = is_visible and pokemon.is_wild


## Registra Poison/Burn/etc. en el controlador de efectos al entrar en campo (estado ya cargado desde `Pokemon.major_status`).
## Sin esto solo existía `BattlePokemon.status` visualmente y el daño por veneno no corría en turnos.
func _register_persistent_ailment_effect_if_needed(bp: BattlePokemon) -> void:
	if bp == null or bp.status == null:
		return
	if not bp.status.is_persistent or bp.status.effect == null:
		return

	var inst: PersistentBattleEffect = bp.status.get_effect() as PersistentBattleEffect
	if inst == null:
		return
	if BattleEffectController.has_effect_for(bp, inst):
		return
	BattleEffectController.add_pokemon_effect(bp, inst)


func clear() -> void:
	stop_selection_bounce()
	sprite.texture = null
	sprite.position = Vector2.ZERO
	hide()

## Remueve el Pokémon debilitado del battlespot y limpia la UI
func remove_pokemon() -> void:
	stop_selection_bounce()
	if pokemon:
		pokemon.in_battle = false
		pokemon.battle_spot = null
	pokemon = null
	sprite.texture = null
	sprite.position = Vector2.ZERO
	sprite.visible = false
	shadow.visible = false
	if hp_bar:
		hp_bar.clear_ui()
		hp_bar.visible = false

func position_hp_bar(mode: int) -> void:
	match mode:
		BattleRules.BattleModes.SINGLE:
			hp_bar.global_position = hp_bar_pos_single.global_position
		BattleRules.BattleModes.DOUBLE:
			hp_bar.global_position = hp_bar_pos_double.global_position
		_:
			push_warning("Modo de batalla no soportado para posicionar HPBar")


## z absoluto por encima de balls (layer z=1) y sprites del spot; empata con MessageBox (6).
func ensure_hp_bar_display_z() -> void:
	if hp_bar == null:
		return
	hp_bar.z_as_relative = false
	hp_bar.z_index = FieldUI.HP_BAR_CANVAS_Z
	for child in hp_bar.get_children():
		if child is CanvasItem:
			var ci := child as CanvasItem
			ci.z_as_relative = false
			ci.z_index = FieldUI.HP_BAR_CANVAS_Z + 1


func highlight(active: bool) -> void:
	if tween:
		tween.kill()
		tween = null

	if active:
		tween = create_tween()
		tween.set_loops()
		tween.tween_property($Sprite, "modulate:a", 0.3, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property($Sprite, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		$Sprite.modulate.a = 1.0


## Pequeño bounce arriba/abajo del sprite y la HP bar mientras se elige acción o movimiento.
func start_selection_bounce() -> void:
	stop_selection_bounce()
	if sprite == null or not sprite.visible:
		return
	_selection_bounce_sprite_rest_y = sprite.position.y
	_selection_bounce_hp_active = hp_bar != null and hp_bar.visible
	if _selection_bounce_hp_active:
		_selection_bounce_hp_rest_y = hp_bar.global_position.y
	# Fase por tiempo real: movimiento continuo sin hitch al reiniciar el ciclo.
	_selection_bounce_elapsed = 0.0
	_selection_bounce_active = true
	set_process(true)


func stop_selection_bounce() -> void:
	_selection_bounce_active = false
	set_process(false)
	_selection_bounce_elapsed = 0.0
	if sprite != null and is_instance_valid(sprite):
		sprite.position.y = _selection_bounce_sprite_rest_y
	if _selection_bounce_hp_active and hp_bar != null and is_instance_valid(hp_bar):
		hp_bar.global_position.y = _selection_bounce_hp_rest_y
	_selection_bounce_hp_active = false


func _process(delta: float) -> void:
	if not _selection_bounce_active:
		return
	_selection_bounce_elapsed += delta
	var phase := fmod(_selection_bounce_elapsed / SELECTION_BOUNCE_CYCLE_SEC, 1.0)
	_update_selection_bounce(phase)


func _update_selection_bounce(t: float) -> void:
	# Seno completo continuo (misma posición y velocidad en t=0 y t=1).
	var offset := sin(t * TAU) * SELECTION_BOUNCE_OFFSET
	if sprite != null and is_instance_valid(sprite):
		sprite.position.y = _selection_bounce_sprite_rest_y - offset
	if _selection_bounce_hp_active and hp_bar != null and is_instance_valid(hp_bar):
		hp_bar.global_position.y = _selection_bounce_hp_rest_y + offset

func get_opponent_side() -> BattleSide:
	return side.opponent_side

func has_active_pokemon() -> bool:
	return pokemon != null and not pokemon.is_fainted()

func apply_damage(decrease_value = null) -> void:
	var active := get_active_pokemon()
	if active == null or hp_bar == null:
		return
	hp_bar.pokemon = active
	if decrease_value != null and decrease_value > 0:
		await hp_bar.reduce_hp_by(decrease_value)
	else:
		await hp_bar.update_hp(active.hp)

func apply_heal(increase_value = null) -> void:
	if get_active_pokemon() == null:
		return

	if hp_bar:
		if increase_value:
			await hp_bar.increase_hp_by(increase_value)
		else:
			await hp_bar.update_hp(get_active_pokemon().hp)

##	Verifica si hay un Pokémon controlable activo en un spot anterior del mismo equipo
func has_previous_controllable_pokemon() -> bool:
	# Si no tenemos índice o side, no podemos verificar
	if index <= 1 or side == null:
		return false

	# Buscar en los spots anteriores del mismo equipo
	for i in range(index - 1):
		var previous_spot = side.battle_spots[i]
		if previous_spot.has_active_pokemon():
			var previous_pokemon = previous_spot.get_active_pokemon()
			if previous_pokemon.controllable and not previous_pokemon.is_fainted():
				return true

	return false


func play_hit_animation() -> void:
	await BattleAnimationUtils.flash_spot(self)


## Alias para Hooks / Call Method (mismos defaults que el hit).
func flash(flashes: int = 2, step_duration: float = 0.1, end_pause: float = 0.5) -> void:
	await BattleAnimationUtils.flash_spot(self, flashes, step_duration, end_pause)


func shake(intensity: float = 4.0, duration: float = 0.25) -> void:
	await BattleAnimationUtils.shake_spot(self, intensity, duration)


func pulse_scale(peak_scale: float = 1.12, up_duration: float = 0.12, down_duration: float = 0.16) -> void:
	await BattleAnimationUtils.pulse_scale_spot(self, peak_scale, up_duration, down_duration)


func move_forward(distance: float = 16.0, duration: float = 0.12) -> void:
	await BattleAnimationUtils.move_spot_forward(self, distance, duration)


func nudge_down(distance: float = 10.0, duration: float = 0.1) -> void:
	await BattleAnimationUtils.nudge_spot_down(self, distance, duration)


## Aparición al enviar: scale + de-white. Awaitable.
func play_enter_animation(scale_duration: float = 0.45, white_duration: float = 0.75) -> void:
	await BattleAnimationUtils.pokemon_enter_spot(self, scale_duration, white_duration)


## Recall / salida del spot. Awaitable.
func play_exit_animation() -> void:
	await BattleAnimationUtils.pokemon_exit_spot(self)


func play_heal_animation() -> void:
	if not is_visible():
		return

	# Overlay verde que baja (como RPG Maker)
	await _play_overlay_animation(
		"res://Sprites/Batalla/Moves Animations/OverlayHeal.png",
		true,  # animate_up = false (baja)
		2.0     # duración
	)

func play_stat_up_animation() -> void:
	if not is_visible():
		return

	# Overlay rojo que sube
	await _play_overlay_animation(
		"res://Sprites/Batalla/Moves Animations/OverlayStatUp.png",
		true,   # animate_up = true (sube)
		2.0
	)

func play_stat_down_animation() -> void:
	if not is_visible():
		return

	# Overlay azul que baja
	await _play_overlay_animation(
		"res://Sprites/Batalla/Moves Animations/OverlayStatDown.png",
		false,  # animate_up = false (baja)
		2.0
	)

# Función genérica para animar overlays con shader
func _play_overlay_animation(overlay_path: String, animate_up: bool, duration: float) -> void:
	# Crear shader material temporal
	var shader = load("res://Shaders/Battle/overlay_animation.gdshader")
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader

	# Configurar parámetros del shader
	shader_material.set_shader_parameter("overlay_texture", load(overlay_path))
	shader_material.set_shader_parameter("animate_up", animate_up)
	shader_material.set_shader_parameter("progress", 0.0)
	shader_material.set_shader_parameter("overlay_alpha", 0.7)
	shader_material.set_shader_parameter("scroll_speed", 2)
	shader_material.set_shader_parameter("overlay_scale", 2.0)

	# Asignar material al sprite
	sprite.material = shader_material

	# Animar el parámetro progress con tween
	var overlay_tween := create_tween()
	overlay_tween.tween_method(
		func(value: float): shader_material.set_shader_parameter("progress", value),
		0.0,
		1.0,
		duration
	)

	await overlay_tween.finished

	# Limpiar material
	sprite.material = null
	await get_tree().create_timer(0.1).timeout

func play_faint_animation() -> void:
	if not is_visible():
		return

	# Guardar valores originales
	var original_position = sprite.position
	var original_region_enabled = sprite.region_enabled
	var original_region = sprite.region_rect

	# Obtener el tamaño del sprite
	var sprite_height = sprite.texture.get_height() if sprite.texture else 96

	# Activar región si no está activa
	if not sprite.region_enabled:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, sprite.texture.get_width(), sprite_height)

	var duration = 0.5

	# Crear tween para hundimiento
	var faint_tween := create_tween()
	faint_tween.set_parallel(false)

	# Animar posición Y y altura de región simultáneamente
	faint_tween.tween_method(
		func(progress: float):
			# Mover sprite hacia abajo
			sprite.position.y = original_position.y + (progress * 40)

			# Recortar región desde abajo hacia arriba
			var new_height = sprite_height * (1.0 - progress)
			sprite.region_rect = Rect2(
				sprite.region_rect.position.x,
				sprite.region_rect.position.y,
				sprite.region_rect.size.x,
				new_height
			),
		0.0,
		1.0,
		duration
	)

	await faint_tween.finished

	# Ocultar completamente el sprite
	sprite.visible = false

	# Ocultar la sombra si existe y es visible
	if shadow and shadow.visible:
		shadow.visible = false

	# Restaurar valores originales
	sprite.position = original_position
	sprite.region_enabled = original_region_enabled
	sprite.region_rect = original_region

	# Animar HP bar retirándose
	await play_hp_bar_slide_out()

func play_hp_bar_slide_out() -> void:
	if not hp_bar or not hp_bar.visible:
		return

	var direction := _hp_bar_slide_direction()
	var slide_distance := 300.0
	var original_hp_position := hp_bar.global_position

	var hp_tween := create_tween()
	hp_tween.set_ease(Tween.EASE_IN)
	hp_tween.set_trans(Tween.TRANS_CUBIC)
	hp_tween.tween_property(
		hp_bar,
		"global_position:x",
		original_hp_position.x + (direction * slide_distance),
		0.3
	)

	await hp_tween.finished

	hp_bar.visible = false
	hp_bar.global_position = original_hp_position


## Inverso del slide-out: entra desde fuera hacia la posición de reposo.
func play_hp_bar_slide_in(duration: float = 0.3) -> void:
	if not hp_bar:
		return
	ensure_hp_bar_display_z()
	var direction := _hp_bar_slide_direction()
	var slide_distance := 300.0
	var rest := hp_bar.global_position
	hp_bar.global_position = Vector2(rest.x + direction * slide_distance, rest.y)
	hp_bar.visible = true

	var hp_tween := create_tween()
	hp_tween.set_ease(Tween.EASE_OUT)
	hp_tween.set_trans(Tween.TRANS_CUBIC)
	hp_tween.tween_property(hp_bar, "global_position:x", rest.x, duration)
	await hp_tween.finished

	if is_instance_valid(hp_bar):
		hp_bar.global_position = rest


func _hp_bar_slide_direction() -> float:
	# Player: sale/entra por la derecha (+). Rival: por la izquierda (-).
	var side_type := BattleSide.Types.PLAYER
	if pokemon != null and pokemon.side != null:
		side_type = pokemon.side.type
	elif side != null:
		side_type = side.type
	return 1.0 if side_type == BattleSide.Types.PLAYER else -1.0


func _on_status_changed():
	var icon := pokemon.status.icon if pokemon.status else null
	hp_bar.set_status_icon(icon)
