@tool
extends Window

signal saved(trainer_data: Resource, was_new: bool)
signal cancelled()

enum EditorMode { CREATE, EDIT, DUPLICATE }

var current_mode: int = EditorMode.CREATE
var original_resource_path: String = ""
var refresh_callback: Callable = Callable()
var was_new: bool = true
var current_trainer_data: Resource = null
var definition_editor_script: GDScript = null
var save_embedded_mode: bool = false

var party_entries: Array[Dictionary] = []
var trainer_classes: Array[Dictionary] = []

@onready var id_spin: SpinBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/IdContainer/IdSpinBox
@onready var class_option: OptionButton = get_node_or_null("VBoxContainer/ScrollContainer/Content/GeneralSection/ClassContainer/ClassOptionButton")
@onready var class_spin_fallback: SpinBox = get_node_or_null("VBoxContainer/ScrollContainer/Content/GeneralSection/ClassContainer/ClassSpinBox")
@onready var display_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var reward_spin: SpinBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/RewardContainer/RewardSpinBox
@onready var double_check: CheckBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/FlagsContainer/DoubleBattleCheck
@onready var rematch_check: CheckBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/FlagsContainer/RematchCheck
@onready var intro_text: TextEdit = $VBoxContainer/ScrollContainer/Content/TextsSection/IntroTextEdit
@onready var defeat_text: TextEdit = $VBoxContainer/ScrollContainer/Content/TextsSection/DefeatTextEdit
@onready var victory_text: TextEdit = $VBoxContainer/ScrollContainer/Content/TextsSection/VictoryTextEdit

@onready var party_list: ItemList = $VBoxContainer/ScrollContainer/Content/PartySection/PartyContent/PartyList
@onready var add_pokemon_button: Button = $VBoxContainer/ScrollContainer/Content/PartySection/PartyContent/PartyButtons/AddPokemonButton
@onready var edit_pokemon_button: Button = $VBoxContainer/ScrollContainer/Content/PartySection/PartyContent/PartyButtons/EditPokemonButton
@onready var remove_pokemon_button: Button = $VBoxContainer/ScrollContainer/Content/PartySection/PartyContent/PartyButtons/RemovePokemonButton

@onready var save_button: Button = $VBoxContainer/BottomButtons/SaveButton
@onready var cancel_button: Button = $VBoxContainer/BottomButtons/CancelButton

func _ready() -> void:
	title = "Trainer Editor"
	unresizable = false
	always_on_top = false
	exclusive = true
	min_size = Vector2i(820, 720)
	print("[TrainerEditorWindow] _ready()")
	definition_editor_script = load("res://addons/event_tools/pokemon_definition_editor_window.gd") as GDScript
	close_requested.connect(_on_close_requested)
	save_button.pressed.connect(_save_with_validation)
	cancel_button.pressed.connect(_on_cancel_pressed)
	party_list.item_selected.connect(_on_party_item_selected)
	add_pokemon_button.pressed.connect(_on_add_pokemon_pressed)
	edit_pokemon_button.pressed.connect(_on_edit_pokemon_pressed)
	remove_pokemon_button.pressed.connect(_on_remove_pokemon_pressed)
	if class_option != null:
		_load_trainer_classes()

func open_create(refresh_cb: Callable = Callable()) -> void:
	current_mode = EditorMode.CREATE
	save_embedded_mode = false
	refresh_callback = refresh_cb
	was_new = true
	original_resource_path = ""
	current_trainer_data = TrainerData.new()
	_reset_form()
	if current_trainer_data != null:
		current_trainer_data.trainer_id = _get_next_trainer_id()
		id_spin.value = current_trainer_data.trainer_id
		display_name_line.text = "Nuevo Entrenador %d" % int(id_spin.value)
	title = "Trainer Editor - Crear"
	popup_centered(Vector2i(820, 720))

func open_edit(trainer_data: Resource, refresh_cb: Callable = Callable(), resource_path: String = "") -> void:
	current_mode = EditorMode.EDIT
	save_embedded_mode = false
	refresh_callback = refresh_cb
	was_new = false
	original_resource_path = resource_path if not resource_path.is_empty() else trainer_data.resource_path
	current_trainer_data = trainer_data
	print("[TrainerEditorWindow] open_edit path=%s class=%s" % [original_resource_path, current_trainer_data.get_class() if current_trainer_data else "null"])
	_load_from_trainer(current_trainer_data)
	title = "Trainer Editor - Editar"
	popup_centered(Vector2i(820, 720))

