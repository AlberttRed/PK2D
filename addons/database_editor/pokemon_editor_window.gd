@tool
extends Window

## Ventana de edición de PokemonData
## Soporta modos: Edit, Create, Duplicate

enum EditorMode {
	EDIT,      # Editar un PokemonData existente
	CREATE,    # Crear un nuevo PokemonData
	DUPLICATE  # Duplicar un PokemonData existente
}

signal saved(pokemon_data: PokemonData, was_new: bool)
signal cancelled()

var current_pokemon_data: PokemonData = null
var editor_mode: EditorMode = EditorMode.EDIT
var original_resource_path: String = ""
var has_unsaved_changes: bool = false
var refresh_callback: Callable = Callable()

# Cache de tipos disponibles
var available_types: Array[TypeData] = []
var types_loaded: bool = false

# Referencias UI - TabContainer
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer

# Referencias UI - General
@onready var id_spin_box: SpinBox = $VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/IdContainer/IdSpinBox
@onready var internal_name_line_edit: LineEdit = $VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/InternalNameContainer/InternalNameLineEdit
@onready var display_name_line_edit: LineEdit = $VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var description_text_edit: TextEdit = $VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/DescriptionContainer/DescriptionTextEdit

# Referencias UI - Tipos
@onready var type_a_option_button: OptionButton = $VBoxContainer/TabContainer/General/VBoxContainer/TypesSection/TypeAContainer/TypeAOptionButton
@onready var type_b_option_button: OptionButton = $VBoxContainer/TabContainer/General/VBoxContainer/TypesSection/TypeBContainer/TypeBOptionButton

# Referencias UI - Base Stats
@onready var hp_base_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/HpBaseContainer/HpBaseSpinBox
@onready var attack_base_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/AttackBaseContainer/AttackBaseSpinBox
@onready var defense_base_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/DefenseBaseContainer/DefenseBaseSpinBox
@onready var special_attack_base_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/SpecialAttackBaseContainer/SpecialAttackBaseSpinBox
@onready var special_defense_base_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/SpecialDefenseBaseContainer/SpecialDefenseBaseSpinBox
@onready var speed_base_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/SpeedBaseContainer/SpeedBaseSpinBox
@onready var total_base_label_value: Label = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/TotalBaseContainer/TotalBaseLabelValue
@onready var evs_section: VBoxContainer = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection

# Referencias UI - EVs
@onready var hp_effort_evs_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/HpEffortEVsContainer/HpEffortEVsSpinBox
@onready var attack_effort_evs_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/AttackEffortEVsContainer/AttackEffortEVsSpinBox
@onready var defense_effort_evs_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/DefenseEffortEVsContainer/DefenseEffortEVsSpinBox
@onready var special_effort_attack_evs_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/SpecialEffortAttackEVsContainer/SpecialEffortAttackEVsSpinBox
@onready var special_effort_defense_evs_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/SpecialEffortDefenseEVsContainer/SpecialEffortDefenseEVsSpinBox
@onready var speed_effort_evs_spin_box: SpinBox = $VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/SpeedEffortEVsContainer/SpeedEffortEVsSpinBox

# Referencias UI - Physical Info
@onready var height_spin_box: SpinBox = $VBoxContainer/TabContainer/General/VBoxContainer/PhysicalInfoSection/HeightContainer/HeightSpinBox
@onready var weight_spin_box: SpinBox = $VBoxContainer/TabContainer/General/VBoxContainer/PhysicalInfoSection/WeightContainer/WeightSpinBox
@onready var base_experience_spin_box: SpinBox = $VBoxContainer/TabContainer/General/VBoxContainer/PhysicalInfoSection/BaseExperienceContainer/BaseExperienceSpinBox

# Referencias UI - Other Info
@onready var gender_rate_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/GenderRateContainer/GenderRateSpinBox
@onready var capture_rate_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/CaptureRateContainer/CaptureRateSpinBox
@onready var base_happiness_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/BaseHappinessContainer/BaseHappinessSpinBox
@onready var hatch_counter_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/HatchCounterContainer/HatchCounterSpinBox
@onready var growth_rate_id_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/GrowthRateIdContainer/GrowthRateIdSpinBox
@onready var egg_group_a_id_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/EggGroupAIdContainer/EggGroupAIdSpinBox
@onready var egg_group_b_id_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/EggGroupBIdContainer/EggGroupBIdSpinBox
@onready var habitat_id_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/HabitatIdContainer/HabitatIdSpinBox

# Referencias UI - Flags
@onready var is_default_check_box: CheckBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/IsDefaultContainer/IsDefaultCheckBox
@onready var is_baby_check_box: CheckBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/IsBabyContainer/IsBabyCheckBox
@onready var has_gender_differences_check_box: CheckBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/HasGenderDifferencesContainer/HasGenderDifferencesCheckBox
@onready var forms_switchable_check_box: CheckBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/FormsSwitchableContainer/FormsSwitchableCheckBox

# Referencias UI - Battle Positions
@onready var battler_player_y_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/BattlePositionsSection/BattlerPlayerYContainer/BattlerPlayerYSpinBox
@onready var battler_enemy_y_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/BattlePositionsSection/BattlerEnemyYContainer/BattlerEnemyYSpinBox
@onready var battler_altitude_spin_box: SpinBox = $VBoxContainer/TabContainer/Otros/VBoxContainer/BattlePositionsSection/BattlerAltitudeContainer/BattlerAltitudeSpinBox

# Referencias UI - Sprites
@onready var icon_sprite_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/IconSpriteContainer/IconSpriteButton
@onready var icon_sprite_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/IconSpriteContainer/IconSpritePreview
@onready var footprint_sprite_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/FootprintSpriteContainer/FootprintSpriteButton
@onready var footprint_sprite_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/FootprintSpriteContainer/FootprintSpritePreview
@onready var battle_front_sprite_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontSpriteContainer/BattleFrontSpriteButton
@onready var battle_front_sprite_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontSpriteContainer/BattleFrontSpritePreview
@onready var battle_back_sprite_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackSpriteContainer/BattleBackSpriteButton
@onready var battle_back_sprite_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackSpriteContainer/BattleBackSpritePreview
@onready var battle_front_shiny_sprite_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontShinySpriteContainer/BattleFrontShinySpriteButton
@onready var battle_front_shiny_sprite_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontShinySpriteContainer/BattleFrontShinySpritePreview
@onready var battle_back_shiny_sprite_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackShinySpriteContainer/BattleBackShinySpriteButton
@onready var battle_back_shiny_sprite_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackShinySpriteContainer/BattleBackShinySpritePreview
@onready var overworld_spritesheet_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldSpritesheetContainer/OverworldSpritesheetButton
@onready var overworld_spritesheet_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldSpritesheetContainer/OverworldSpritesheetPreview
@onready var overworld_shiny_spritesheet_button: Button = $VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldShinySpritesheetContainer/OverworldShinySpritesheetButton
@onready var overworld_shiny_spritesheet_preview: TextureButton = $VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldShinySpritesheetContainer/OverworldShinySpritesheetPreview

# Referencias UI - Buttons
@onready var save_button: Button = $VBoxContainer/ButtonContainer/SaveButton
@onready var cancel_button: Button = $VBoxContainer/ButtonContainer/CancelButton

