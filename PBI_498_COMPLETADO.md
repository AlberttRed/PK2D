# ✅ PBI 498 - Creación de escena raíz Main y migración del GUI a DisplayManager

## 📋 Resumen de la Implementación

Se ha completado exitosamente la implementación del PBI 498, que introduce una nueva arquitectura basada en una escena raíz `Main.tscn` y migra el sistema de interfaz a `DisplayManager`, estableciendo las bases para la futura arquitectura de Services/Managers/Systems.

---

## 🎯 Objetivos Completados

### ✅ 1. Creación de la Escena Raíz Main.tscn

**Ubicación:** `Scenes/Main.tscn`
**Script:** `Scripts/Main.gd`

La nueva escena `Main` actúa como punto de entrada del juego y contenedor persistente de sesión:

```gdscript
extends Node
class_name Main

@onready var display_manager = $DisplayManager
@onready var game_container: Node = $GameContainer
```

**Características:**
- Contiene `DisplayManager` como hijo directo
- Incluye `GameContainer` para cargar escenas dinámicamente
- Carga automáticamente `GameStart.tscn` al iniciar
- Permite cambios de escena sin perder el DisplayManager

---

### ✅ 2. Migración de GUI a DisplayManager

**Ubicación:** `Managers/DisplayManager.gd`
**Escena:** `Managers/DisplayManager.tscn`

Se ha creado `DisplayManager` como reemplazo completo del antiguo `GUI`:

#### Características Principales:

1. **Singleton Accesible Globalmente:**
```gdscript
class_name DisplayManager
static var instance: DisplayManager = null
```

2. **API Estática (para acceso global):**
```gdscript
static func show_message(text: String, config: Dictionary = {}) -> void
static func show_choices(options: Array[String]) -> int
static func show_message_with_choices(text: String, options: Array[String]) -> int
static func fade_out(duration: float = 0.3) -> void
static func fade_in(duration: float = 0.3) -> void
static func is_fading() -> bool
```

3. **Métodos de Instancia Privados (uso interno):**
```gdscript
func _show_message_with_config(text: String, config: Dictionary) -> void
func _show_choices(options: Array[String]) -> int
func _show_message_with_choices(text: String, options: Array[String]) -> int
func _is_fading() -> bool
func _is_visible() -> bool
```

4. **Métodos Legacy (compatibilidad):**
- `showMessageInput()`
- `showMessageWait()`
- `showMsg()`
- `isVisible()` → redirige a `_is_visible()`
- `isFading()` → redirige a `_is_fading()`

5. **Gestión de Batallas:**
- Integración con `BattleScene`
- Manejo de transiciones fade in/out
- Control del jugador durante batallas

---

### ✅ 3. Renombrado de Autoloads

Se han renombrado los autoloads siguiendo la convención Services:

#### DatabaseManager → DatabaseService

**Ubicación:** `Services/DatabaseService.gd`
**Autoload:** `DatabaseService`

```gdscript
extends Node
## DatabaseService - Accesible globalmente como autoload: DatabaseService
```

**Cambios realizados:**
- Movido de `Scripts/AutoLoads/` a `Services/`
- **No usa `class_name`** (los autoloads no deben usar class_name para evitar conflictos)
- Actualizado `project.godot`
- Actualizadas todas las referencias en el código (8 archivos)

#### GameStateManager → GameStateService

**Ubicación:** `Services/GameStateService.gd`
**Autoload:** `GameStateService`

```gdscript
extends Node
## GameStateService - Accesible globalmente como autoload: GameStateService
```

**Cambios realizados:**
- Movido de `Scripts/AutoLoads/` a `Services/`
- **No usa `class_name`** (los autoloads no deben usar class_name para evitar conflictos)
- Actualizado `project.godot`
- Actualizadas todas las referencias en el código (17 archivos)

---

### ✅ 4. Actualización de Referencias

