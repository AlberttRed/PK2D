# Sistema de Máquinas Ocultas (MOSystem)

## Descripción General

El **MOSystem** es un sistema centralizado dentro del Overworld que gestiona la lógica y validación del uso de Máquinas Ocultas (MOs) como CORTE, SURF, FUERZA, DESTELLO o GOLPE ROCA.

El sistema se encarga de:
- ✅ Verificar si la acción puede ejecutarse
- ✅ Aplicar el efecto lógico correspondiente (marcar evento como eliminado, cambiar flags, etc.)
- ✅ Comunicar el resultado mediante señales al resto de sistemas

**IMPORTANTE:** El MOSystem **NO** gestiona mensajes ni animaciones visuales. Estos se controlan desde los eventos usando comandos como `ShowMessageCommand` y `PlayAnimationCommand`.

---

## Arquitectura del Sistema

### 1. MOSystem (Nodo en Overworld)

**Ubicación:** `/Scripts/Overworld/Core/MOSystem.gd`

Es el nodo principal que se encuentra en la escena `Overworld.tscn` al mismo nivel que `WarpSystem`, `MapSystem`, y `EventSystem`.

**Responsabilidades:**
- Escuchar peticiones de MO mediante `SignalManager.mo_requested`
- Validar si la MO puede ser usada (contexto, permisos, etc.)
- Ejecutar el efecto lógico de la MO
- Emitir señales de resultado (`mo_completed` o `mo_failed`)

**Métodos principales:**
```gdscript
# Registrar una nueva MO
register_mo_action(mo_type: String, action: Resource) -> void

# Verificar si una MO está registrada
has_mo_action(mo_type: String) -> bool

# Obtener información del estado actual
get_current_mo_info() -> Dictionary
```

---

### 2. MOAction (Clase Base)

**Ubicación:** `/Scripts/Overworld/Core/MOAction.gd`

Clase base abstracta que define la interfaz para todas las acciones de MO específicas.

**Métodos a sobrescribir:**

```gdscript
# Verifica si el jugador puede usar esta MO
func can_use(player: Node, target: Node) -> bool:
    # Implementar validación específica
    return true/false

# Ejecuta el efecto lógico de la MO
func execute(player: Node, target: Node) -> Dictionary:
    # Implementar lógica específica
    return {"success": true/false, "data": {...}}
```

**Ejemplo de implementación (CUT):**

```gdscript
# Scripts/Overworld/Core/MOActions/CutAction.gd
extends MOAction
class_name CutAction

func _init():
    mo_name = "CUT"
    description = "Corta árboles pequeños que bloquean el camino"

func can_use(player: Node, target: Node) -> bool:
    # Verificar que el jugador tenga la MO
    if not player_has_mo("CUT"):
        return false

    # Verificar que el target sea un evento con el flag "cuttable"
    if not target.has_meta("cuttable"):
        return false

    return true

func execute(player: Node, target: Node) -> Dictionary:
    # Marcar el evento como eliminado
    if target.has_method("set_enabled"):
        target.set_enabled(false)

    # Establecer un flag global para registrar la acción
    var event_id = target.name
    GameStateManager.set_event_flag("cut_%s" % event_id, true)

    return {"success": true, "data": {"event_id": event_id}}
```

---

### 3. UseMOCommand (Comando de Evento)

**Ubicación:** `/Scripts/Events/Commands/UseMOCommand.gd`

Comando que se usa en los eventos para solicitar el uso de una MO.

**Propiedades configurables:**

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `mo_type` | MOTypeEnum.Type | Tipo de MO a usar (enum) |
| `target_path` | NodePath | Path al nodo target (opcional). Si está vacío, usa el evento de origen |

**Flujo de ejecución:**
1. Obtiene el target (evento o nodo especificado)
2. Emite `SignalManager.mo_requested`
3. Espera respuesta (`mo_completed` o `mo_failed`)
4. Continúa ejecución del evento

---

### 4. Señales (SignalManager)

**Ubicación:** `/Scripts/AutoLoads/SignalManager.gd`

```gdscript
# Petición de uso de MO
signal mo_requested(mo_type: String, target: Node)

# MO completada con éxito
signal mo_completed(mo_type: String, target: Node)

# MO falló
signal mo_failed(mo_type: String, target: Node, reason: String)
```

---

## Ejemplo Completo: Implementar CORTE

### 1. Crear la clase CutAction

```gdscript
# Scripts/Overworld/Core/MOActions/CutAction.gd
extends MOAction
class_name CutAction

func _init():
    mo_name = "CUT"
    description = "Corta árboles pequeños"

func can_use(player: Node, target: Node) -> bool:
    # Verificar que el jugador tenga CORTE
    if not player_has_mo("CUT"):
        return false

    # Verificar que el target tenga la meta "cuttable"
    if not target.has_meta("cuttable"):
        return false

    return true

func execute(player: Node, target: Node) -> Dictionary:
    # Desactivar el evento
    if target.has_method("set_enabled"):
        target.set_enabled(false)

    # Marcar flag global
    GameStateManager.set_event_flag("cut_%s" % target.name, true)

    return {"success": true, "data": {"removed": target.name}}
```

