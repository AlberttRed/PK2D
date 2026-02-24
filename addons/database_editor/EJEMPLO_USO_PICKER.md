# Ejemplo de Uso: Resource Picker

## Uso Básico desde Event Editor

```gdscript
# En un EventCommand editor (ej: start_battle_event_command_editor.gd)

# Importar la API
const ResourcePickerAPI = preload("res://addons/database_editor/resource_picker_api.gd")

# Abrir picker para seleccionar un Pokémon
func _on_select_pokemon_button_pressed() -> void:
    var picker = ResourcePickerAPI.open_pokemon_picker(
        initial_selection = current_pokemon_id,  # ID actual (opcional)
        callback = _on_pokemon_selected,         # Callback cuando se confirma
        cancel_callback = _on_picker_cancelled   # Callback cuando se cancela (opcional)
    )

# Callback cuando se selecciona un Pokémon
func _on_pokemon_selected(result: ResourcePickerResult) -> void:
    current_pokemon_id = result.resource_id
    pokemon_name_label.text = result.display_name
    # Actualizar UI del command con el nuevo valor

# Callback cuando se cancela
func _on_picker_cancelled() -> void:
    print("Selección cancelada")

# Abrir picker para seleccionar un Movimiento
func _on_select_move_button_pressed() -> void:
    ResourcePickerAPI.open_move_picker(
        initial_selection = current_move_id,
        callback = func(result: ResourcePickerResult):
            current_move_id = result.resource_id
            move_name_label.text = result.display_name
    )

# Abrir picker para seleccionar un Item
func _on_select_item_button_pressed() -> void:
    ResourcePickerAPI.open_item_picker(
        initial_selection = current_item_id,
        callback = func(result: ResourcePickerResult):
            current_item_id = result.resource_id
            item_name_label.text = result.display_name
    )
```

## Flujo Completo

1. Usuario hace clic en botón "Seleccionar Pokémon" en el EventCommand editor
2. Se abre el DatabaseEditor en modo picker (solo pestaña Pokémon)
3. Usuario puede:
   - Buscar y seleccionar un Pokémon existente
   - Crear un nuevo Pokémon (se guarda y queda seleccionado)
   - Editar un Pokémon (se guarda y vuelve al picker con selección mantenida)
   - Duplicar un Pokémon (se guarda y queda seleccionado)
4. Usuario presiona "Seleccionar" → se emite `resource_selected` con el resultado
5. El EventCommand actualiza su campo con el ID y nombre
6. El picker se cierra automáticamente

## Estructura de ResourcePickerResult

```gdscript
var result: ResourcePickerResult
result.resource_id      # int: ID del recurso
result.resource_path    # String: Path del archivo .tres
result.display_name     # String: Nombre para mostrar
result.resource_type    # String: "POKEMON", "MOVE", "ITEM"
result.resource         # Resource: Recurso completo (opcional)
```

