@tool
extends RefCounted
class_name ResourcePickerAPI

## API estática para abrir el Resource Picker desde otros editores
## Permite seleccionar recursos (Pokemon, Move, Item) desde EventCommands u otros editores

const DATABASE_EDITOR_SCENE_PATH := "res://addons/database_editor/database_editor.tscn"

## Tipos de recursos soportados
## Extensible: Para añadir nuevos tipos, actualizar aquí y en DatabaseEditor.ResourceType
enum ResourceType {
	POKEMON,
	MOVE,
	ITEM,
	TRAINER,
	TYPE,
	ABILITY,
	AILMENT,
	WEATHER,
}

## Abre el DatabaseEditor en modo picker
## @param resource_type: Tipo de recurso a seleccionar (ResourceType.POKEMON, MOVE, ITEM)
## @param initial_selection: ID o path del recurso preseleccionado (opcional)
## @param callback: Callable que se llamará con ResourcePickerResult cuando se confirme la selección
## @param cancel_callback: Callable opcional que se llamará si se cancela
## @return: La ventana del DatabaseEditor en modo picker (para referencia si es necesario)
static func open_resource_picker(
	resource_type: ResourceType,
	initial_selection = null,
	callback: Callable = Callable(),
	cancel_callback: Callable = Callable()
) -> Window:
	if not Engine.is_editor_hint():
		push_error("[ResourcePickerAPI] Solo disponible en el editor")
		return null

	# Cargar la escena del DatabaseEditor
	var database_editor_scene = load(DATABASE_EDITOR_SCENE_PATH) as PackedScene
	if not database_editor_scene:
		push_error("[ResourcePickerAPI] No se pudo cargar database_editor.tscn")
		return null

	# Instanciar la ventana
	var window = database_editor_scene.instantiate()
	if not window:
		push_error("[ResourcePickerAPI] No se pudo instanciar DatabaseEditor")
		return null

	# Añadir al base_control del editor
	var base_control = EditorInterface.get_base_control()
	base_control.add_child(window)

	# Configurar modo picker
	if window.has_method("open_picker_mode"):
		window.open_picker_mode(resource_type, initial_selection)
	else:
		push_error("[ResourcePickerAPI] DatabaseEditor no tiene método open_picker_mode")
		window.queue_free()
		return null

	# Conectar callbacks
	if callback.is_valid():
		if window.has_signal("resource_selected"):
			window.resource_selected.connect(callback)

	if cancel_callback.is_valid():
		if window.has_signal("picker_cancelled"):
			window.picker_cancelled.connect(cancel_callback)

	# Mostrar la ventana
	window.popup_centered(Vector2i(1200, 800))

	return window

## Abre el picker para seleccionar un Pokémon
static func open_pokemon_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.POKEMON, initial_selection, callback, cancel_callback)

## Abre el picker para seleccionar un Movimiento
static func open_move_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.MOVE, initial_selection, callback, cancel_callback)

## Abre el picker para seleccionar un Item
static func open_item_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.ITEM, initial_selection, callback, cancel_callback)

## Abre el picker para seleccionar un Trainer
static func open_trainer_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.TRAINER, initial_selection, callback, cancel_callback)

## Abre el picker para seleccionar un Type
static func open_type_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.TYPE, initial_selection, callback, cancel_callback)

## Abre el picker para seleccionar una Ability
static func open_ability_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.ABILITY, initial_selection, callback, cancel_callback)

## Abre el picker para seleccionar un Ailment
static func open_ailment_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.AILMENT, initial_selection, callback, cancel_callback)

## Abre el picker para seleccionar un Weather
static func open_weather_picker(initial_selection = null, callback: Callable = Callable(), cancel_callback: Callable = Callable()) -> Window:
	return open_resource_picker(ResourceType.WEATHER, initial_selection, callback, cancel_callback)