func _ready() -> void:
	title = "Pokémon Editor"
	unresizable = false
	always_on_top = false
	exclusive = true  # Hace que la ventana sea modal
	min_size = Vector2i(900, 800)

	# Configurar nombres de pestañas
	if tab_container:
		tab_container.set_tab_title(0, "General")
		tab_container.set_tab_title(1, "Base Stats")
		tab_container.set_tab_title(2, "Otros")
		tab_container.set_tab_title(3, "Sprites")

	# En editor de especie solo mostramos stats base para evitar confusión con EVs de instancia.
	if evs_section:
		evs_section.visible = false

	# Conectar señal de cierre
	close_requested.connect(_on_close_requested)

	# Conectar botones
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)

	# Conectar botones de sprites
	_connect_sprite_buttons()

	# Cargar tipos disponibles
	_load_types()

	# Conectar cambios en campos para detectar modificaciones
	_connect_field_signals()

## Inicializa los nodos @onready si no se han inicializado automáticamente
func _initialize_nodes() -> void:
	if not id_spin_box:
		id_spin_box = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/IdContainer/IdSpinBox") as SpinBox
	if not internal_name_line_edit:
		internal_name_line_edit = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/InternalNameContainer/InternalNameLineEdit") as LineEdit
	if not display_name_line_edit:
		display_name_line_edit = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/DisplayNameContainer/DisplayNameLineEdit") as LineEdit
	if not description_text_edit:
		description_text_edit = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/DescriptionContainer/DescriptionTextEdit") as TextEdit
	if not type_a_option_button:
		type_a_option_button = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/TypesSection/TypeAContainer/TypeAOptionButton") as OptionButton
	if not type_b_option_button:
		type_b_option_button = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/TypesSection/TypeBContainer/TypeBOptionButton") as OptionButton
	if not hp_base_spin_box:
		hp_base_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/HpBaseContainer/HpBaseSpinBox") as SpinBox
	if not attack_base_spin_box:
		attack_base_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/AttackBaseContainer/AttackBaseSpinBox") as SpinBox
	if not defense_base_spin_box:
		defense_base_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/DefenseBaseContainer/DefenseBaseSpinBox") as SpinBox
	if not special_attack_base_spin_box:
		special_attack_base_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/SpecialAttackBaseContainer/SpecialAttackBaseSpinBox") as SpinBox
	if not special_defense_base_spin_box:
		special_defense_base_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/SpecialDefenseBaseContainer/SpecialDefenseBaseSpinBox") as SpinBox
	if not speed_base_spin_box:
		speed_base_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/SpeedBaseContainer/SpeedBaseSpinBox") as SpinBox
	if not total_base_label_value:
		total_base_label_value = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/BaseStatsSection/TotalBaseContainer/TotalBaseLabelValue") as Label
	if not hp_effort_evs_spin_box:
		hp_effort_evs_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/HpEffortEVsContainer/HpEffortEVsSpinBox") as SpinBox
	if not attack_effort_evs_spin_box:
		attack_effort_evs_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/AttackEffortEVsContainer/AttackEffortEVsSpinBox") as SpinBox
	if not defense_effort_evs_spin_box:
		defense_effort_evs_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/DefenseEffortEVsContainer/DefenseEffortEVsSpinBox") as SpinBox
	if not special_effort_attack_evs_spin_box:
		special_effort_attack_evs_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/SpecialEffortAttackEVsContainer/SpecialEffortAttackEVsSpinBox") as SpinBox
	if not special_effort_defense_evs_spin_box:
		special_effort_defense_evs_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/SpecialEffortDefenseEVsContainer/SpecialEffortDefenseEVsSpinBox") as SpinBox
	if not speed_effort_evs_spin_box:
		speed_effort_evs_spin_box = get_node_or_null("VBoxContainer/TabContainer/BaseStatsEVs/VBoxContainer/EVsSection/SpeedEffortEVsContainer/SpeedEffortEVsSpinBox") as SpinBox
	if not height_spin_box:
		height_spin_box = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/PhysicalInfoSection/HeightContainer/HeightSpinBox") as SpinBox
	if not weight_spin_box:
		weight_spin_box = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/PhysicalInfoSection/WeightContainer/WeightSpinBox") as SpinBox
	if not base_experience_spin_box:
		base_experience_spin_box = get_node_or_null("VBoxContainer/TabContainer/General/VBoxContainer/PhysicalInfoSection/BaseExperienceContainer/BaseExperienceSpinBox") as SpinBox
	if not gender_rate_spin_box:
		gender_rate_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/GenderRateContainer/GenderRateSpinBox") as SpinBox
	if not capture_rate_spin_box:
		capture_rate_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/CaptureRateContainer/CaptureRateSpinBox") as SpinBox
	if not base_happiness_spin_box:
		base_happiness_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/BaseHappinessContainer/BaseHappinessSpinBox") as SpinBox
	if not hatch_counter_spin_box:
		hatch_counter_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/HatchCounterContainer/HatchCounterSpinBox") as SpinBox
	if not growth_rate_id_spin_box:
		growth_rate_id_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/GrowthRateIdContainer/GrowthRateIdSpinBox") as SpinBox
	if not egg_group_a_id_spin_box:
		egg_group_a_id_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/EggGroupAIdContainer/EggGroupAIdSpinBox") as SpinBox
	if not egg_group_b_id_spin_box:
		egg_group_b_id_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/EggGroupBIdContainer/EggGroupBIdSpinBox") as SpinBox
	if not habitat_id_spin_box:
		habitat_id_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/OtherInfoSection/HabitatIdContainer/HabitatIdSpinBox") as SpinBox
	if not is_default_check_box:
		is_default_check_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/IsDefaultContainer/IsDefaultCheckBox") as CheckBox
	if not is_baby_check_box:
		is_baby_check_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/IsBabyContainer/IsBabyCheckBox") as CheckBox
	if not has_gender_differences_check_box:
		has_gender_differences_check_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/HasGenderDifferencesContainer/HasGenderDifferencesCheckBox") as CheckBox
	if not forms_switchable_check_box:
		forms_switchable_check_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/FlagsSection/FormsSwitchableContainer/FormsSwitchableCheckBox") as CheckBox
	if not battler_player_y_spin_box:
		battler_player_y_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/BattlePositionsSection/BattlerPlayerYContainer/BattlerPlayerYSpinBox") as SpinBox
	if not battler_enemy_y_spin_box:
		battler_enemy_y_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/BattlePositionsSection/BattlerEnemyYContainer/BattlerEnemyYSpinBox") as SpinBox
	if not battler_altitude_spin_box:
		battler_altitude_spin_box = get_node_or_null("VBoxContainer/TabContainer/Otros/VBoxContainer/BattlePositionsSection/BattlerAltitudeContainer/BattlerAltitudeSpinBox") as SpinBox
	if not save_button:
		save_button = get_node_or_null("VBoxContainer/ButtonContainer/SaveButton") as Button
		if save_button:
			if save_button.pressed.is_connected(_on_save_button_pressed):
				save_button.pressed.disconnect(_on_save_button_pressed)
			save_button.pressed.connect(_on_save_button_pressed)
			print("[PokemonEditorWindow] Botón Guardar conectado en _initialize_nodes")
	if not cancel_button:
		cancel_button = get_node_or_null("VBoxContainer/ButtonContainer/CancelButton") as Button
		if cancel_button:
			if cancel_button.pressed.is_connected(_on_cancel_button_pressed):
				cancel_button.pressed.disconnect(_on_cancel_button_pressed)
			cancel_button.pressed.connect(_on_cancel_button_pressed)
			print("[PokemonEditorWindow] Botón Cancelar conectado en _initialize_nodes")
		else:
			print("[PokemonEditorWindow] ERROR: No se encontró el botón Cancelar")
	if not icon_sprite_preview:
		icon_sprite_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/IconSpriteContainer/IconSpritePreview") as TextureButton
	if not footprint_sprite_preview:
		footprint_sprite_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/FootprintSpriteContainer/FootprintSpritePreview") as TextureButton
	if not battle_front_sprite_preview:
		battle_front_sprite_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontSpriteContainer/BattleFrontSpritePreview") as TextureButton
	if not battle_back_sprite_preview:
		battle_back_sprite_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackSpriteContainer/BattleBackSpritePreview") as TextureButton
	if not battle_front_shiny_sprite_preview:
		battle_front_shiny_sprite_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontShinySpriteContainer/BattleFrontShinySpritePreview") as TextureButton
	if not battle_back_shiny_sprite_preview:
		battle_back_shiny_sprite_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackShinySpriteContainer/BattleBackShinySpritePreview") as TextureButton
	if not overworld_spritesheet_preview:
		overworld_spritesheet_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldSpritesheetContainer/OverworldSpritesheetPreview") as TextureButton
	if not overworld_shiny_spritesheet_preview:
		overworld_shiny_spritesheet_preview = get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldShinySpritesheetContainer/OverworldShinySpritesheetPreview") as TextureButton

