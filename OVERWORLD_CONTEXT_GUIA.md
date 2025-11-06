# Guía de OverworldContext - Arquitectura y Uso

## 📋 Resumen

El **OverworldContext** es un sistema de gestión de dependencias que centraliza el acceso a los sistemas del Overworld, eliminando el acoplamiento global mediante `get_tree().get_node_in_group()` y reduciendo el uso innecesario de `SignalManager`.

## 🎯 Objetivos

1. **Reducir acoplamiento**: Eliminar búsquedas globales con `get_tree().get_node_in_group()`
2. **Mejorar rendimiento**: Evitar búsquedas en el árbol de nodos en cada llamada
3. **Facilitar testing**: Inyección de dependencias permite mock y testing unitario
4. **Clarificar arquitectura**: Relaciones explícitas entre sistemas
5. **Limitar SignalManager**: Usarlo solo para comunicación entre capas (GUI, Audio, Fade)

## 🏗️ Arquitectura

### Estructura de clases

```
OverworldCoordinator (Overworld.gd)
├── OverworldContext (nuevo)
│   ├── systems: Dictionary
│   ├── map_system: MapSystem
│   ├── warp_system: WarpSystem
│   ├── mo_system: MOSystem
│   ├── event_system: EventSystem
│   ├── world_system: WorldSystem
│   └── player: Node
├── WorldSystem
├── MapSystem
├── WarpSystem
├── MOSystem
└── EventSystem
```

### Flujo de inicialización

```
1. OverworldCoordinator._ready()
   ├── Crear OverworldContext
   ├── await get_tree().process_frame (esperar a hijos)
   ├── _register_systems_in_context()
   │   ├── Registrar World, Map, Event, Warp, MO
   │   └── Registrar Player (si existe)
   ├── _inject_dependencies()
   │   └── Inyectar context a todos los sistemas
   └── context.validate() y print_summary()
```

## 📖 Uso del OverworldContext

### 1. En Sistemas del Overworld

Los sistemas reciben el contexto inyectado desde `OverworldCoordinator`:

```gdscript
# MapSystem.gd, WarpSystem.gd, MOSystem.gd, EventSystem.gd
var context: OverworldContext = null

func some_method():
    # Método preferido: usar context
    var player = context.get_player()
    var map_sys = context.get_map_system()

    # ❌ NO HACER: búsqueda global (deprecated)
    # var player = get_tree().get_first_node_in_group("Player")
```

### 2. En Comandos de Eventos

Los comandos acceden al contexto a través del `EventController`:

```gdscript
# WarpCommand.gd, UseMOCommand.gd, BlockPlayerCommand.gd
func execute(context: Node) -> void:
    # Obtener OverworldContext del EventController
    var overworld_context = _get_overworld_context(context)

    if overworld_context:
        var player = overworld_context.get_player()
        # usar player...
    else:
        # Fallback temporal para compatibilidad
        var player = context.get_tree().get_first_node_in_group("Player")

func _get_overworld_context(context: Node) -> OverworldContext:
    if context is EventController:
        var event_system = context.get_parent() as EventSystem
        if event_system and event_system.context:
            return event_system.context
    return null
```

### 3. Control del Player (API Directa)

En lugar de usar `SignalManager.player_control_blocked/unblocked`, se prefiere el control directo:

```gdscript
# ✅ MÉTODO PREFERIDO: Control directo
var player = context.get_player()
player.block_controls()    # Bloquear
player.unblock_controls()  # Desbloquear

# ❌ DEPRECATED: SignalManager (solo compatibilidad temporal)
SignalManager.player_control_blocked.emit()
SignalManager.player_control_unblocked.emit()
```

**API del Player:**
- `block_controls()`: Bloquea controles (contador anidado)
- `unblock_controls()`: Desbloquea controles (decrementa contador)
- `force_unblock_controls()`: Fuerza desbloqueo inmediato
- `are_controls_blocked()`: Verifica estado

### 4. Registro del Player dinámico

Cuando el Player se carga dinámicamente (desde MapSystem):

```gdscript
# MapSystem.gd
func load_player() -> bool:
    var player_instance = player_scene.instantiate()
    add_child(player_instance)
    player = player_instance

    # Registrar en el contexto
    if context:
        context.register_system("Player", player_instance)
        print("MapSystem: Jugador registrado en el contexto")

    # Inyectar contexto al jugador
    if player_instance.has_method("set_context"):
        player_instance.set_context(context)

    return true
```

## 🔄 Compatibilidad y Migración

### Estrategia de migración gradual

El sistema está diseñado para **coexistir** con el código antiguo:

1. **OverworldContext activo**: Todos los sistemas reciben el contexto
2. **Fallbacks temporales**: Si el contexto no está disponible, se usa el método antiguo
3. **Warnings informativos**: Se notifica cuando se usa el fallback
4. **SignalManager limitado**: Se mantiene para GUI, Audio, Fade (capas diferentes)

### Ejemplo de código compatible

```gdscript
# Código con fallback temporal
var player: Node = null
if context:
    player = context.get_player()  # Método preferido
else:
    player = get_tree().get_first_node_in_group("Player")  # Fallback

if not player:
    push_error("No se encontró el jugador")
    return
```

### Plan de migración futuro

A medida que se trabaje en nuevos PBIs, se irá migrando el código restante:

1. **Prioridad Alta**: Sistemas principales (✅ Ya migrados: MapSystem, WarpSystem, MOSystem, EventSystem, Player)
2. **Prioridad Media**: Comandos de eventos (✅ Ejemplos migrados: WarpCommand, UseMOCommand, BlockPlayerCommand, UnblockPlayerCommand)
3. **Prioridad Baja**: Scripts auxiliares (GridMotion, Occupancy, etc.)

## 🚫 Cuándo NO usar OverworldContext

**SignalManager sigue siendo el método correcto para:**

1. **Comunicación con GUI**: `message_requested`, `choice_requested`
2. **Comunicación con Audio**: `play_sound`, `play_music`
3. **Comunicación con Fade**: `fade_requested`, `fade_finished`
4. **Eventos de alto nivel**: `battle_requested`, `battle_finished`
5. **Eventos globales de juego**: `event_started`, `event_finished`

**Estos NO deben usar OverworldContext porque cruzan capas arquitectónicas.**

## 📝 Checklist para nuevos sistemas

Al crear o modificar un sistema del Overworld:

- [ ] Añadir variable `var context: OverworldContext = null`
- [ ] Registrar el sistema en `OverworldCoordinator._register_systems_in_context()`
- [ ] Inyectar contexto en `OverworldCoordinator._inject_dependencies()`
- [ ] Usar `context.get_X_system()` en lugar de `get_node_in_group()`
- [ ] Si es Player: usar API directa (`block_controls()`) en lugar de SignalManager
- [ ] Mantener fallback temporal para compatibilidad
- [ ] Documentar el cambio

## 🎯 Beneficios observados

1. **Rendimiento**: Acceso O(1) vs búsqueda en árbol O(n)
2. **Claridad**: Dependencias explícitas en lugar de implícitas
3. **Testing**: Posibilidad de inyectar mocks para tests unitarios
4. **Mantenibilidad**: Cambios localizados, no dispersos
5. **Debug**: Trazabilidad de llamadas entre sistemas

## 📚 Referencias

- **PBI 493**: Implementación inicial del OverworldContext
- `Scripts/Overworld/Core/OverworldContext.gd`: Clase principal
- `Scripts/Overworld/Overworld.gd`: OverworldCoordinator
- `Scripts/Overworld/Actors/Player.gd`: API de control directo

---

**Última actualización**: PBI 493 - Noviembre 2025