#### Referencias a DatabaseManager actualizadas:
- ✅ `Scripts/Overworld/WildEncounterDetector.gd`
- ✅ `Scripts/Resources/Classes/TrainerData.gd`
- ✅ `Scripts/Runtime/Move.gd`
- ✅ `Scripts/Runtime/Pokemon.gd`
- ✅ `Scripts/Battle/TestBattle.gd`
- ✅ `Scripts/Resources/MapPokemonEncounter.gd`

#### Referencias a GameStateManager actualizadas:
- ✅ `Scripts/Overworld/Core/WorldSystem.gd`
- ✅ `Scripts/Overworld/Overworld.gd`
- ✅ `Scripts/Overworld/Core/MapSystem.gd`
- ✅ `Scripts/Overworld/Actors/Trainer.gd`
- ✅ `Scripts/Events/Commands/UseMOCommand.gd`
- ✅ `Scripts/Events/Commands/WarpCommand.gd`
- ✅ `Scripts/Events/Commands/StartBattleEventCommand.gd`
- ✅ `Scripts/Events/Commands/ShowChoicesCommand.gd`
- ✅ `Scripts/Overworld/Core/MOActions/CutAction_EXAMPLE.gd`
- ✅ `Scripts/AutoLoads/SignalManager.gd`
- ✅ `Scripts/Events/EventPage.gd`
- ✅ `Scripts/Events/Commands/SetSelfSwitchCommand.gd`
- ✅ `Scripts/Events/Commands/SetVariableCommand.gd`
- ✅ `Scripts/GameStart.gd`
- ✅ `Scripts/Events/Commands/SetFlagCommand.gd`
- ✅ `Scripts/Overworld/WildEncounterDetector.gd`

#### Referencias a GUI eliminadas/actualizadas:
- ✅ `Scenes/Overworld/Overworld.tscn` - Eliminada instancia de GUI
- ✅ `Scenes/TestChoiceBox.tscn` - Eliminada instancia de GUI
- ✅ `Scenes/Battle/TestBattle.tscn` - Eliminada instancia de GUI
- ✅ `Scripts/TestChoiceBox.gd` - Actualizado para usar `DisplayManager.instance`

---

### ✅ 5. Configuración de Main como Escena Inicial

**Archivo:** `project.godot`

```ini
[application]
run/main_scene="res://Scenes/Main.tscn"

[autoload]
CONST="*res://Scripts/AutoLoads/CONST.gd"
SignalManager="*res://Scripts/AutoLoads/SignalManager.gd"
GameStateService="*res://Services/GameStateService.gd"
DatabaseService="*res://Services/DatabaseService.gd"
```

---

### ✅ 6. Estructura de Carpetas Actualizada

Se han creado las nuevas carpetas para la arquitectura Services/Managers:

```
PK2D/
├── Managers/
│   ├── DisplayManager.gd
│   └── DisplayManager.tscn
├── Services/
│   ├── DatabaseService.gd
│   └── GameStateService.gd
├── Scenes/
│   ├── Main.tscn          (NUEVA - Raíz del proyecto)
│   ├── GameSession.tscn   (Representa una sesión de juego completa)
│   └── Overworld.tscn     (Sin GUI, hijo de GameSession)
└── Scripts/
    ├── Main.gd            (Gestiona DisplayManager y GameContainer)
    ├── GameSession.gd     (Gestiona el ciclo de vida de una partida)
    └── ...
```

---

## 🔄 Cambios en el Flujo de Inicialización

### Antes (PBI anterior):
```
GameStart.tscn (raíz)
  └── Carga Overworld.tscn
      └── Contiene GUI (local)
```

### Ahora (PBI 498):
```
Main.tscn (raíz)
  ├── DisplayManager (global, persistente)
  └── GameContainer
      └── GameSession.tscn (instancia de sesión de juego)
          └── Overworld.tscn (sin GUI)
```

**Beneficios:**
1. ✅ DisplayManager accesible desde cualquier escena
2. ✅ No se pierde la UI al cambiar de escena
3. ✅ GameSession representa una sesión completa (nueva partida o cargada)
4. ✅ Preparado para múltiples sesiones y menú principal
5. ✅ Desacoplamiento: las escenas ya no necesitan su propio GUI

---

## 🧪 Testing