func open_duplicate(trainer_data: Resource, refresh_cb: Callable = Callable(), _resource_path: String = "") -> void:
	current_mode = EditorMode.DUPLICATE
	save_embedded_mode = false
	refresh_callback = refresh_cb
	was_new = true
	if trainer_data == null:
		return
	current_trainer_data = trainer_data.duplicate(true)
	original_resource_path = ""
	_load_from_trainer(current_trainer_data)
	id_spin.value = _get_next_trainer_id()
	display_name_line.text = "%s Copia" % display_name_line.text
	title = "Trainer Editor - Duplicar"
	popup_centered(Vector2i(820, 720))

func open_edit_embedded(trainer_data: Resource, refresh_cb: Callable = Callable()) -> void:
	current_mode = EditorMode.EDIT
	save_embedded_mode = true
	refresh_callback = refresh_cb
	was_new = false
	original_resource_path = ""
	current_trainer_data = trainer_data
	_load_from_trainer(current_trainer_data)
	title = "Trainer Editor - Editar (Embebido)"
	popup_centered(Vector2i(820, 720))

func _reset_form() -> void:
	id_spin.value = 1
	_select_trainer_class_id(0)
	display_name_line.text = ""
	reward_spin.value = 1000
	double_check.button_pressed = false
	rematch_check.button_pressed = false
	intro_text.text = "¡Vamos a combatir!"
	defeat_text.text = "He perdido..."
	victory_text.text = "¡Gané!"
	party_entries.clear()
	_refresh_party_list()

func _load_from_trainer(trainer_data: Resource) -> void:
	_reset_form()
	if trainer_data == null:
		return

	id_spin.value = int(trainer_data.get("trainer_id"))
	_select_trainer_class_id(int(trainer_data.get("trainer_class_id")))
	display_name_line.text = str(trainer_data.get("display_name"))
	reward_spin.value = int(trainer_data.get("reward_money"))
	double_check.button_pressed = bool(trainer_data.get("double_battle"))
	rematch_check.button_pressed = bool(trainer_data.get("can_rematch"))
	intro_text.text = str(trainer_data.get("intro_text"))
	defeat_text.text = str(trainer_data.get("defeat_text"))
	victory_text.text = str(trainer_data.get("victory_text"))

	var party_value: Variant = trainer_data.get("party_data")
	if party_value is Array:
		for entry in party_value:
			if entry == null:
				continue
			var parsed := {
				"pokemon_id": int(_entry_get(entry, "pokemon_id", 1)),
				"level": maxi(1, mini(100, int(_entry_get(entry, "level", 5)))),
				"nickname": str(_entry_get(entry, "nickname", "")),
				"gender": int(_entry_get(entry, "gender", 0)),
				"shiny": bool(_entry_get(entry, "shiny", false)),
				"is_wild": bool(_entry_get(entry, "is_wild", false)),
				"randomize_ivs": bool(_entry_get(entry, "randomize_ivs", false)),
				"hp_IVs": int(_entry_get(entry, "hp_IVs", 0)),
				"attack_IVs": int(_entry_get(entry, "attack_IVs", 0)),
				"defense_IVs": int(_entry_get(entry, "defense_IVs", 0)),
				"spAttack_IVs": int(_entry_get(entry, "spAttack_IVs", 0)),
				"spDefense_IVs": int(_entry_get(entry, "spDefense_IVs", 0)),
				"speed_IVs": int(_entry_get(entry, "speed_IVs", 0)),
				"randomize_evs": bool(_entry_get(entry, "randomize_evs", false)),
				"hp_EVs": int(_entry_get(entry, "hp_EVs", 0)),
				"attack_EVs": int(_entry_get(entry, "attack_EVs", 0)),
				"defense_EVs": int(_entry_get(entry, "defense_EVs", 0)),
				"spAttack_EVs": int(_entry_get(entry, "spAttack_EVs", 0)),
				"spDefense_EVs": int(_entry_get(entry, "spDefense_EVs", 0)),
				"speed_EVs": int(_entry_get(entry, "speed_EVs", 0)),
				"nature_id": int(_entry_get(entry, "nature_id", 0)),
				"ability_id": int(_entry_get(entry, "ability_id", 0)),
				"custom_move_ids": _to_move_enum_array(_entry_get(entry, "custom_move_ids", [])),
				"held_item_id": int(_entry_get(entry, "held_item_id", 0))
			}
			party_entries.append(parsed)
	_refresh_party_list()