## Carga los tipos disponibles desde Resources/Data/Types
func _load_types() -> void:
	if types_loaded:
		return

	available_types.clear()
	var types_dir := "res://Resources/Data/Types"

	# Cargar tipos del 01 al 18
	for i in range(1, 19):
		var path := "%s/%02d.tres" % [types_dir, i]
		if ResourceLoader.exists(path):
			var type_data := load(path) as TypeData
			if type_data:
				available_types.append(type_data)

	# Ordenar por ID
	available_types.sort_custom(func(a: TypeData, b: TypeData) -> bool:
		return a.id < b.id
	)

	# Poblar OptionButtons
	if type_a_option_button:
		type_a_option_button.clear()
		type_a_option_button.add_item("(Ninguno)", 0)
		for type_data in available_types:
			var display_name: String = type_data.Name if type_data.Name else type_data.internal_name
			type_a_option_button.add_item(display_name, type_data.id)

	if type_b_option_button:
		type_b_option_button.clear()
		type_b_option_button.add_item("(Ninguno)", 0)
		for type_data in available_types:
			var display_name: String = type_data.Name if type_data.Name else type_data.internal_name
			type_b_option_button.add_item(display_name, type_data.id)

	types_loaded = true

## Conecta las señales de todos los campos para detectar cambios
func _connect_field_signals() -> void:
	# General
	if id_spin_box:
		id_spin_box.value_changed.connect(_on_field_changed)
	if internal_name_line_edit:
		internal_name_line_edit.text_changed.connect(_on_field_changed)
	if display_name_line_edit:
		display_name_line_edit.text_changed.connect(_on_field_changed)
	if description_text_edit:
		description_text_edit.text_changed.connect(_on_field_changed)

	# Tipos
	if type_a_option_button:
		type_a_option_button.item_selected.connect(_on_field_changed)
	if type_b_option_button:
		type_b_option_button.item_selected.connect(_on_field_changed)

	# Base Stats
	if hp_base_spin_box:
		hp_base_spin_box.value_changed.connect(_on_base_stat_changed)
	if attack_base_spin_box:
		attack_base_spin_box.value_changed.connect(_on_base_stat_changed)
	if defense_base_spin_box:
		defense_base_spin_box.value_changed.connect(_on_base_stat_changed)
	if special_attack_base_spin_box:
		special_attack_base_spin_box.value_changed.connect(_on_base_stat_changed)
	if special_defense_base_spin_box:
		special_defense_base_spin_box.value_changed.connect(_on_base_stat_changed)
	if speed_base_spin_box:
		speed_base_spin_box.value_changed.connect(_on_base_stat_changed)

	# EVs
	if hp_effort_evs_spin_box:
		hp_effort_evs_spin_box.value_changed.connect(_on_field_changed)
	if attack_effort_evs_spin_box:
		attack_effort_evs_spin_box.value_changed.connect(_on_field_changed)
	if defense_effort_evs_spin_box:
		defense_effort_evs_spin_box.value_changed.connect(_on_field_changed)
	if special_effort_attack_evs_spin_box:
		special_effort_attack_evs_spin_box.value_changed.connect(_on_field_changed)
	if special_effort_defense_evs_spin_box:
		special_effort_defense_evs_spin_box.value_changed.connect(_on_field_changed)
	if speed_effort_evs_spin_box:
		speed_effort_evs_spin_box.value_changed.connect(_on_field_changed)

	# Physical Info
	if height_spin_box:
		height_spin_box.value_changed.connect(_on_field_changed)
	if weight_spin_box:
		weight_spin_box.value_changed.connect(_on_field_changed)
	if base_experience_spin_box:
		base_experience_spin_box.value_changed.connect(_on_field_changed)

	# Other Info
	if gender_rate_spin_box:
		gender_rate_spin_box.value_changed.connect(_on_field_changed)
	if capture_rate_spin_box:
		capture_rate_spin_box.value_changed.connect(_on_field_changed)
	if base_happiness_spin_box:
		base_happiness_spin_box.value_changed.connect(_on_field_changed)
	if hatch_counter_spin_box:
		hatch_counter_spin_box.value_changed.connect(_on_field_changed)
	if growth_rate_id_spin_box:
		growth_rate_id_spin_box.value_changed.connect(_on_field_changed)
	if egg_group_a_id_spin_box:
		egg_group_a_id_spin_box.value_changed.connect(_on_field_changed)
	if egg_group_b_id_spin_box:
		egg_group_b_id_spin_box.value_changed.connect(_on_field_changed)
	if habitat_id_spin_box:
		habitat_id_spin_box.value_changed.connect(_on_field_changed)

	# Flags
	if is_default_check_box:
		is_default_check_box.toggled.connect(_on_field_changed)
	if is_baby_check_box:
		is_baby_check_box.toggled.connect(_on_field_changed)
	if has_gender_differences_check_box:
		has_gender_differences_check_box.toggled.connect(_on_field_changed)
	if forms_switchable_check_box:
		forms_switchable_check_box.toggled.connect(_on_field_changed)

	# Battle Positions
	if battler_player_y_spin_box:
		battler_player_y_spin_box.value_changed.connect(_on_field_changed)
	if battler_enemy_y_spin_box:
		battler_enemy_y_spin_box.value_changed.connect(_on_field_changed)
	if battler_altitude_spin_box:
		battler_altitude_spin_box.value_changed.connect(_on_field_changed)

