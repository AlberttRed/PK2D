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

func init(_pokemon: BattlePokemon) -> void:
	pokemon = _pokemon

	# Inicializar barras
	health_bar.set_values(pokemon.hp, pokemon.total_hp)
	exp_bar.set_values(pokemon.base_data.totalExp, pokemon.base_data.nextLevelExpBase)

	# Inicializar UI general
	update_ui()

func update_ui() -> void:
	lbl_name.setText(pokemon.get_name())
	lbl_level.setText(pokemon.get_level())
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

func update_status_ui() -> void:
	if pokemon.base_data.status != CONST.STATUS.OK:
		status_ui.visible = true
		status_ui.region_rect = Rect2(0, 16 * (pokemon.base_data.status - 1), 44, 16)
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
	await health_bar.animate_to(hp)
	updated.emit()
	
func reduce_hp_by(hp: int) -> void:
	await health_bar.animate_to(health_bar.current_value - hp)
	updated.emit()

func update_exp(exp: int) -> void:
	await exp_bar.animate_to(exp)
	pokemon.base_data.totalExp = exp
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