func _refresh_party_list() -> void:
	party_list.clear()
	for i in range(party_entries.size()):
		var e := party_entries[i]
		var pid: int = e.get("pokemon_id", 0)
		var level: int = e.get("level", 1)
		var nickname: String = e.get("nickname", "")
		var species := PokemonsEnum.get_display_name(pid) if pid > 0 else "Pokemon"
		if species == "":
			species = "Pokemon ID %d" % pid
		var label := "%d) %s - Nv.%d" % [i + 1, species, level]
		if nickname != "":
			label = "%d) %s (%s) - Nv.%d" % [i + 1, nickname, species, level]
		party_list.add_item(label)

func _on_party_item_selected(index: int) -> void:
	if index < 0 or index >= party_entries.size():
		return

func _on_add_pokemon_pressed() -> void:
	if not Engine.is_editor_hint():
		_show_warning("El selector de Pokémon solo está disponible en editor.")
		return

	var picker_window = ResourcePickerAPI.open_pokemon_picker(
		null,
		_on_pokemon_picker_selected,
		_on_pokemon_picker_cancelled
	)
	if not picker_window:
		_show_warning("No se pudo abrir el selector de Pokémon.")

func _on_edit_pokemon_pressed() -> void:
	var selected := party_list.get_selected_items()
	if selected.is_empty():
		_show_warning("Selecciona un Pokémon del equipo para editar.")
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= party_entries.size():
		return
	var current_entry := party_entries[idx].duplicate(true)
	_show_party_entry_dialog(current_entry, func(updated_entry: Dictionary):
		party_entries[idx] = updated_entry
		_refresh_party_list()
		party_list.select(idx)
	, "Editar PokemonDefinition")

func _on_remove_pokemon_pressed() -> void:
	var selected := party_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= party_entries.size():
		return
	party_entries.remove_at(idx)
	_refresh_party_list()

func _on_pokemon_picker_selected(result: ResourcePickerResult) -> void:
	if result == null:
		return

	var pokemon_id := int(result.resource_id)
	if pokemon_id <= 0 and result.resource:
		pokemon_id = int(result.resource.get("id"))
	if pokemon_id <= 0:
		_show_warning("No se pudo obtener el ID del Pokémon seleccionado.")
		return

	var new_entry := {
		"pokemon_id": pokemon_id,
		"level": 5,
		"nickname": "",
		"gender": 0,
		"shiny": false,
		"is_wild": false,
		"randomize_ivs": false,
		"hp_IVs": 0,
		"attack_IVs": 0,
		"defense_IVs": 0,
		"spAttack_IVs": 0,
		"spDefense_IVs": 0,
		"speed_IVs": 0,
		"randomize_evs": false,
		"hp_EVs": 0,
		"attack_EVs": 0,
		"defense_EVs": 0,
		"spAttack_EVs": 0,
		"spDefense_EVs": 0,
		"speed_EVs": 0,
		"nature_id": 0,
		"ability_id": 0,
		"custom_move_ids": [],
		"held_item_id": 0
	}
	_show_party_entry_dialog(new_entry, func(updated_entry: Dictionary):
		party_entries.append(updated_entry)
		_refresh_party_list()
		party_list.select(party_entries.size() - 1)
	, "Nuevo PokemonDefinition")

func _on_pokemon_picker_cancelled() -> void:
	# No hacemos nada; el usuario canceló el picker.
	pass