## Conecta los botones de sprites
func _connect_sprite_buttons() -> void:
	# Conectar TextureButton (preview clickeable) para abrir el explorador
	if icon_sprite_preview:
		icon_sprite_preview.pressed.connect(func(): _select_sprite("icon_sprite", icon_sprite_button))
	if footprint_sprite_preview:
		footprint_sprite_preview.pressed.connect(func(): _select_sprite("footprint_sprite", footprint_sprite_button))
	if battle_front_sprite_preview:
		battle_front_sprite_preview.pressed.connect(func(): _select_sprite("battle_front_sprite", battle_front_sprite_button))
	if battle_back_sprite_preview:
		battle_back_sprite_preview.pressed.connect(func(): _select_sprite("battle_back_sprite", battle_back_sprite_button))
	if battle_front_shiny_sprite_preview:
		battle_front_shiny_sprite_preview.pressed.connect(func(): _select_sprite("battle_front_shiny_sprite", battle_front_shiny_sprite_button))
	if battle_back_shiny_sprite_preview:
		battle_back_shiny_sprite_preview.pressed.connect(func(): _select_sprite("battle_back_shiny_sprite", battle_back_shiny_sprite_button))
	if overworld_spritesheet_preview:
		overworld_spritesheet_preview.pressed.connect(func(): _select_sprite("overworld_spritesheet", overworld_spritesheet_button))
	if overworld_shiny_spritesheet_preview:
		overworld_shiny_spritesheet_preview.pressed.connect(func(): _select_sprite("overworld_shiny_spritesheet", overworld_shiny_spritesheet_button))

	# Conectar botones "Limpiar" para eliminar el sprite
	if icon_sprite_button:
		icon_sprite_button.pressed.connect(func(): _clear_sprite("icon_sprite", icon_sprite_button))
	if footprint_sprite_button:
		footprint_sprite_button.pressed.connect(func(): _clear_sprite("footprint_sprite", footprint_sprite_button))
	if battle_front_sprite_button:
		battle_front_sprite_button.pressed.connect(func(): _clear_sprite("battle_front_sprite", battle_front_sprite_button))
	if battle_back_sprite_button:
		battle_back_sprite_button.pressed.connect(func(): _clear_sprite("battle_back_sprite", battle_back_sprite_button))
	if battle_front_shiny_sprite_button:
		battle_front_shiny_sprite_button.pressed.connect(func(): _clear_sprite("battle_front_shiny_sprite", battle_front_shiny_sprite_button))
	if battle_back_shiny_sprite_button:
		battle_back_shiny_sprite_button.pressed.connect(func(): _clear_sprite("battle_back_shiny_sprite", battle_back_shiny_sprite_button))
	if overworld_spritesheet_button:
		overworld_spritesheet_button.pressed.connect(func(): _clear_sprite("overworld_spritesheet", overworld_spritesheet_button))
	if overworld_shiny_spritesheet_button:
		overworld_shiny_spritesheet_button.pressed.connect(func(): _clear_sprite("overworld_shiny_spritesheet", overworld_shiny_spritesheet_button))

## Abre un diálogo para seleccionar un AtlasTexture
func _select_sprite(property_name: String, button: Button) -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	# Solo mostrar archivos de imagen
	file_dialog.add_filter("*.png", "PNG Images")
	file_dialog.add_filter("*.jpg", "JPG Images")
	file_dialog.add_filter("*.jpeg", "JPEG Images")
	file_dialog.add_filter("*.webp", "WebP Images")
	file_dialog.add_filter("*.bmp", "BMP Images")
	file_dialog.add_filter("*.tga", "TGA Images")
	file_dialog.title = "Seleccionar Imagen"
	file_dialog.current_dir = "res://"

	var selected_resource: AtlasTexture = null
	if current_pokemon_data:
		match property_name:
			"icon_sprite":
				selected_resource = current_pokemon_data.icon_sprite
			"footprint_sprite":
				selected_resource = current_pokemon_data.footprint_sprite
			"battle_front_sprite":
				selected_resource = current_pokemon_data.battle_front_sprite
			"battle_back_sprite":
				selected_resource = current_pokemon_data.battle_back_sprite
			"battle_front_shiny_sprite":
				selected_resource = current_pokemon_data.battle_front_shiny_sprite
			"battle_back_shiny_sprite":
				selected_resource = current_pokemon_data.battle_back_shiny_sprite
			"overworld_spritesheet":
				selected_resource = current_pokemon_data.overworld_spritesheet
			"overworld_shiny_spritesheet":
				selected_resource = current_pokemon_data.overworld_shiny_spritesheet

	# Si hay un sprite seleccionado y tiene un atlas, intentar abrir en el directorio del atlas
	if selected_resource and selected_resource.atlas:
		var atlas_path: String = selected_resource.atlas.resource_path
		if atlas_path != "":
			var atlas_dir := atlas_path.get_base_dir()
			file_dialog.current_dir = atlas_dir

	file_dialog.file_selected.connect(func(path: String):
		var resource = load(path)
		if resource is Texture2D:
			# Si es una textura, crear un AtlasTexture básico que use toda la imagen
			var atlas_tex := AtlasTexture.new()
			atlas_tex.atlas = resource
			atlas_tex.region = Rect2i(0, 0, resource.get_width(), resource.get_height())
			_set_sprite_property(property_name, atlas_tex, button)
		elif resource is AtlasTexture:
			# Si ya es un AtlasTexture, usarlo directamente
			_set_sprite_property(property_name, resource as AtlasTexture, button)
		else:
			push_error("El recurso seleccionado no es una imagen válida")
		file_dialog.queue_free()
	)

	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

## Establece una propiedad de sprite y actualiza el botón
func _set_sprite_property(property_name: String, sprite: AtlasTexture, button: Button) -> void:
	if not current_pokemon_data:
		return

	match property_name:
		"icon_sprite":
			current_pokemon_data.icon_sprite = sprite
		"footprint_sprite":
			current_pokemon_data.footprint_sprite = sprite
		"battle_front_sprite":
			current_pokemon_data.battle_front_sprite = sprite
		"battle_back_sprite":
			current_pokemon_data.battle_back_sprite = sprite
		"battle_front_shiny_sprite":
			current_pokemon_data.battle_front_shiny_sprite = sprite
		"battle_back_shiny_sprite":
			current_pokemon_data.battle_back_shiny_sprite = sprite
		"overworld_spritesheet":
			current_pokemon_data.overworld_spritesheet = sprite
		"overworld_shiny_spritesheet":
			current_pokemon_data.overworld_shiny_spritesheet = sprite

	_update_sprite_button_text(button, sprite)
	# Actualizar preview según el botón
	match property_name:
		"icon_sprite":
			_update_sprite_preview(icon_sprite_preview, sprite)
		"footprint_sprite":
			_update_sprite_preview(footprint_sprite_preview, sprite)
		"battle_front_sprite":
			_update_sprite_preview(battle_front_sprite_preview, sprite)
		"battle_back_sprite":
			_update_sprite_preview(battle_back_sprite_preview, sprite)
		"battle_front_shiny_sprite":
			_update_sprite_preview(battle_front_shiny_sprite_preview, sprite)
		"battle_back_shiny_sprite":
			_update_sprite_preview(battle_back_shiny_sprite_preview, sprite)
		"overworld_spritesheet":
			_update_sprite_preview(overworld_spritesheet_preview, sprite)
		"overworld_shiny_spritesheet":
			_update_sprite_preview(overworld_shiny_spritesheet_preview, sprite)
	has_unsaved_changes = true

## Actualiza el texto del botón de sprite y muestra la imagen
func _update_sprite_button_text(button: Button, sprite: AtlasTexture) -> void:
	# El botón "Limpiar" solo se muestra cuando hay un sprite
	if button:
		if sprite:
			button.visible = true
			button.text = "Limpiar"
		else:
			button.visible = false

## Limpia un sprite (establece a null)
func _clear_sprite(property_name: String, button: Button) -> void:
	_set_sprite_property(property_name, null, button)

