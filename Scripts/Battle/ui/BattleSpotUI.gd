extends Node2D
class_name BattleSpot

var pokemon: BattlePokemon = null
var side: BattleSide
var tween: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow

@onready var hp_bar: HPBar = $HPBar
@onready var hp_bar_pos_single: Marker2D = $Positions/HPBarPos_Single
@onready var hp_bar_pos_double: Marker2D = $Positions/HPBarPos_Double
	
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
		var effect = pokemon.ability.effect_resource.new(_pokemon.ability)
		BattleEffectController.add_pokemon_effect(_pokemon, effect)

func get_active_pokemon() -> BattlePokemon:
	return pokemon
	
func clear() -> void:
	sprite.texture = null
	hide()

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

func play_hit_animation() -> void:
	if not is_visible():
		return

	var tween := create_tween()
	tween.set_parallel(false) # animación secuencial (no solapada)

	# Parpadeo: transparente → visible (2 veces)
	for i in 2:
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1.0), 0.1)

	await tween.finished
	await get_tree().create_timer(0.5).timeout

func play_enter_animation():
	# Simple animación de entrada, si querés algo visual
	# Podés conectarlo luego con AnimationPlayer o con tween
	pass

func _on_status_changed():
	var icon := pokemon.status.icon if pokemon.status else null
	hp_bar.set_status_icon(icon)