func _show_party_entry_dialog(initial_data: Dictionary, on_confirm: Callable, dialog_title: String) -> void:
	if definition_editor_script == null:
		_show_warning("No se pudo cargar PokemonDefinitionEditorWindow.")
		return
	var definition_editor = definition_editor_script.new()
	if definition_editor == null:
		_show_warning("No se pudo instanciar PokemonDefinitionEditorWindow.")
		return

	var definition := PokemonDefinition.new()
	definition.pokemon_id = int(initial_data.get("pokemon_id", 1))
	definition.level = int(initial_data.get("level", 5))
	definition.nickname = str(initial_data.get("nickname", ""))
	definition.gender = int(initial_data.get("gender", 0))
	definition.shiny = bool(initial_data.get("shiny", false))
	definition.is_wild = bool(initial_data.get("is_wild", false))
	definition.randomize_ivs = bool(initial_data.get("randomize_ivs", false))
	definition.hp_IVs = int(initial_data.get("hp_IVs", 0))
	definition.attack_IVs = int(initial_data.get("attack_IVs", 0))
	definition.defense_IVs = int(initial_data.get("defense_IVs", 0))
	definition.spAttack_IVs = int(initial_data.get("spAttack_IVs", 0))
	definition.spDefense_IVs = int(initial_data.get("spDefense_IVs", 0))
	definition.speed_IVs = int(initial_data.get("speed_IVs", 0))
	definition.randomize_evs = bool(initial_data.get("randomize_evs", false))
	definition.hp_EVs = int(initial_data.get("hp_EVs", 0))
	definition.attack_EVs = int(initial_data.get("attack_EVs", 0))
	definition.defense_EVs = int(initial_data.get("defense_EVs", 0))
	definition.spAttack_EVs = int(initial_data.get("spAttack_EVs", 0))
	definition.spDefense_EVs = int(initial_data.get("spDefense_EVs", 0))
	definition.speed_EVs = int(initial_data.get("speed_EVs", 0))
	definition.nature_id = int(initial_data.get("nature_id", 0))
	definition.ability_id = int(initial_data.get("ability_id", 0))
	definition.custom_move_ids = _to_move_enum_array(initial_data.get("custom_move_ids", []))
	definition.held_item_id = int(initial_data.get("held_item_id", 0))

	add_child(definition_editor)
	definition_editor.saved.connect(func(updated_definition: PokemonDefinition):
		on_confirm.call({
			"pokemon_id": int(updated_definition.pokemon_id),
			"level": int(updated_definition.level),
			"nickname": updated_definition.nickname,
			"gender": int(updated_definition.gender),
			"shiny": updated_definition.shiny,
			"is_wild": updated_definition.is_wild,
			"randomize_ivs": updated_definition.randomize_ivs,
			"hp_IVs": int(updated_definition.hp_IVs),
			"attack_IVs": int(updated_definition.attack_IVs),
			"defense_IVs": int(updated_definition.defense_IVs),
			"spAttack_IVs": int(updated_definition.spAttack_IVs),
			"spDefense_IVs": int(updated_definition.spDefense_IVs),
			"speed_IVs": int(updated_definition.speed_IVs),
			"randomize_evs": updated_definition.randomize_evs,
			"hp_EVs": int(updated_definition.hp_EVs),
			"attack_EVs": int(updated_definition.attack_EVs),
			"defense_EVs": int(updated_definition.defense_EVs),
			"spAttack_EVs": int(updated_definition.spAttack_EVs),
			"spDefense_EVs": int(updated_definition.spDefense_EVs),
			"speed_EVs": int(updated_definition.speed_EVs),
			"nature_id": int(updated_definition.nature_id),
			"ability_id": int(updated_definition.ability_id),
			"custom_move_ids": _to_move_enum_array(updated_definition.custom_move_ids),
			"held_item_id": int(updated_definition.held_item_id)
		})
	)
	definition_editor.open_for_definition(definition, dialog_title)

func _save_with_validation() -> void:
	print("[TrainerEditorWindow] _save_with_validation()")
	if display_name_line.text.strip_edges().is_empty():
		_show_warning("El nombre del trainer no puede estar vacío.")
		return

	if current_trainer_data == null:
		_show_warning("No hay datos de trainer para guardar")
		return

	if not _apply_form_to_trainer(current_trainer_data):
		return

	if save_embedded_mode:
		current_trainer_data.emit_changed()
		if refresh_callback.is_valid():
			refresh_callback.call()
		saved.emit(current_trainer_data, false)
		queue_free()
		return

	var target_path := _resolve_target_path()
	if target_path.is_empty():
		_show_warning("No se pudo determinar la ruta de guardado")
		return
	current_trainer_data.resource_path = target_path
	current_trainer_data.emit_changed()
	print("[TrainerEditorWindow] saving path=%s party_entries=%d intro_len=%d" % [target_path, party_entries.size(), intro_text.text.length()])

	var error := ResourceSaver.save(current_trainer_data, target_path)
	if error != OK:
		_show_warning("Error al guardar trainer: %s" % error_string(error))
		return

	_refresh_filesystem()
	var saved_resource := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	print("[TrainerEditorWindow] saved, reloaded=%s" % (saved_resource.get_class() if saved_resource else "null"))
	if saved_resource != null:
		var saved_party: Variant = saved_resource.get("party_data")
		var saved_party_count: int = saved_party.size() if saved_party is Array else -1
		if saved_party_count != party_entries.size():
			push_warning("TrainerEditor: party_data desincronizado tras guardar en %s (esperado=%d, guardado=%d)" % [target_path, party_entries.size(), saved_party_count])
		var expected_intro := intro_text.text
		var expected_defeat := defeat_text.text
		var expected_victory := victory_text.text
		if str(saved_resource.get("intro_text")) != expected_intro \
			or str(saved_resource.get("defeat_text")) != expected_defeat \
			or str(saved_resource.get("victory_text")) != expected_victory:
			push_warning("TrainerEditor: textos desincronizados tras guardar en %s" % target_path)
	if refresh_callback.is_valid():
		refresh_callback.call()
	saved.emit(saved_resource if saved_resource else current_trainer_data, was_new)
	queue_free()