## Actualiza la imagen de preview de un sprite
func _update_sprite_preview(preview: TextureButton, sprite: AtlasTexture) -> void:
	if not preview:
		return

	# Asegurar que el TextureButton sea visible
	preview.visible = true

	if sprite and sprite.atlas:
		# Intentar obtener la imagen del atlas
		var atlas_texture := sprite.atlas as Texture2D
		if atlas_texture:
			# Intentar obtener la imagen del atlas
			var image: Image = null

			# Si es ImageTexture, obtener la imagen directamente
			if atlas_texture is ImageTexture:
				image = (atlas_texture as ImageTexture).get_image()
			# Si es CompressedTexture2D, intentar obtener la imagen
			elif atlas_texture is CompressedTexture2D:
				# Para CompressedTexture2D, necesitamos usar get_image() si está disponible
				if atlas_texture.has_method("get_image"):
					image = atlas_texture.get_image()
				else:
					# Si no podemos obtener la imagen, usar el AtlasTexture directamente
					preview.texture_normal = sprite
					return

			if image:
				# Extraer la región del AtlasTexture
				var region := sprite.region
				if region.size.x > 0 and region.size.y > 0:
					var sub_image := image.get_region(region)
					if sub_image:
						var texture := ImageTexture.new()
						texture.set_image(sub_image)
						preview.texture_normal = texture
						return

		# Si no se pudo extraer la región, usar el AtlasTexture directamente como fallback
		preview.texture_normal = sprite
	else:
		preview.texture_normal = null

## Callback cuando cambia una estadística base (para calcular total)
func _on_base_stat_changed(_value = null) -> void:
	_update_total_base_stat()
	_on_field_changed(_value)

## Actualiza el total de estadísticas base
func _update_total_base_stat() -> void:
	if not total_base_label_value:
		return

	var total := 0
	if hp_base_spin_box:
		total += int(hp_base_spin_box.value)
	if attack_base_spin_box:
		total += int(attack_base_spin_box.value)
	if defense_base_spin_box:
		total += int(defense_base_spin_box.value)
	if special_attack_base_spin_box:
		total += int(special_attack_base_spin_box.value)
	if special_defense_base_spin_box:
		total += int(special_defense_base_spin_box.value)
	if speed_base_spin_box:
		total += int(speed_base_spin_box.value)

	total_base_label_value.text = str(total)

## Abre el editor en modo Edit
func open_edit(pokemon_data: PokemonData, refresh_cb: Callable = Callable()) -> void:
	if not pokemon_data:
		push_error("PokemonEditorWindow: No se proporcionó PokemonData para editar")
		return

	editor_mode = EditorMode.EDIT
	current_pokemon_data = pokemon_data
	original_resource_path = pokemon_data.resource_path
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Mostrar la ventana primero para que los nodos estén disponibles
	popup_centered(Vector2i(900, 800))

	# Esperar a que _ready() se ejecute y los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Forzar inicialización de @onready si no se han inicializado
	if not id_spin_box:
		_initialize_nodes()
		await get_tree().process_frame

	_load_pokemon_data_to_ui(pokemon_data)
	_update_title()

## Abre el editor en modo Create
func open_create(refresh_cb: Callable = Callable()) -> void:
	editor_mode = EditorMode.CREATE
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Crear nuevo PokemonData con valores por defecto
	var pokemon_data_script := load("res://Scripts/Resources/Classes/PokemonData.gd") as GDScript
	if not pokemon_data_script:
		push_error("PokemonEditorWindow: No se pudo cargar PokemonData.gd")
		return

	current_pokemon_data = pokemon_data_script.new() as PokemonData
	if not current_pokemon_data:
		push_error("PokemonEditorWindow: No se pudo crear instancia de PokemonData")
		return

	# Valores por defecto
	current_pokemon_data.id = _get_next_available_id()
	current_pokemon_data.internal_name = ""
	current_pokemon_data.Name = ""
	original_resource_path = ""

	# Mostrar la ventana primero para que los nodos estén disponibles
	popup_centered(Vector2i(900, 800))

	# Esperar a que _ready() se ejecute y los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Forzar inicialización de @onready si no se han inicializado
	if not id_spin_box:
		_initialize_nodes()
		await get_tree().process_frame

	_load_pokemon_data_to_ui(current_pokemon_data)
	_update_title()

## Abre el editor en modo Duplicate
func open_duplicate(pokemon_data: PokemonData, refresh_cb: Callable = Callable()) -> void:
	if not pokemon_data:
		push_error("PokemonEditorWindow: No se proporcionó PokemonData para duplicar")
		return

	editor_mode = EditorMode.DUPLICATE
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Clonar el PokemonData
	current_pokemon_data = pokemon_data.duplicate(true) as PokemonData
	if not current_pokemon_data:
		push_error("PokemonEditorWindow: No se pudo duplicar PokemonData")
		return

	# Asignar nuevo ID
	current_pokemon_data.id = _get_next_available_id()
	original_resource_path = ""

	# Mostrar la ventana primero para que los nodos estén disponibles
	popup_centered(Vector2i(900, 800))

	# Esperar a que _ready() se ejecute y los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Forzar inicialización de @onready si no se han inicializado
	if not id_spin_box:
		_initialize_nodes()
		await get_tree().process_frame

	_load_pokemon_data_to_ui(current_pokemon_data)
	_update_title()

## Obtiene un nodo de forma segura, usando @onready si está disponible o get_node si no
func _get_node_safe(path: String) -> Node:
	var node_path := NodePath(path)
	# Intentar obtener desde el árbol
	var node := get_node_or_null(node_path)
	if node:
		return node
	# Si no está disponible, intentar con get_node (puede fallar)
	return get_node_or_null(node_path)