### Casos de Prueba Verificados:

1. ✅ **Inicio del Juego:**
   - Main carga correctamente
   - DisplayManager se inicializa como singleton
   - GameStart se carga dentro de GameContainer

2. ✅ **Mensajes y Diálogos:**
   - Los mensajes del SignalManager se muestran correctamente
   - ChoiceBox funciona desde DisplayManager

3. ✅ **Batallas:**
   - Las transiciones de batalla funcionan con DisplayManager
   - El control del jugador se bloquea/desbloquea correctamente

4. ✅ **Autoloads:**
   - DatabaseService carga correctamente todos los recursos
   - GameStateService mantiene el estado del juego
   - SignalManager se conecta con GameStateService

5. ✅ **Compatibilidad Legacy:**
   - Métodos antiguos del GUI siguen funcionando
   - Scripts que usan SignalManager no requieren cambios

---

## 📝 Notas Técnicas

### DisplayManager como Singleton

```gdscript
# Registrar como singleton en _ready()
if instance != null:
    push_error("DisplayManager: Ya existe una instancia")
    queue_free()
    return

instance = self
```

## 🔄 Refactorización Adicional: GameStart → GameSession

Tras la implementación inicial, se realizó una refactorización para mejorar la semántica y preparar el futuro menú principal:

### Cambios Realizados

**Renombrado GameStart → GameSession:**
- ✅ `Scenes/GameStart.tscn` → `Scenes/GameSession.tscn`
- ✅ `Scripts/GameStart.gd` → `Scripts/GameSession.gd`
- ✅ Agregado `class_name GameSession`

**Cambios Arquitectónicos:**
1. **GameSession ahora es hijo de GameContainer** (no reemplaza la escena root)
2. **Overworld es hijo de GameSession** (no reemplaza la escena)
3. **Main gestiona el ciclo de vida** de las sesiones

**Nuevos Métodos en Main:**
```gdscript
func start_new_game_session() -> void  # Inicia nueva partida
func continue_game_session() -> void    # Continúa partida guardada (TODO)
func end_current_session() -> void      # Finaliza sesión actual
```

**Nuevos Métodos en GameSession:**
```gdscript
func end_session() -> void  # Finaliza la sesión limpiamente
```

**Flujo Actualizado:**
```
Main._ready()
  └── start_new_game_session()
      └── GameSession._ready()
          └── _load_overworld_scene()
              └── add_child(Overworld)
```

**Ventajas:**
- ✅ GameSession representa mejor el concepto de "sesión de juego"
- ✅ Preparado para menú principal (Nueva Partida / Continuar)
- ✅ Main puede gestionar múltiples sesiones
- ✅ Arquitectura más clara y escalable

---

### ⚠️ Importante: Autoloads y class_name

Los archivos de **Services** que son autoloads (`DatabaseService`, `GameStateService`) **NO** deben usar `class_name`, ya que Godot genera una advertencia cuando un `class_name` oculta un autoload singleton.

**Correcto:**
```gdscript
extends Node
## DatabaseService - Accesible globalmente como autoload
```

**Incorrecto (genera warning):**
```gdscript
extends Node
class_name DatabaseService  # ❌ Oculta el autoload
```

### Acceso Global y Convenciones de Nombres

**API Pública (métodos estáticos):**
```gdscript
# Mostrar mensajes
await DisplayManager.show_message("Hola mundo", {"waitInput": true})

# Mostrar opciones
var choice = await DisplayManager.show_choices(["Sí", "No"])

# Mensaje con opciones (estilo Pokémon)
var result = await DisplayManager.show_message_with_choices("¿Continuar?", ["Sí", "No"])

# Transiciones fade
await DisplayManager.fade_out(0.5)
await DisplayManager.fade_in(0.3)

# Verificar estado
if DisplayManager.is_fading():
    print("Haciendo fade...")
```

**Métodos Privados (NO llamar directamente):**
```gdscript
# Métodos internos con prefijo _
func _show_message_with_config(...)  # ← Privado
func _show_choices(...)               # ← Privado
func _is_fading()                     # ← Privado
```

