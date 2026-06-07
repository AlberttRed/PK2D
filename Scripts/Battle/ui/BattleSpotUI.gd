extends Node2D
class_name BattleSpot

## Se emite al asignar un Pokémon al terreno (`load_active_pokemon`). Escucha `BattleController` (u otro orquestador), no lógica de EXP aquí.
signal active_pokemon_loaded(pokemon: BattlePokemon)

var index = null
var pokemon: BattlePokemon = null
var side: BattleSide
var tween: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

@onready var hp_bar: HPBar = $HPBar
@onready var hp_bar_pos_single: Marker2D = $Positions/HPBarPos_Single
@onready var hp_bar_pos_double: Marker2D = $Positions/HPBarPos_Double

func _ready() -> void:
	index = 1 if name.contains("SpotA") else 2

func load_active_pokemon(_pokemon: BattlePokemon, rules: BattleRules) -> void:
	self.pokemon = _pokemon
	self.pokemon.set_battle_spot(self)
	self.pokemon.in_battle = true

	# Asignar sprite
	if self.pokemon.side.type == BattleSide.Types.PLAYER:
		sprite.texture = self.pokemon.get_back_sprite()
	else:
		sprite.texture = self.pokemon.get_front_sprite()

	# Posicionar sprite si hiciera falta (ya tenías set_sprite_position)
	#set_sprite_position()
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
	sprite.texture = null
	hide()

##	Remueve el Pokémon debilitado del battlespot y limpia la UI
func remove_pokemon() -> void:
	if pokemon:
		pokemon.in_battle = false
		pokemon.battle_spot = null
	pokemon = null
	sprite.visible = false
	shadow.visible = false
	hp_bar.visible = false

func position_hp_bar(mode: int) -> void:
	match mode:
		BattleRules.BattleModes.SINGLE:
			hp_bar.global_position = hp_bar_pos_single.global_position
		BattleRules.BattleModes.DOUBLE:
			hp_bar.global_position = hp_bar_pos_double.global_position
		_:
			push_warning("Modo de batalla no soportado para posicionar HPBar")

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

func get_opponent_side() -> BattleSide:
	return side.opponent_side

func has_active_pokemon() -> bool:
	return pokemon != null and not pokemon.is_fainted()

func apply_damage(decrease_value = null) -> void:
	if get_active_pokemon() == null:
		return

	if hp_bar:
		if decrease_value:
			await hp_bar.reduce_hp_by(decrease_value)
		else:
			await hp_bar.update_hp(get_active_pokemon().hp)

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
	if not is_visible():
		return

	var hit_tween := create_tween()
	hit_tween.set_parallel(false) # animación secuencial (no solapada)

	# Parpadeo: transparente → visible (2 veces)
	for i in 2:
		hit_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), 0.1)
		hit_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1.0), 0.1)

	await hit_tween.finished
	await get_tree().create_timer(0.5).timeout

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

	# Determinar dirección según el tipo de lado
	var is_player = pokemon.side.type == BattleSide.Types.PLAYER
	var slide_distance = 300  # Píxeles a desplazar
	var direction = 1 if is_player else -1  # Derecha (+) para player, izquierda (-) para enemy

	# Guardar posición original
	var original_hp_position = hp_bar.global_position

	# Crear tween para deslizar el HP bar
	var hp_tween := create_tween()
	hp_tween.set_ease(Tween.EASE_IN)
	hp_tween.set_trans(Tween.TRANS_CUBIC)

	# Deslizar hacia la dirección correspondiente
	hp_tween.tween_property(
		hp_bar,
		"global_position:x",
		original_hp_position.x + (direction * slide_distance),
		0.3
	)

	await hp_tween.finished

	# Ocultar HP bar
	hp_bar.visible = false

	# Restaurar posición (para futuras batallas)
	hp_bar.global_position = original_hp_position

func play_enter_animation():
	# Simple animación de entrada, si querés algo visual
	# Podés conectarlo luego con AnimationPlayer o con tween
	pass

func _on_status_changed():
	var icon := pokemon.status.icon if pokemon.status else null
	hp_bar.set_status_icon(icon)