func _apply_form_to_trainer(trainer_data: Resource) -> bool:
	trainer_data.set("trainer_id", int(id_spin.value))
	trainer_data.set("trainer_class_id", _get_selected_trainer_class_id())
	trainer_data.set("display_name", display_name_line.text.strip_edges())
	trainer_data.set("reward_money", int(reward_spin.value))
	trainer_data.set("double_battle", double_check.button_pressed)
	trainer_data.set("can_rematch", rematch_check.button_pressed)
	trainer_data.set("intro_text", intro_text.text)
	trainer_data.set("defeat_text", defeat_text.text)
	trainer_data.set("victory_text", victory_text.text)

	var def_script := load("res://Scripts/Resources/Classes/PokemonDefinition.gd")
	if def_script == null:
		_show_warning("No se pudo cargar PokemonDefinition.gd. No se guardó el trainer.")
		return false

	var party_data: Array = []
	for e in party_entries:
		var def: Resource = def_script.new()
		if def == null:
			_show_warning("No se pudo crear un PokemonDefinition. No se guardó el trainer.")
			return false
		def.set("pokemon_id", int(e.get("pokemon_id", 1)))
		def.set("level", int(e.get("level", 5)))
		def.set("nickname", str(e.get("nickname", "")))
		def.set("gender", int(e.get("gender", 0)))
		def.set("shiny", bool(e.get("shiny", false)))
		def.set("is_wild", bool(e.get("is_wild", false)))
		def.set("randomize_ivs", bool(e.get("randomize_ivs", false)))
		def.set("hp_IVs", int(e.get("hp_IVs", 0)))
		def.set("attack_IVs", int(e.get("attack_IVs", 0)))
		def.set("defense_IVs", int(e.get("defense_IVs", 0)))
		def.set("spAttack_IVs", int(e.get("spAttack_IVs", 0)))
		def.set("spDefense_IVs", int(e.get("spDefense_IVs", 0)))
		def.set("speed_IVs", int(e.get("speed_IVs", 0)))
		def.set("randomize_evs", bool(e.get("randomize_evs", false)))
		def.set("hp_EVs", int(e.get("hp_EVs", 0)))
		def.set("attack_EVs", int(e.get("attack_EVs", 0)))
		def.set("defense_EVs", int(e.get("defense_EVs", 0)))
		def.set("spAttack_EVs", int(e.get("spAttack_EVs", 0)))
		def.set("spDefense_EVs", int(e.get("spDefense_EVs", 0)))
		def.set("speed_EVs", int(e.get("speed_EVs", 0)))
		def.set("nature_id", int(e.get("nature_id", 0)))
		def.set("ability_id", int(e.get("ability_id", 0)))
		def.set("custom_move_ids", _to_move_enum_array(e.get("custom_move_ids", [])))
		def.set("held_item_id", int(e.get("held_item_id", 0)))
		party_data.append(def)
	trainer_data.set("party_data", party_data)
	return true

func _entry_get(entry: Variant, key: String, default_value: Variant) -> Variant:
	if entry == null:
		return default_value
	if entry is Dictionary:
		return entry.get(key, default_value)
	if entry is Object:
		var value = entry.get(key)
		return value if value != null else default_value
	return default_value

func _to_move_enum_array(raw_value: Variant) -> Array[MovesEnum.Values]:
	var result: Array[MovesEnum.Values] = []
	if not (raw_value is Array):
		return result
	for value in raw_value:
		result.append(int(value) as MovesEnum.Values)
	return result