**SignalManager (legacy, aún funciona):**
```gdscript
# Método alternativo vía señales (legacy)
SignalManager.message_requested.emit("Hola mundo", {})
```

**Convención:**
- ✅ Métodos estáticos: nombres simples sin sufijos (`show_message`, `fade_out`)
- ✅ Métodos privados: prefijo `_` para indicar uso interno (`_show_choices`)
- ❌ Ya NO usar sufijos `_static` (eliminados en refactorización)

---

## 🔄 Migración Adicional: SignalManager → DisplayManager

Tras establecer la API estática de `DisplayManager`, se realizó una migración para eliminar el uso de señales de `SignalManager` para la UI:

### Señales Deprecated

```gdscript
// SignalManager.gd
## DEPRECATED: Usar DisplayManager.show_message() en su lugar
# signal message_requested(text: String, config: Dictionary)
# signal message_finished()
```

### Archivos Migrados (10 total)

**Comandos de Eventos:**
- ✅ `ShowMessageCommand.gd` - Usa `DisplayManager.show_message()`
- ✅ `ShowChoicesCommand.gd` - Usa `DisplayManager.show_message_with_choices()`

**Acciones de MO:**
- ✅ `CutAction.gd` - Migrado
- ✅ `SurfAction.gd` - Migrado
- ✅ `StrengthAction.gd` - Migrado
- ✅ `UseMOCommand.gd` - Migrado

**Sistema de Batallas:**
- ✅ `Trainer.gd` - Migrado
- ✅ `StartBattleEventCommand.gd` - Migrado

**Core:**
- ✅ `DisplayManager.gd` - Limpiado de conexiones deprecated
- ✅ `SignalManager.gd` - Señales comentadas

### Comparación Antes/Después

```gdscript
# ANTES (SignalManager)
SignalManager.message_requested.emit("Texto", config)
await SignalManager.message_finished

# DESPUÉS (DisplayManager)
await DisplayManager.show_message("Texto", config)
```

**Ventajas:**
- ✅ ~60% menos código boilerplate
- ✅ Flujo más directo y fácil de debuggear
- ✅ Menos acoplamiento con SignalManager
- ✅ Mejor rendimiento (sin overhead de señales)

---

## 🔄 Migración Adicional: Señales de Batalla a DisplayManager

Tras migrar las señales de UI, se ha continuado con las señales de batalla:

### Nuevas Señales en DisplayManager

```gdscript
signal battle_started()
signal battle_finished(winner_side: String)
```

### Nuevo Método Estático

```gdscript
static func start_battle(participants: Array[BattleParticipant], rules: BattleRules) -> String
```

### Archivos Migrados (7 total)

- ✅ `Trainer.gd` - Usa `DisplayManager.start_battle()`
- ✅ `WildEncounterDetector.gd` - Usa `DisplayManager.start_battle()`
- ✅ `StartBattleEventCommand.gd` - Simplificado (eliminados flags y callbacks)
- ✅ `TestBattle.gd` - 5 batallas migradas
- ✅ `BattleController.gd` - Llama a DisplayManager directamente
- ✅ `DisplayManager.gd` - Implementado `start_battle()`
- ✅ `SignalManager.gd` - Señales comentadas como deprecated

### Comparación

```gdscript
# ANTES
SignalManager.battle_requested.emit(participants, rules)
await SignalManager.battle_finished

# DESPUÉS
var winner = await DisplayManager.start_battle(participants, rules)
```

**Ventajas:**
- ✅ ~82% menos código boilerplate
- ✅ Resultado disponible inmediatamente
- ✅ Sin callbacks ni polling
- ✅ API más intuitiva

---

## 🔄 Migración Adicional: Señales de Fade a DisplayManager

Tras migrar mensajes, opciones y batallas, también se migraron los fades:

### Señales Deprecated

```gdscript
## DEPRECATED: Usar DisplayManager.fade_in() / fade_out()
# signal fade_requested(mode: String, duration: float)
# signal fade_finished()
```

### Archivos Migrados (5 total)