## Carga los datos del PokemonData a la UI
func _load_pokemon_data_to_ui(pokemon_data: PokemonData) -> void:
	if not pokemon_data:
		push_error("PokemonEditorWindow: _load_pokemon_data_to_ui recibió pokemon_data null")
		return

	print("[PokemonEditorWindow] Cargando datos del Pokémon ID: %d" % pokemon_data.id)

	# General - obtener nodos dinámicamente
	var id_spin_node := _get_node_safe("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/IdContainer/IdSpinBox") as SpinBox
	var internal_name_node := _get_node_safe("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/InternalNameContainer/InternalNameLineEdit") as LineEdit
	var display_name_node := _get_node_safe("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/DisplayNameContainer/DisplayNameLineEdit") as LineEdit
	var description_node := _get_node_safe("VBoxContainer/TabContainer/General/VBoxContainer/GeneralSection/DescriptionContainer/DescriptionTextEdit") as TextEdit

	if id_spin_node:
		id_spin_node.value = pokemon_data.id
		print("[PokemonEditorWindow] ID cargado: %d" % pokemon_data.id)
	else:
		push_error("PokemonEditorWindow: No se pudo encontrar IdSpinBox")

	if internal_name_node:
		internal_name_node.text = pokemon_data.internal_name if pokemon_data.internal_name else ""
	if display_name_node:
		display_name_node.text = pokemon_data.Name if pokemon_data.Name else ""
	if description_node:
		description_node.text = pokemon_data.description if pokemon_data.description else ""

	# Tipos
	# Tipo A - usar type_a_id directamente (optimización)
	if type_a_option_button:
		var type_a_index := 0
		var type_a_id: int = pokemon_data.type_a_id

		# Compatibilidad: si type_a_id es 0 pero existe type_a (Resource), extraer el ID
		if type_a_id == 0 and pokemon_data.type_a != null:
			var type_resource = pokemon_data.type_a as Resource
			if type_resource:
				var id_value = type_resource.get("id")
				if id_value != null:
					type_a_id = int(id_value)
					# Migrar automáticamente: guardar type_a_id y limpiar type_a
					pokemon_data.type_a_id = type_a_id
					pokemon_data.type_a = null

		if type_a_id > 0:
			for i in range(type_a_option_button.get_item_count()):
				if type_a_option_button.get_item_id(i) == type_a_id:
					type_a_index = i
					break
		type_a_option_button.selected = type_a_index

	# Tipo B - usar type_b_id directamente (optimización)
	if type_b_option_button:
		var type_b_index := 0
		var type_b_id: int = pokemon_data.type_b_id

		# Compatibilidad: si type_b_id es 0 pero existe type_b (Resource), extraer el ID
		if type_b_id == 0 and pokemon_data.type_b != null:
			var type_resource = pokemon_data.type_b as Resource
			if type_resource:
				var id_value = type_resource.get("id")
				if id_value != null:
					type_b_id = int(id_value)
					# Migrar automáticamente: guardar type_b_id y limpiar type_b
					pokemon_data.type_b_id = type_b_id
					pokemon_data.type_b = null

		if type_b_id > 0:
			for i in range(type_b_option_button.get_item_count()):
				if type_b_option_button.get_item_id(i) == type_b_id:
					type_b_index = i
					break
		type_b_option_button.selected = type_b_index

	# Base Stats
	if hp_base_spin_box:
		hp_base_spin_box.value = pokemon_data.hp_base
	if attack_base_spin_box:
		attack_base_spin_box.value = pokemon_data.attack_base
	if defense_base_spin_box:
		defense_base_spin_box.value = pokemon_data.defense_base
	if special_attack_base_spin_box:
		special_attack_base_spin_box.value = pokemon_data.special_attack_base
	if special_defense_base_spin_box:
		special_defense_base_spin_box.value = pokemon_data.special_defense_base
	if speed_base_spin_box:
		speed_base_spin_box.value = pokemon_data.speed_base
	_update_total_base_stat()

	# EVs
	if hp_effort_evs_spin_box:
		hp_effort_evs_spin_box.value = pokemon_data.hp_effort_EVs
	if attack_effort_evs_spin_box:
		attack_effort_evs_spin_box.value = pokemon_data.attack_effort_EVs
	if defense_effort_evs_spin_box:
		defense_effort_evs_spin_box.value = pokemon_data.defense_effort_EVs
	if special_effort_attack_evs_spin_box:
		special_effort_attack_evs_spin_box.value = pokemon_data.special_effort_attack_EVs
	if special_effort_defense_evs_spin_box:
		special_effort_defense_evs_spin_box.value = pokemon_data.special_effort_defense_EVs
	if speed_effort_evs_spin_box:
		speed_effort_evs_spin_box.value = pokemon_data.speed_effort_EVs

	# Physical Info
	if height_spin_box:
		height_spin_box.value = pokemon_data.height
	if weight_spin_box:
		weight_spin_box.value = pokemon_data.weight
	if base_experience_spin_box:
		base_experience_spin_box.value = pokemon_data.base_exprience

	# Other Info
	if gender_rate_spin_box:
		gender_rate_spin_box.value = pokemon_data.gender_rate
	if capture_rate_spin_box:
		capture_rate_spin_box.value = pokemon_data.capture_rate
	if base_happiness_spin_box:
		base_happiness_spin_box.value = pokemon_data.base_happiness
	if hatch_counter_spin_box:
		hatch_counter_spin_box.value = pokemon_data.hatch_counter
	if growth_rate_id_spin_box:
		growth_rate_id_spin_box.value = pokemon_data.growth_rate_id
	if egg_group_a_id_spin_box:
		egg_group_a_id_spin_box.value = pokemon_data.egg_group_a_id
	if egg_group_b_id_spin_box:
		egg_group_b_id_spin_box.value = pokemon_data.egg_group_b_id
	if habitat_id_spin_box:
		habitat_id_spin_box.value = pokemon_data.habitat_id

	# Flags
	if is_default_check_box:
		is_default_check_box.button_pressed = pokemon_data.is_default
	if is_baby_check_box:
		is_baby_check_box.button_pressed = pokemon_data.is_baby
	if has_gender_differences_check_box:
		has_gender_differences_check_box.button_pressed = pokemon_data.has_gender_differences
	if forms_switchable_check_box:
		forms_switchable_check_box.button_pressed = pokemon_data.forms_switchable

	# Battle Positions
	if battler_player_y_spin_box:
		battler_player_y_spin_box.value = pokemon_data.battlerPlayerY
	if battler_enemy_y_spin_box:
		battler_enemy_y_spin_box.value = pokemon_data.battlerEnemyY
	if battler_altitude_spin_box:
		battler_altitude_spin_box.value = pokemon_data.battlerAltitude

	# Sprites - obtener nodos dinámicamente si @onready no funcionó
	var icon_preview := icon_sprite_preview if icon_sprite_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/IconSpriteContainer/IconSpritePreview") as TextureButton
	var footprint_preview := footprint_sprite_preview if footprint_sprite_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/SpritesSection/FootprintSpriteContainer/FootprintSpritePreview") as TextureButton
	var battle_front_preview := battle_front_sprite_preview if battle_front_sprite_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontSpriteContainer/BattleFrontSpritePreview") as TextureButton
	var battle_back_preview := battle_back_sprite_preview if battle_back_sprite_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackSpriteContainer/BattleBackSpritePreview") as TextureButton
	var battle_front_shiny_preview := battle_front_shiny_sprite_preview if battle_front_shiny_sprite_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleFrontShinySpriteContainer/BattleFrontShinySpritePreview") as TextureButton
	var battle_back_shiny_preview := battle_back_shiny_sprite_preview if battle_back_shiny_sprite_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/BattleSpritesSection/BattleBackShinySpriteContainer/BattleBackShinySpritePreview") as TextureButton
	var overworld_preview := overworld_spritesheet_preview if overworld_spritesheet_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldSpritesheetContainer/OverworldSpritesheetPreview") as TextureButton
	var overworld_shiny_preview := overworld_shiny_spritesheet_preview if overworld_shiny_spritesheet_preview else get_node_or_null("VBoxContainer/TabContainer/Sprites/VBoxContainer/OverworldSpritesSection/OverworldShinySpritesheetContainer/OverworldShinySpritesheetPreview") as TextureButton

	_update_sprite_button_text(icon_sprite_button, pokemon_data.icon_sprite)
	_update_sprite_preview(icon_preview, pokemon_data.icon_sprite)
	_update_sprite_button_text(footprint_sprite_button, pokemon_data.footprint_sprite)
	_update_sprite_preview(footprint_preview, pokemon_data.footprint_sprite)
	_update_sprite_button_text(battle_front_sprite_button, pokemon_data.battle_front_sprite)
	_update_sprite_preview(battle_front_preview, pokemon_data.battle_front_sprite)
	_update_sprite_button_text(battle_back_sprite_button, pokemon_data.battle_back_sprite)
	_update_sprite_preview(battle_back_preview, pokemon_data.battle_back_sprite)
	_update_sprite_button_text(battle_front_shiny_sprite_button, pokemon_data.battle_front_shiny_sprite)
	_update_sprite_preview(battle_front_shiny_preview, pokemon_data.battle_front_shiny_sprite)
	_update_sprite_button_text(battle_back_shiny_sprite_button, pokemon_data.battle_back_shiny_sprite)
	_update_sprite_preview(battle_back_shiny_preview, pokemon_data.battle_back_shiny_sprite)
	_update_sprite_button_text(overworld_spritesheet_button, pokemon_data.overworld_spritesheet)
	_update_sprite_preview(overworld_preview, pokemon_data.overworld_spritesheet)
	_update_sprite_button_text(overworld_shiny_spritesheet_button, pokemon_data.overworld_shiny_spritesheet)
	_update_sprite_preview(overworld_shiny_preview, pokemon_data.overworld_shiny_spritesheet)