func _resolve_target_path() -> String:
	if current_mode == EditorMode.EDIT:
		if not original_resource_path.is_empty():
			return original_resource_path
		if current_trainer_data != null and not current_trainer_data.resource_path.is_empty():
			return current_trainer_data.resource_path
		return ""

	var file_stub := _sanitize_filename(display_name_line.text)
	var target_path := "res://Resources/Trainers/%s.tres" % file_stub
	var i := 1
	while ResourceLoader.exists(target_path):
		target_path = "res://Resources/Trainers/%s_%d.tres" % [file_stub, i]
		i += 1
	return target_path

func _sanitize_filename(raw_name: String) -> String:
	var clean := raw_name.strip_edges()
	clean = clean.replace("/", "-").replace("\\", "-").replace(":", "-")
	clean = clean.replace("*", "").replace("?", "").replace("\"", "")
	clean = clean.replace("<", "").replace(">", "").replace("|", "")
	clean = clean.replace(".", "")
	if clean == "":
		clean = "trainer"
	return clean

func _get_next_trainer_id() -> int:
	var dir_path := "res://Resources/Trainers"
	var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
	if dir == null:
		dir = DirAccess.open(dir_path)
		if dir == null:
			return 1

	var max_id := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := dir_path + "/" + file_name
			var trainer_data := load(path)
			if trainer_data:
				max_id = maxi(max_id, int(trainer_data.get("trainer_id")))
		file_name = dir.get_next()
	dir.list_dir_end()
	return max_id + 1

func _show_warning(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Aviso"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _load_trainer_classes() -> void:
	trainer_classes.clear()
	if class_option == null:
		return
	class_option.clear()
	class_option.add_item("0 - Sin clase", 0)

	var dir_paths := [
		"res://Resources/Trainer Classes",
		"res://Resources/Data/TrainerClasses"
	]

	for dir_path in dir_paths:
		var dir := DirAccess.open(ProjectSettings.globalize_path(dir_path))
		if dir == null:
			dir = DirAccess.open(dir_path)
		if dir == null:
			continue

		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var path := "%s/%s" % [dir_path, file_name]
				var trainer_class := load(path)
				if trainer_class != null:
					var class_id := int(trainer_class.get("id"))
					var display_name := str(trainer_class.get("display_name"))
					if display_name.is_empty():
						display_name = str(trainer_class.get("internal_name"))
					if display_name.is_empty():
						display_name = file_name.get_basename()
					trainer_classes.append({
						"id": class_id,
						"name": display_name
					})
			file_name = dir.get_next()
		dir.list_dir_end()

	trainer_classes.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)

	var seen_ids := {0: true}
	for trainer_class in trainer_classes:
		var class_id := int(trainer_class.get("id", 0))
		if seen_ids.has(class_id):
			continue
		seen_ids[class_id] = true
		var class_label_text := str(trainer_class.get("name", ""))
		class_option.add_item("%d - %s" % [class_id, class_label_text], class_id)

	# Compatibilidad: también mostrar IDs definidos en TrainerClassEnum
	# aunque no existan recursos en "Resources/Trainer Classes".
	for enum_key in TrainerClassEnum.Values.keys():
		var enum_id: int = int(TrainerClassEnum.Values[enum_key])
		if seen_ids.has(enum_id):
			continue
		seen_ids[enum_id] = true
		var enum_label := "%s (%s)" % [
			TrainerClassEnum.get_display_name(enum_id as TrainerClassEnum.Values),
			str(enum_key).replace("_", " ").to_lower().capitalize()
		]
		class_option.add_item("%d - %s" % [enum_id, enum_label], enum_id)

func _select_trainer_class_id(class_id: int) -> void:
	if class_option == null:
		if class_spin_fallback != null:
			class_spin_fallback.value = class_id
		return
	for i in range(class_option.item_count):
		if class_option.get_item_id(i) == class_id:
			class_option.select(i)
			return
	var fallback_label := TrainerClassEnum.get_display_name(class_id as TrainerClassEnum.Values)
	if fallback_label.strip_edges().is_empty():
		fallback_label = "Clase desconocida"
	class_option.add_item("%d - %s" % [class_id, fallback_label], class_id)
	class_option.select(class_option.item_count - 1)

func _get_selected_trainer_class_id() -> int:
	if class_option == null or class_option.item_count == 0:
		if class_spin_fallback != null:
			return int(class_spin_fallback.value)
		return 0
	var selected_index := class_option.selected
	if selected_index < 0:
		return 0
	return class_option.get_item_id(selected_index)

func _refresh_filesystem() -> void:
	var filesystem = EditorInterface.get_resource_filesystem()
	if filesystem:
		filesystem.scan()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()
