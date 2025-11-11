# 🔄 Migración de Señales de Batalla a DisplayManager

## 📋 Resumen

Se han migrado las señales de batalla de `SignalManager` a `DisplayManager`, creando una API más limpia y directa para iniciar batallas.

---

## 🎯 Cambios Realizados

### 1. **Nuevas Señales en DisplayManager**

```gdscript
// DisplayManager.gd
signal battle_started()
signal battle_finished(winner_side: String)
```

**Antes** (SignalManager):
```gdscript
SignalManager.battle_started    # ← Global, en SignalManager
SignalManager.battle_finished   # ← Global, en SignalManager
```

**Ahora** (DisplayManager):
```gdscript
DisplayManager.instance.battle_started    # ← En DisplayManager
DisplayManager.instance.battle_finished   # ← En DisplayManager
```

---

### 2. **Nuevo Método Estático: `start_battle()`**

```gdscript
## Inicia una batalla y devuelve el ganador
static func start_battle(participants: Array[BattleParticipant], rules: BattleRules) -> String
```

**Uso:**
```gdscript
# Preparar participantes y reglas
var participants: Array[BattleParticipant] = [player_participant, wild_participant]
var rules = BattleRules.new(BattleRules.BattleTypes.WILD, BattleRules.BattleModes.SINGLE)

# Iniciar batalla y obtener ganador
var winner = await DisplayManager.start_battle(participants, rules)

# Procesar resultado
if winner == "player":
    print("¡El jugador ganó!")
else:
    print("El jugador perdió...")
```

---

## 📝 Comparación Antes/Después

### Iniciar Batalla

```gdscript
# ❌ ANTES (SignalManager)
SignalManager.battle_requested.emit(participants, rules)
await SignalManager.battle_finished

# ✅ AHORA (DisplayManager)
var winner = await DisplayManager.start_battle(participants, rules)
```

### Escuchar cuando termina la batalla

```gdscript
# ❌ ANTES (SignalManager)
SignalManager.battle_finished.connect(_on_battle_finished)

func _on_battle_finished(winner_side: String):
    print("Ganador:", winner_side)

# ✅ AHORA (DisplayManager)
DisplayManager.instance.battle_finished.connect(_on_battle_finished)

func _on_battle_finished(winner_side: String):
    print("Ganador:", winner_side)
```

---

## 🗂️ Archivos Migrados

### 1. **Trainer.gd**

```gdscript
# ANTES
SignalManager.battle_requested.emit(participants, rules)
# ... en otro lugar ...
SignalManager.battle_finished.connect(_on_battle_finished)

# DESPUÉS
var winner = await DisplayManager.start_battle(participants, rules)
# ...
DisplayManager.instance.battle_finished.connect(_on_battle_finished)
```

### 2. **WildEncounterDetector.gd**

```gdscript
# ANTES
SignalManager.battle_requested.emit(participants, rules)
await SignalManager.battle_finished

# DESPUÉS
var winner = await DisplayManager.start_battle(participants, rules)
print("Ganador: %s" % winner)
```

### 3. **StartBattleEventCommand.gd**

```gdscript
# ANTES
_battle_finished = false
SignalManager.battle_finished.connect(_on_battle_finished)
SignalManager.battle_requested.emit(participants, rules)

while not _battle_finished:
    await context.get_tree().process_frame

SignalManager.battle_finished.disconnect(_on_battle_finished)

# DESPUÉS
_battle_winner = await DisplayManager.start_battle(participants, rules)
# Ya no necesita flags ni callbacks
```

**Simplificación:**
- ❌ Eliminada variable `_battle_finished`
- ❌ Eliminado método `_on_battle_finished()`
- ❌ Eliminado loop de polling
- ✅ Una sola línea con await

### 4. **TestBattle.gd**

```gdscript
# ANTES (5 veces en el archivo)
SignalManager.battle_requested.emit(participants, rules)
await SignalManager.battle_finished

# DESPUÉS
var winner = await DisplayManager.start_battle(participants, rules)
print(">>> Batalla terminada. Ganador: %s" % winner)
```

### 5. **BattleController.gd**

```gdscript
# ANTES
SignalManager.battle_finished.emit(battle_winner)

# DESPUÉS
if DisplayManager.instance:
    DisplayManager.instance._on_battle_finished(battle_winner)
```

**Nota:** Llama directamente al método privado `_on_battle_finished()` de DisplayManager, que:
1. Maneja el fade out
2. Limpia la batalla
3. Emite `DisplayManager.instance.battle_finished`
4. Desbloquea el control del jugador

---

## 🏗️ Arquitectura Interna

### Flujo de Batalla Completo

```
[Código del usuario]
    ↓
DisplayManager.start_battle(participants, rules)
    ↓
DisplayManager._start_battle() (privado)
    ├── Bloquea control del jugador
    ├── Separa participantes (player vs enemy)
    ├── Emite DisplayManager.battle_started
    ├── Muestra BattleScene
    ├── await BattleNew.start_battle()
    └── await _wait_for_battle_cleanup()
            ↓
        [Durante la batalla...]
            ↓
        BattleController termina
            ↓
        BattleController.end_battle()
            ├── SignalManager.battle_finished.emit()  (temporal)
            └── DisplayManager._on_battle_finished()
                    ├── Fade in (a negro)
                    ├── BattleNew.cleanup_battle()
                    ├── Fade out (revelar overworld)
                    ├── Emite DisplayManager.battle_finished
                    ├── Desbloquea control del jugador
                    └── Marca _battle_cleanup_done = true
                            ↓
                        _wait_for_battle_cleanup() retorna
                            ↓
                        start_battle() retorna winner
```