### 2. Registrar la MO en MOSystem

Editar `/Scripts/Overworld/Core/MOSystem.gd` en `_initialize_mo_actions()`:

```gdscript
func _initialize_mo_actions() -> void:
    # Registrar CORTE
    var cut_action = preload("res://Scripts/Overworld/Core/MOActions/CutAction.gd").new()
    register_mo_action("CUT", cut_action)
```

### 3. Configurar el Evento en el Mapa

1. Crear un nodo `Event` para el árbol cortable
2. Añadir metadata `cuttable = true` en el inspector
3. Configurar **EventPage 1** con:
   - Trigger: `ACTION_BUTTON`
   - Conditions: (ninguna)
4. Añadir comandos en orden:

```
1. ShowMessageCommand: "¡Hay un árbol cortable!"
2. ShowMessageCommand: "¿Usar CORTE?"
3. UseMOCommand:
   - mo_type: MOTypeEnum.Type.CUT
   - target_path: (vacío para usar el evento de origen)
4. ShowMessageCommand: "¡El árbol fue cortado!"
5. PlayAnimationCommand: "corte_arbol" (animación visual)
6. SetSelfSwitchCommand: (A = true, para desactivar el árbol)
```

---

## Flujo de Ejecución Completo

```
1. Jugador interactúa con evento (botón acción)
   ↓
2. Evento ejecuta ShowMessageCommand ("¿Usar CORTE?")
   ↓
3. Evento ejecuta UseMOCommand
   ↓
4. UseMOCommand emite SignalManager.mo_requested("CUT", target)
   ↓
5. MOSystem recibe la petición
   ↓
6. MOSystem valida con CutAction.can_use()
   ├─ Si falla → emite mo_failed
   └─ Si pasa → ejecuta CutAction.execute()
       ↓
7. MOSystem emite mo_completed/mo_failed
   ↓
8. UseMOCommand recibe la señal y continúa
   ↓
9. Evento continúa con mensajes/animaciones visuales
```

---

## Integración con EventSystem

El `UseMOCommand` es **asíncrono** (`is_async() = true`), lo que significa que:

- El `EventController` se **pausa** hasta que el comando termine
- El comando espera la señal `mo_completed` o `mo_failed`
- Solo entonces llama a `context.continue_execution()`
- El evento continúa con el siguiente comando

Esto garantiza que las animaciones y mensajes posteriores solo se ejecuten después de que la MO se complete.

---

## Próximos Pasos

Para cada nueva MO que se implemente, se creará un PBI específico:

- **PBI-428:** Implementar CORTE (CUT)
- **PBI-429:** Implementar SURF
- **PBI-430:** Implementar FUERZA (STRENGTH)
- **PBI-431:** Implementar DESTELLO (FLASH)
- **PBI-432:** Implementar GOLPE ROCA (ROCK SMASH)

Cada PBI incluirá:
1. Crear la clase específica que hereda de `MOAction`
2. Registrarla en `MOSystem._initialize_mo_actions()`
3. Crear eventos de prueba en un mapa de test
4. Documentar comportamiento específico

---

## Notas de Diseño

### ¿Por qué no es un Autoload?

El MOSystem es un **nodo del Overworld**, no un autoload, porque:
- Solo es necesario durante el modo Overworld
- Se libera de memoria al salir del Overworld (ej: en batalla)
- Mantiene consistencia con otros sistemas (WarpSystem, MapSystem)

### ¿Por qué separar lógica y visuales?

Separar la lógica (MOSystem) de los visuales (eventos) permite:
- **Reutilización:** La misma MO puede tener diferentes presentaciones visuales
- **Flexibilidad:** Fácil modificar mensajes y animaciones sin tocar la lógica
- **Testeo:** Probar la lógica sin depender de animaciones
- **Modularidad:** Cada sistema tiene una responsabilidad clara

---

## Troubleshooting

### La MO no se ejecuta

1. Verificar que la MO está registrada en `MOSystem._initialize_mo_actions()`
2. Verificar que `can_use()` retorna `true`
3. Revisar logs en la consola para errores

### El evento no continúa después de usar la MO

1. Verificar que `UseMOCommand` llama a `context.continue_execution()`
2. Verificar que las señales se emiten correctamente
3. Asegurarse de que no hay timeout (10 segundos máximo)

### El target no se elimina

1. Verificar `remove_target_on_success = true` en `UseMOCommand`
2. Verificar que el target tiene el método `set_enabled()` o `queue_free()`
3. Comprobar que la MO se completó con éxito

---

## Créditos

**PBI-427:** Sistema base de MOs (MOSystem)
**Implementado:** Noviembre 2025
**Estado:** ✅ Completado


