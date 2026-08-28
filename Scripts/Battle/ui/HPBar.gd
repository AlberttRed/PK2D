extends Node2D
class_name HPBar

signal updated

var pokemon: BattlePokemon

@onready var lbl_name: RichTextLabel = $lblName
@onready var lbl_gender: RichTextLabel = $lblGender
@onready var lbl_level: RichTextLabel = $lblLevel
@onready var spr_level: Sprite2D = $lblNv
@onready var status_ui: Sprite2D = $Status
@onready var health_bar: AnimatedProgressBar = $health_bar
@onready var exp_bar: AnimatedProgressBar = $exp_bar

const SPRITE_PLAYER_SINGLE = preload("res://Sprites/Pictures/battlePlayerBoxS.png")
const SPRITE_PLAYER_DOUBLE = preload("res://Sprites/Pictures/battlePlayerBoxD.png")
const SPRITE_ENEMY_SINGLE  = preload("res://Sprites/Pictures/battleFoeBoxS.png")
const SPRITE_ENEMY_DOUBLE  = preload("res://Sprites/Pictures/battleFoeBoxD.png")
const _PokemonExperienceGroup := preload("res://Scripts/Runtime/PokemonExperienceGroup.gd")

func _ready() -> void:
	# Misma escena que la barra de PS: no aplicar verde/amarillo/rojo al % (es trozo de EXP, no HP).
	exp_bar.use_hp_color_tiers = false

func init(_pokemon: BattlePokemon) -> void:
	pokemon = _pokemon

	# Inicializar barras
	health_bar.set_values(pokemon.hp, pokemon.total_hp)
	var seg: Vector2i = pokemon.base_data.get_exp_bar_segment_values()
	exp_bar.set_values(seg.x, seg.y)

	# Inicializar UI general
	refresh_panel_labels()


## `level_display_override`: si no es null, fija el número de nivel en caja (p. ej. animación EXP: aún el nivel antiguo).
func refresh_panel_labels(level_display_override = null) -> void:
	lbl_name.setText(pokemon.get_name())
	if level_display_override != null:
		lbl_level.setText(str(level_display_override))
	else:
		lbl_level.setText(str(pokemon.get_level()))
	print(pokemon.get_name() +":" + str(pokemon.base_data.gender))
	match pokemon.base_data.gender:
		CONST.GENEROS.HEMBRA:
			lbl_gender.setText("♀")
			lbl_gender.set("theme_override_colors/default_color", Color("FF5D2C"))
		CONST.GENEROS.MACHO:
			lbl_gender.setText("♂")
			lbl_gender.set("theme_override_colors/default_color", Color("3465DF"))
		_:
			lbl_gender.text = ""

	update_status_ui()


## Alinea la barra de PS con `pokemon.hp` / `pokemon.total_hp` (p. ej. tras subir de nivel y `refresh_derived_stats_from_base`).
func sync_health_bar_from_pokemon() -> void:
	if pokemon == null:
		return
	health_bar.set_values(pokemon.hp, pokemon.total_hp)


func update_status_ui() -> void:
	# status está en BattlePokemon, no en Pokemon (base_data)
	if pokemon.status != null:
		status_ui.visible = true
		# pokemon.status es un AilmentData, necesitamos el ID
		status_ui.region_rect = Rect2(0, 16 * (pokemon.status.id - 1), 44, 16)
	else:
		status_ui.visible = false

func clear_ui() -> void:
	lbl_name.text = ""
	lbl_level.text = ""
	lbl_gender.text = ""
	status_ui.visible = false
	health_bar.clear()
	exp_bar.clear()

func update_hp(hp: int) -> void:
	await health_bar.animate_to(min(hp, health_bar.max_value))
	updated.emit()
	
func reduce_hp_by(hp: int) -> void:
	await health_bar.animate_to(max(health_bar.current_value - hp, 0))
	updated.emit()

func increase_hp_by(hp: int) -> void:
	await health_bar.animate_to(min(health_bar.current_value + hp, health_bar.max_value))
	updated.emit()

func update_exp(exp_value: int) -> void:
	pokemon.base_data.totalExp = exp_value
	var seg: Vector2i = pokemon.base_data.get_exp_bar_segment_values(exp_value)
	exp_bar.set_values(seg.x, seg.y)
	updated.emit()