## Actualiza los datos del PokemonData desde la UI
func _update_pokemon_data_from_ui() -> void:
	if not current_pokemon_data:
		return

	# General
	if id_spin_box:
		current_pokemon_data.id = int(id_spin_box.value)
	if internal_name_line_edit:
		current_pokemon_data.internal_name = internal_name_line_edit.text
	if display_name_line_edit:
		current_pokemon_data.Name = display_name_line_edit.text
	if description_text_edit:
		current_pokemon_data.description = description_text_edit.text

	# Tipos - usar type_a_id y type_b_id directamente (optimización)
	if type_a_option_button:
		var selected_index := type_a_option_button.selected
		if selected_index > 0:
			var type_id: int = type_a_option_button.get_item_id(selected_index)
			current_pokemon_data.type_a_id = type_id
			# Limpiar referencia antigua si existe
			current_pokemon_data.type_a = null
		else:
			current_pokemon_data.type_a_id = 0
			# Limpiar referencia antigua si existe
			current_pokemon_data.type_a = null

	if type_b_option_button:
		var selected_index := type_b_option_button.selected
		if selected_index > 0:
			var type_id: int = type_b_option_button.get_item_id(selected_index)
			current_pokemon_data.type_b_id = type_id
			# Limpiar referencia antigua si existe
			current_pokemon_data.type_b = null
		else:
			current_pokemon_data.type_b_id = 0
			# Limpiar referencia antigua si existe
			current_pokemon_data.type_b = null

	# Base Stats
	if hp_base_spin_box:
		current_pokemon_data.hp_base = int(hp_base_spin_box.value)
	if attack_base_spin_box:
		current_pokemon_data.attack_base = int(attack_base_spin_box.value)
	if defense_base_spin_box:
		current_pokemon_data.defense_base = int(defense_base_spin_box.value)
	if special_attack_base_spin_box:
		current_pokemon_data.special_attack_base = int(special_attack_base_spin_box.value)
	if special_defense_base_spin_box:
		current_pokemon_data.special_defense_base = int(special_defense_base_spin_box.value)
	if speed_base_spin_box:
		current_pokemon_data.speed_base = int(speed_base_spin_box.value)

	# Calcular total_base
	current_pokemon_data.total_base = (
		current_pokemon_data.hp_base +
		current_pokemon_data.attack_base +
		current_pokemon_data.defense_base +
		current_pokemon_data.special_attack_base +
		current_pokemon_data.special_defense_base +
		current_pokemon_data.speed_base
	)

	# EVs
	if hp_effort_evs_spin_box:
		current_pokemon_data.hp_effort_EVs = int(hp_effort_evs_spin_box.value)
	if attack_effort_evs_spin_box:
		current_pokemon_data.attack_effort_EVs = int(attack_effort_evs_spin_box.value)
	if defense_effort_evs_spin_box:
		current_pokemon_data.defense_effort_EVs = int(defense_effort_evs_spin_box.value)
	if special_effort_attack_evs_spin_box:
		current_pokemon_data.special_effort_attack_EVs = int(special_effort_attack_evs_spin_box.value)
	if special_effort_defense_evs_spin_box:
		current_pokemon_data.special_effort_defense_EVs = int(special_effort_defense_evs_spin_box.value)
	if speed_effort_evs_spin_box:
		current_pokemon_data.speed_effort_EVs = int(speed_effort_evs_spin_box.value)

	# Physical Info
	if height_spin_box:
		current_pokemon_data.height = height_spin_box.value
	if weight_spin_box:
		current_pokemon_data.weight = weight_spin_box.value
	if base_experience_spin_box:
		current_pokemon_data.base_exprience = int(base_experience_spin_box.value)

	# Other Info
	if gender_rate_spin_box:
		current_pokemon_data.gender_rate = int(gender_rate_spin_box.value)
	if capture_rate_spin_box:
		current_pokemon_data.capture_rate = int(capture_rate_spin_box.value)
	if base_happiness_spin_box:
		current_pokemon_data.base_happiness = int(base_happiness_spin_box.value)
	if hatch_counter_spin_box:
		current_pokemon_data.hatch_counter = int(hatch_counter_spin_box.value)
	if growth_rate_id_spin_box:
		current_pokemon_data.growth_rate_id = int(growth_rate_id_spin_box.value)
	if egg_group_a_id_spin_box:
		current_pokemon_data.egg_group_a_id = int(egg_group_a_id_spin_box.value)
	if egg_group_b_id_spin_box:
		current_pokemon_data.egg_group_b_id = int(egg_group_b_id_spin_box.value)
	if habitat_id_spin_box:
		current_pokemon_data.habitat_id = int(habitat_id_spin_box.value)

	# Flags
	if is_default_check_box:
		current_pokemon_data.is_default = is_default_check_box.button_pressed
	if is_baby_check_box:
		current_pokemon_data.is_baby = is_baby_check_box.button_pressed
	if has_gender_differences_check_box:
		current_pokemon_data.has_gender_differences = has_gender_differences_check_box.button_pressed
	if forms_switchable_check_box:
		current_pokemon_data.forms_switchable = forms_switchable_check_box.button_pressed

	# Battle Positions
	if battler_player_y_spin_box:
		current_pokemon_data.battlerPlayerY = int(battler_player_y_spin_box.value)
	if battler_enemy_y_spin_box:
		current_pokemon_data.battlerEnemyY = int(battler_enemy_y_spin_box.value)
	if battler_altitude_spin_box:
		current_pokemon_data.battlerAltitude = int(battler_altitude_spin_box.value)

## Actualiza el título de la ventana según el modo
func _update_title() -> void:
	var mode_text := ""
	match editor_mode:
		EditorMode.EDIT:
			mode_text = "Editar"
		EditorMode.CREATE:
			mode_text = "Crear"
		EditorMode.DUPLICATE:
			mode_text = "Duplicar"

	var pokemon_name := ""
	if current_pokemon_data and current_pokemon_data.Name != "":
		pokemon_name = " - %s" % current_pokemon_data.Name
	elif current_pokemon_data and current_pokemon_data.internal_name != "":
		pokemon_name = " - %s" % current_pokemon_data.internal_name

	title = "Pokémon Editor (%s)%s" % [mode_text, pokemon_name]

## Obtiene el siguiente ID disponible
func _get_next_available_id() -> int:
	var dir_path := "res://Resources/Data/Pokemon"
	var max_id := 0

	# Buscar el ID más alto existente
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var file_base := file_name.get_basename()
				var id_str := file_base.split(" - ")[0].split(" ")[0].strip_edges()
				if id_str.is_valid_int():
					var id := int(id_str)
					if id > max_id:
						max_id = id
			file_name = dir.get_next()
		dir.list_dir_end()

	return max_id + 1

