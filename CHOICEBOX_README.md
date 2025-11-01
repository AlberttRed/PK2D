# Sistema ChoiceBox - Selección de Opciones

## Descripción
Sistema de selección de opciones interactivo para eventos, similar al sistema de opciones de los juegos Pokémon.

## Archivos Creados

### Scripts
- `Scripts/UI/MessageBox/ChoiceBox.gd` - Lógica del ChoiceBox
- `Scripts/TestChoiceBox.gd` - Script de prueba

### Escenas
- `Scenes/UI/MessageBox/ChoiceBox.tscn` - UI del ChoiceBox
- `Scenes/TestChoiceBox.tscn` - Escena de prueba

## Características Implementadas

### ✅ Parte Visual Completada

1. **ChoiceBox UI**
   - Panel con estilo visual coherente con MessageBox
   - Posicionado en la parte derecha de la pantalla
   - Ajuste automático de tamaño según número de opciones
   - Cursor triangular para indicar selección

2. **Navegación**
   - ↑ (ui_up): Navegar hacia arriba
   - ↓ (ui_down): Navegar hacia abajo
   - Navegación circular (al llegar al final, vuelve al inicio)

3. **Selección**
   - A/Enter (ui_accept): Confirmar selección
   - B/Esc (ui_cancel): Cancelar selección (devuelve -1)

4. **Integración**
   - Integrado en GUI.tscn
   - Método `GUI.show_choices(options: Array[String]) -> int`
   - Señales: `choice_made(index: int)`, `choice_cancelled()`

## Cómo Usar

### Desde el GUI
```gdscript
# Ejemplo básico
var opciones = ["Sí", "No", "Tal vez"]
var seleccion = await GUI.show_choices(opciones)

if seleccion == 0:
    print("Seleccionó Sí")
elif seleccion == 1:
    print("Seleccionó No")
elif seleccion == 2:
    print("Seleccionó Tal vez")
elif seleccion == -1:
    print("Canceló la selección")
```

### Combinado con MessageBox
```gdscript
# Mostrar mensaje y luego opciones
await GUI.msg.show_input("¿Te gusta este juego?")
var respuesta = await GUI.show_choices(["Sí", "No"])

if respuesta == 0:
    await GUI.msg.show_input("¡Qué bien!")
else:
    await GUI.msg.show_input("Oh, vaya...")
```

## Cómo Probar

### Opción 1: Escena de Prueba
1. Abre Godot
2. Ejecuta la escena `Scenes/TestChoiceBox.tscn` (F6)
3. Se mostrará un mensaje seguido de un ChoiceBox con 4 opciones
4. Usa las flechas ↑↓ para navegar
5. Presiona Enter para seleccionar
6. Presiona ESC para cancelar

### Opción 2: Desde el Juego Principal
Puedes integrar el ChoiceBox en cualquier evento existente:
```gdscript
# En cualquier EventCommand o script
var opciones = ["Primera opción", "Segunda opción"]
var seleccion = await GUI.show_choices(opciones)
# Hacer algo según la selección...
```

## Estilo Visual

El ChoiceBox usa el mismo estilo que el MessageBox:
- Fuente: pkmnhgss.ttf (tamaño 26)
- Colores: Gris oscuro con sombra clara
- Panel: HGSS_MessageBox_Style.tres
- Cursor: Triángulo gris oscuro

## Próximos Pasos (PBI 482)

Una vez confirmado que el ChoiceBox funciona correctamente, los siguientes pasos serían:

1. **EventBranch Resource**
   - Crear `Scripts/Resources/EventBranch.gd`
   - Estructura: `label: String`, `commands: Array[EventCommand]`

2. **ShowChoicesCommand**
   - Crear `Scripts/Events/Commands/ShowChoicesCommand.gd`
   - Propiedades: `choices: Array[String]`, `branches: Array[EventBranch]`
   - Lógica: Mostrar ChoiceBox → Ejecutar branch correspondiente

3. **Integración con EventSystem**
   - El EventController debe pausar el flujo
   - Ejecutar solo los comandos del branch seleccionado
   - Continuar con el flujo principal después

4. **Características Opcionales**
   - Guardar resultado en variable global
   - Animación de apertura/cierre
   - Soporte para diferentes posiciones del ChoiceBox

## Notas Técnicas

- El ChoiceBox usa las señales del `SignalManager` para input
- El input se habilita/deshabilita automáticamente para evitar conflictos
- El método `show_choices()` es asíncrono (usa `await`)
- Compatible con el sistema de input del GUI existente