## EXP final ya está aplicada en runtime. Si hay subida, `level_up_message_fn(battle_pokemon, nivel_alcanzado)` se invoca tras cada nivel; la barra ya está reiniciada para ese nivel (antes del trozo EXP restante).
func animate_exp_bar_gain(
	previous_total_exp: int,
	new_total_exp: int,
	level_before_gain: int,
	levels_gained: int,
	level_up_message_fn: Callable = Callable()
) -> void:
	var mon := pokemon.base_data
	var target_level: int = mon.level

	# Nv.100: barra vacía y sin animación de subida.
	if level_before_gain >= 100:
		var empty := mon.get_exp_bar_segment_values_for_level(new_total_exp, 100)
		exp_bar.set_values(empty.x, empty.y)
		updated.emit()
		return

	if levels_gained <= 0:
		var from_seg: Vector2i = mon.get_exp_bar_segment_values_for_level(previous_total_exp, level_before_gain)
		var to_seg: Vector2i = mon.get_exp_bar_segment_values_for_level(new_total_exp, level_before_gain)
		exp_bar.set_values(from_seg.x, from_seg.y)
		await exp_bar.animate_to(to_seg.x)
		updated.emit()
		return

	var grp := _PokemonExperienceGroup.new(mon.base.growth_rate_id)
	var L: int = level_before_gain
	var e: int = previous_total_exp

	while L < target_level:
		var need: int = grp.get_total_exp_for_level(L + 1)
		if new_total_exp < need:
			break
		if e < need:
			var from_seg2: Vector2i = mon.get_exp_bar_segment_values_for_level(e, L)
			var to_seg2: Vector2i = mon.get_exp_bar_segment_values_for_level(need, L)
			exp_bar.set_values(from_seg2.x, from_seg2.y)
			await exp_bar.animate_to(to_seg2.x)
			e = need
		var reached: int = L + 1
		lbl_level.setText(str(reached))
		if reached == target_level:
			sync_health_bar_from_pokemon()
		var start_new_lvl: Vector2i = mon.get_exp_bar_segment_values_for_level(e, reached)
		exp_bar.set_values(start_new_lvl.x, start_new_lvl.y)
		if level_up_message_fn.is_valid() and pokemon != null:
			await level_up_message_fn.call(pokemon, reached)
		L += 1

	if e < new_total_exp:
		var from_seg3: Vector2i = mon.get_exp_bar_segment_values_for_level(e, L)
		var to_seg3: Vector2i = mon.get_exp_bar_segment_values_for_level(new_total_exp, L)
		exp_bar.set_values(from_seg3.x, from_seg3.y)
		await exp_bar.animate_to(to_seg3.x)

	refresh_panel_labels()
	updated.emit()

func setup_for(side_type: int, mode: int) -> void:
	match [side_type, mode]:
		[BattleSide.Types.PLAYER, BattleRules.BattleModes.SINGLE]:
			_set_player_single_box()
		[BattleSide.Types.PLAYER, BattleRules.BattleModes.DOUBLE]:
			_set_player_double_box()
		[BattleSide.Types.ENEMY, BattleRules.BattleModes.SINGLE]:
			_set_enemy_single_box()
		[BattleSide.Types.ENEMY, BattleRules.BattleModes.DOUBLE]:
			_set_enemy_double_box()
			
			

#region Set Battle Boxes
func _set_player_single_box():
	self.texture = SPRITE_PLAYER_SINGLE
	lbl_name.visible = true
	lbl_name.position = Vector2(-90, -35)
	lbl_gender.visible = true
	lbl_gender.position = Vector2(33, -37)
	spr_level.visible = true
	spr_level.position = Vector2(57.5, -20.0)
	lbl_level.visible = true
	lbl_level.position = Vector2(70, -31)
	status_ui.visible = false
	status_ui.position = Vector2(-50, 1)
	health_bar.visible = true
	health_bar.set_value_visible(true)
	health_bar.position = Vector2(-26, -7)
	exp_bar.visible = true

func _set_player_double_box():
	self.texture = SPRITE_PLAYER_DOUBLE
	lbl_name.visible = true
	lbl_name.position = Vector2(-90, -25)
	lbl_gender.visible = true
	lbl_gender.position = Vector2(33, -25)
	spr_level.visible = true
	spr_level.position = Vector2(57.5, -8.0)
	lbl_level.visible = true
	lbl_level.position = Vector2(70, -19)
	status_ui.visible = false
	status_ui.position = Vector2(-50, 13)
	health_bar.visible = true
	health_bar.set_value_visible(false)
	health_bar.position = Vector2(-26, 5)
	exp_bar.visible = false
	
func _set_enemy_single_box():
	self.texture = SPRITE_ENEMY_SINGLE
	lbl_name.visible = true
	lbl_name.position = Vector2(-105, -24)
	lbl_gender.visible = true
	lbl_gender.position = Vector2(16, -28)
	spr_level.visible = true
	spr_level.position = Vector2(40.5, -9.0)
	lbl_level.visible = true
	lbl_level.position = Vector2(45, -20)
	status_ui.visible = false
	status_ui.position = Vector2(-68, 13)
	health_bar.visible = true
	health_bar.set_value_visible(false)
	health_bar.position = Vector2(-44, 5)
	exp_bar.visible = false
	
func _set_enemy_double_box():
	self.texture = SPRITE_ENEMY_DOUBLE
	lbl_name.visible = true
	lbl_name.position = Vector2(-108, -25)
	lbl_gender.visible = true
	lbl_gender.position = Vector2(15, -25)
	spr_level.visible = true
	spr_level.position = Vector2(39.5, -8.0)
	lbl_level.visible = true
	lbl_level.position = Vector2(52, -19)
	status_ui.visible = false
	status_ui.position = Vector2(-68, 13)
	health_bar.visible = true
	health_bar.set_value_visible(false)
	health_bar.position = Vector2(-44, 5)
	exp_bar.visible = false
#endregion

func set_status_icon(texture: Texture2D):
	$Status.texture = texture
	$Status.visible = texture != null