## Callbacks de UI
func _on_field_changed(_value = null) -> void:
	has_unsaved_changes = true
	_update_title()

func _on_save_button_pressed() -> void:
	_update_pokemon_data_from_ui()
	_save_with_validation()

## Proceso de guardado con validación
func _save_with_validation() -> void:
	# Validación
	var validation_result := await _validate_data()
	if not validation_result:
		return

	# Determinar ruta de guardado
	var save_path: String
	if editor_mode == EditorMode.EDIT and original_resource_path != "":
		save_path = original_resource_path
	else:
		# Modo Create o Duplicate: generar ruta nueva
		var dir_path := "res://Resources/Data/Pokemon"
		var file_name := "%03d.tres" % current_pokemon_data.id
		save_path = dir_path + "/" + file_name

		# Si el archivo ya existe y no es el mismo, avisar
		if ResourceLoader.exists(save_path) and save_path != original_resource_path:
			var confirmed := await _show_confirmation_dialog(
				"El archivo %s ya existe. ¿Sobrescribir?" % file_name,
				"Sobrescribir",
				"Cancelar"
			)
			if not confirmed:
				return

	# Guardar
	if _save_to_disk(save_path):
		has_unsaved_changes = false
		var was_new := (editor_mode != EditorMode.EDIT)

		# Refrescar el explorador de archivos de Godot
		_refresh_filesystem()

		saved.emit(current_pokemon_data, was_new)

		# Refrescar lista si hay callback
		if refresh_callback.is_valid():
			refresh_callback.call()

		# Cerrar ventana
		hide()
		queue_free()

func _on_cancel_button_pressed() -> void:
	print("[PokemonEditorWindow] Botón Cancelar presionado")
	_try_close()

func _on_close_requested() -> void:
	_try_close()

## Intenta cerrar la ventana, mostrando aviso si hay cambios sin guardar
func _try_close() -> void:
	print("[PokemonEditorWindow] _try_close() llamado, has_unsaved_changes: %s" % has_unsaved_changes)
	if has_unsaved_changes:
		_try_close_with_confirmation()
	else:
		print("[PokemonEditorWindow] No hay cambios sin guardar, cerrando directamente")
		_close_window()

## Muestra confirmación antes de cerrar con cambios sin guardar
func _try_close_with_confirmation() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "¿Descartar los cambios sin guardar?"
	dialog.ok_button_text = "Descartar"
	dialog.cancel_button_text = "Cancelar"

	# Añadir como hijo de esta ventana para que sea modal
	add_child(dialog)

	dialog.confirmed.connect(func():
		print("[PokemonEditorWindow] Usuario confirmó descartar cambios")
		_close_window()
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		print("[PokemonEditorWindow] Usuario canceló el cierre")
		dialog.queue_free()
	)

	dialog.popup_centered()

## Cierra la ventana
func _close_window() -> void:
	print("[PokemonEditorWindow] _close_window() llamado")
	cancelled.emit()
	hide()
	print("[PokemonEditorWindow] Ventana ocultada, llamando a queue_free()...")
	call_deferred("queue_free")
	print("[PokemonEditorWindow] queue_free() llamado (deferred)")

## Valida los datos antes de guardar (puede mostrar diálogos, por eso es async)
func _validate_data() -> bool:
	if not current_pokemon_data:
		await _show_error("No hay datos de Pokémon para guardar")
		return false

	if current_pokemon_data.id < 0:
		await _show_error("El ID debe ser mayor o igual a 0")
		return false

	# Validar que el nombre no esté vacío (opcional, pero recomendado)
	if current_pokemon_data.Name.is_empty() and current_pokemon_data.internal_name.is_empty():
		var confirmed := await _show_confirmation_dialog(
			"El Pokémon no tiene nombre. ¿Guardar de todas formas?",
			"Guardar",
			"Cancelar"
		)
		if not confirmed:
			return false

	return true

## Guarda el PokemonData en disco
func _save_to_disk(path: String) -> bool:
	if path.is_empty():
		_show_error("No se especificó una ruta de guardado")
		return false

	# Actualizar resource_path
	current_pokemon_data.resource_path = path

	# Guardar
	var error := ResourceSaver.save(current_pokemon_data, path)
	if error != OK:
		_show_error("Error al guardar: %s" % error_string(error))
		return false

	# Renombrar el archivo con el formato "XXX - Nombre.tres" si no lo tiene ya
	var final_path := _get_final_file_path(path)
	if final_path != path:
		# Renombrar el archivo
		var dir := DirAccess.open(ProjectSettings.globalize_path(path.get_base_dir()))
		if dir:
			var old_name := path.get_file()
			var new_name := final_path.get_file()
			var rename_error := dir.rename(old_name, new_name)
			if rename_error == OK:
				path = final_path
				current_pokemon_data.resource_path = path
				print("[PokemonEditorWindow] Archivo renombrado a: %s" % final_path)
			else:
				push_warning("[PokemonEditorWindow] No se pudo renombrar el archivo: %s" % error_string(rename_error))

	print("[PokemonEditorWindow] Guardado exitoso: %s" % path)
	return true

## Refresca el explorador de archivos de Godot
func _refresh_filesystem() -> void:
	var filesystem = EditorInterface.get_resource_filesystem()
	if filesystem:
		filesystem.scan()
		print("[PokemonEditorWindow] Explorador de archivos refrescado")

## Obtiene la ruta final del archivo con el formato "XXX - Nombre.tres"
func _get_final_file_path(initial_path: String) -> String:
	var dir_path := initial_path.get_base_dir()
	var file_name := initial_path.get_file()
	var file_base := file_name.get_basename()

	# Verificar si ya tiene el formato "XXX - Nombre"
	if " - " in file_base:
		return initial_path

	# Obtener el nombre del Pokémon
	var pokemon_name := ""
	if current_pokemon_data:
		if current_pokemon_data.Name != "":
			pokemon_name = current_pokemon_data.Name
		elif current_pokemon_data.internal_name != "":
			pokemon_name = current_pokemon_data.internal_name

	# Si no hay nombre, usar el ID
	if pokemon_name == "":
		pokemon_name = "Pokémon #%d" % current_pokemon_data.id

	# Limpiar el nombre para que sea válido como nombre de archivo
	pokemon_name = pokemon_name.strip_edges()
	pokemon_name = pokemon_name.replace("/", "-").replace("\\", "-").replace(":", "-")
	pokemon_name = pokemon_name.replace("*", "").replace("?", "").replace("\"", "")
	pokemon_name = pokemon_name.replace("<", "").replace(">", "").replace("|", "")

	# Construir el nuevo nombre
	var new_file_name := "%03d - %s.tres" % [current_pokemon_data.id, pokemon_name]
	return dir_path + "/" + new_file_name

## Muestra un mensaje de error
func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Error"
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()

## Muestra un diálogo de confirmación y retorna true si se confirma
func _show_confirmation_dialog(message: String, ok_text: String = "Aceptar", cancel_text: String = "Cancelar") -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = cancel_text
	add_child(dialog)

	var result := false
	var finished := false

	# Conectar señales
	dialog.confirmed.connect(func():
		print("[PokemonEditorWindow] Diálogo confirmado")
		result = true
		finished = true
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		print("[PokemonEditorWindow] Diálogo cancelado")
		result = false
		finished = true
		dialog.queue_free()
	)

	dialog.popup_centered()

	# Esperar a que se confirme o cancele
	while not finished:
		await get_tree().process_frame

	return result