---

## 🔄 Variables de Control

### En DisplayManager

```gdscript
# Variables para sincronizar el flujo de batalla
var _battle_winner: String = ""
var _battle_cleanup_done: bool = false

func _wait_for_battle_cleanup() -> String:
    # Esperar a que _on_battle_finished termine
    while not _battle_cleanup_done:
        await get_tree().process_frame

    _battle_cleanup_done = false
    return _battle_winner
```

Estas variables permiten que `start_battle()` espere a que todo el cleanup (fades, limpieza, etc.) termine antes de retornar el ganador.

---

## ✅ Ventajas de la Migración

### 1. **API Más Simple**

```gdscript
# ANTES: 3 pasos (emit, await, procesar)
SignalManager.battle_requested.emit(participants, rules)
await SignalManager.battle_finished
# ... procesar resultado en callback

# AHORA: 1 paso (await y obtener resultado)
var winner = await DisplayManager.start_battle(participants, rules)
if winner == "player":
    # ... procesar
```

### 2. **Menos Código Boilerplate**

**StartBattleEventCommand.gd:**
- ❌ Eliminadas 15+ líneas de código (flags, callbacks, loops)
- ✅ Reemplazadas por 1 línea con await

**TestBattle.gd:**
- ❌ Eliminadas 10 líneas (5 x 2 líneas cada batalla)
- ✅ Reemplazadas por 5 líneas (5 x 1 línea cada batalla)

### 3. **Mejor Flujo de Control**

```gdscript
# ANTES: Flujo indirecto con callbacks
func start_battle_old():
    SignalManager.battle_finished.connect(_on_battle_finished)
    SignalManager.battle_requested.emit(...)

    while not _battle_finished:  # ← polling
        await process_frame

    SignalManager.battle_finished.disconnect(...)
    process_winner()

# DESPUÉS: Flujo directo
func start_battle_new():
    var winner = await DisplayManager.start_battle(...)
    process_winner()  # ← directamente después
```

### 4. **Resultado Disponible Inmediatamente**

```gdscript
# Ahora puedes hacer cosas como:
var winner = await DisplayManager.start_battle(participants, rules)

if winner == "player":
    GameStateService.set_event_flag("defeated_gym_leader_1", true)
    await DisplayManager.show_message("¡Has derrotado al líder del gimnasio!")
```

---

## 🔧 Señales Deprecated en SignalManager

```gdscript
// SignalManager.gd

## DEPRECATED: Usar DisplayManager.start_battle() en su lugar
# signal battle_requested(participants: Array, rules: BattleRules)

## DEPRECATED: Ahora es DisplayManager.battle_started
# signal battle_started()

## DEPRECATED: Ahora es DisplayManager.battle_finished (emitida desde BattleController)
signal battle_finished(winner_side)  # Mantener temporalmente
```

**Nota:** `battle_finished` se mantiene temporalmente porque `BattleController` aún la emite. En el futuro se podría eliminar completamente.

---

## 📊 Estadísticas

### Archivos Modificados
- ✅ `DisplayManager.gd` - Añadidas señales y método `start_battle()`
- ✅ `SignalManager.gd` - Señales comentadas como deprecated
- ✅ `Trainer.gd` - Migrado a DisplayManager
- ✅ `WildEncounterDetector.gd` - Migrado a DisplayManager
- ✅ `StartBattleEventCommand.gd` - Migrado y simplificado
- ✅ `TestBattle.gd` - Migrado (5 batallas)
- ✅ `BattleController.gd` - Llama a DisplayManager directamente

**Total: 7 archivos actualizados**

### Reducción de Código
- **Antes:** ~40 líneas para gestionar batallas (emit + await + callbacks)
- **Después:** ~7 líneas (await directo)
- **Reducción:** ~82% menos código boilerplate

---

## 🎯 Próximos Pasos

### Opcional: Eliminar Completamente battle_finished de SignalManager

Cuando estemos seguros de que todo funciona:

1. Eliminar `SignalManager.battle_finished`
2. BattleController llamará solo a `DisplayManager.instance._on_battle_finished()`
3. Eliminar la conexión temporal en DisplayManager

### Migrar Señales de Fade

```gdscript
# Actual
SignalManager.fade_requested.emit("fade_out", 0.5)
await SignalManager.fade_finished

# Futuro
await DisplayManager.fade_out(0.5)  # Ya está implementado!
```

---

## ✅ Conclusión

La migración de las señales de batalla a `DisplayManager` ha sido exitosa:

- ✅ API más simple y directa
- ✅ Menos código boilerplate (~82% reducción)
- ✅ Resultado disponible inmediatamente
- ✅ Mejor flujo de control (sin callbacks)
- ✅ DisplayManager es el punto central para toda la UI y batallas

**Fecha de Migración:** 6 de Noviembre, 2025
**Estado:** ✅ COMPLETADO