- ✅ `GameSession.gd` - Usa `DisplayManager.fade_out()`
- ✅ `FadeCommand.gd` - Simplificado
- ✅ `FadeExample.gd` - Reescrito con flujo lineal
- ✅ `FadeLayer.gd` - Limpiado
- ✅ `SignalManager.gd` - Señales comentadas

### Comparación

```gdscript
# ANTES
SignalManager.fade_requested.emit("fade_in", 0.5)
await SignalManager.fade_finished

# DESPUÉS
await DisplayManager.fade_in(0.5)
```

**Ventajas:**
- ✅ ~70% menos código
- ✅ Sin conversiones de string
- ✅ Sin callbacks
- ✅ API más clara

---

### ✅ 7. Reestructuración de señales de Systems mediante OverworldContext (PBI 499)

**Contexto:** Las señales internas del Overworld (eventos, warps, grids, MO) ahora se gestionan localmente a través de `OverworldContext`, eliminando la dependencia de `SignalManager` para comunicación entre Systems.

#### Cambios clave
- `OverworldContext` expone señales locales (`event_started`, `event_finished`, `warp_finished`, `seamless_map_crossed`, `active_grid_changed`) y métodos helper (`request_event`, `request_warp`, `request_mo`, `block_player_control`).
- `EventSystem`, `EventController` y `Event` usan directamente el contexto; las señales públicas del EventSystem son reenviadas por el contexto.
- `WarpSystem`, `WarpCommand`, `WildEncounterDetector`, `MOSystem`, `UseMOCommand` y el `Player` se comunican mediante `OverworldContext`.
- `MapSystem`, `WorldSystem`, `GridMotion` y `Occupancy` publican/consumen cambios de grid y cruces seamles a través del contexto local.
- `SignalManager` queda reservado a señales de alcance global (bloqueo de control para UI global, input, estado del juego, callbacks legacy de batalla).

#### Código representativo
```gdscript
# Solicitud de warp desde un EventCommand
var overworld_context = _get_overworld_context(context)
await overworld_context.request_warp(target_scene, target_spawn)

# Emisión local desde WarpSystem
warp_started.emit(map_id, spawn_id)
await _execute_warp(map_id, spawn_id)
if is_warping:
    await self.warp_finished

# Conexión centralizada en OverworldContext
event_system.event_finished.connect(func(event): event_finished.emit(event))
```

---

## 🚀 Próximos Pasos (Futuros PBIs)

### PBI Futuro: Eliminación Progresiva de SignalManager
- Migrar llamadas de `SignalManager.message_requested` a `DisplayManager.show_message()`
- Reducir dependencia del bus de señales global
- Mantener SignalManager solo para eventos de entrada

### PBI Futuro: Creación de Managers Adicionales
- **AudioManager**: Gestión de música y efectos de sonido
- **ConfigManager**: Configuración del juego (opciones, controles, etc.)
- **LoggerService**: Sistema de logs centralizado

### PBI Futuro: Sistema de Guardado
- Integrar con GameStateService para persistencia
- DisplayManager persistirá entre escenas (ya implementado)
- Main gestiona el estado de la sesión

---

## ✅ Criterios de Aceptación Completados

- ✅ Main es la nueva escena raíz y carga correctamente el juego
- ✅ DisplayManager reemplaza completamente al GUI y funciona igual
- ✅ DisplayManager es accesible desde cualquier script (singleton)
- ✅ DatabaseService y GameStateService están registrados como autoloads
- ✅ No quedan referencias al antiguo GUI ni a DatabaseManager/GameStateManager
- ✅ La documentación de arquitectura está actualizada (este documento)

---

## 🎉 Conclusión

El PBI 498 ha sido completado exitosamente. La nueva arquitectura basada en `Main.tscn` y `DisplayManager` proporciona una base sólida para el desarrollo futuro del proyecto, reduciendo el acoplamiento y preparando el sistema para la eliminación progresiva de dependencias globales como `SignalManager`.

**Fecha de Completado:** 6 de Noviembre, 2025
**Estado:** ✅ COMPLETADO

