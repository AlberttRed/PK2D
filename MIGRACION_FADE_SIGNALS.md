# 🔄 Migración de Señales de Fade a DisplayManager

## 📋 Resumen

Se han migrado las señales de fade de `SignalManager` a usar directamente los métodos de `DisplayManager`, simplificando el código y eliminando indirecciones innecesarias.

---

## 🎯 Cambios Realizados

### Señales Deprecated en SignalManager

```gdscript
// SignalManager.gd
## DEPRECATED: Usar DisplayManager.fade_in() / fade_out() en su lugar
# signal fade_requested(mode: String, duration: float)
# signal fade_finished()
```

### Métodos ya Disponibles en DisplayManager

```gdscript
static func fade_in(duration: float = 0.3) -> void
static func fade_out(duration: float = 0.3) -> void
```

---

## 📝 Archivos Migrados

### 1. **GameSession.gd**

```gdscript
# ANTES
SignalManager.fade_requested.emit("fade_out", 0.25)
await SignalManager.fade_finished

# DESPUÉS
await DisplayManager.fade_out(0.25)
```

### 2. **FadeCommand.gd**

```gdscript
# ANTES
var fade_mode_string: String = "fade_out"
match mode:
    FadeMode.IN:
        fade_mode_string = "fade_in"
    FadeMode.OUT:
        fade_mode_string = "fade_out"

SignalManager.fade_requested.emit(fade_mode_string, duration)
await SignalManager.fade_finished

# DESPUÉS
match mode:
    FadeMode.IN:
        await DisplayManager.fade_in(duration)
    FadeMode.OUT:
        await DisplayManager.fade_out(duration)
```

**Simplificación:**
- ❌ Eliminada conversión de enum a string
- ✅ Llamada directa según el modo
- ✅ Más legible y directo

### 3. **FadeExample.gd**

```gdscript
# ANTES
SignalManager.fade_finished.connect(_on_fade_finished)
SignalManager.fade_requested.emit("fade_in", 0.3)

func _on_fade_finished():
    # Callback indirecto
    SignalManager.fade_requested.emit("fade_out", 0.3)

# DESPUÉS
await DisplayManager.fade_in(0.3)
print("Fade completado")
await get_tree().create_timer(1.0).timeout
await DisplayManager.fade_out(0.3)
print("Fade completado")
```

**Simplificación:**
- ❌ Eliminados callbacks
- ✅ Flujo secuencial directo
- ✅ Más fácil de leer

### 4. **FadeLayer.gd**

```gdscript
# ANTES
func fade_in(duration: float) -> void:
    # ... código ...
    fade_finished.emit()
    SignalManager.fade_finished.emit()  # ← Emitía a SignalManager

# Conectaba señales
SignalManager.fade_requested.connect(_on_fade_requested)

func _on_fade_requested(mode: String, duration: float) -> void:
    match mode:
        "fade_in": await fade_in(duration)
        "fade_out": await fade_out(duration)

# DESPUÉS
func fade_in(duration: float) -> void:
    # ... código ...
    fade_finished.emit()
    # SignalManager.fade_finished.emit()  # DEPRECATED

# Ya no conecta señales
# SignalManager.fade_requested.connect(_on_fade_requested)  # DEPRECATED

## DEPRECATED: Ya no se usa
# func _on_fade_requested(mode: String, duration: float) -> void:
```

---

## 📊 Comparación Antes/Después

### Ejemplo 1: Fade Simple

```gdscript
# ANTES (3 pasos)
SignalManager.fade_requested.emit("fade_in", 0.5)
await SignalManager.fade_finished
# Continuar...

# DESPUÉS (1 paso)
await DisplayManager.fade_in(0.5)
# Continuar...
```

### Ejemplo 2: Secuencia de Fades

```gdscript
# ANTES (con callbacks complicados)
func _ready():
    SignalManager.fade_finished.connect(_on_fade_finished)
    SignalManager.fade_requested.emit("fade_in", 0.3)

func _on_fade_finished():
    if not done:
        SignalManager.fade_requested.emit("fade_out", 0.3)
        done = true

# DESPUÉS (flujo lineal)
func _ready():
    await DisplayManager.fade_in(0.3)
    await get_tree().create_timer(1.0).timeout
    await DisplayManager.fade_out(0.3)
```

---

## ✅ Ventajas de la Migración

### 1. **Código Más Limpio**
- **Antes:** 3 líneas (emit + await + string conversion)
- **Ahora:** 1 línea (await directo)
- **Reducción:** ~66% menos código

### 2. **Más Intuitivo**
```gdscript
# Claro y directo
await DisplayManager.fade_in(0.5)   # A negro
await DisplayManager.fade_out(0.5)  # Revelar
```

vs

```gdscript
# Indirecto y requiere conocer strings
SignalManager.fade_requested.emit("fade_in", 0.5)  # ¿"fade_in" o "fade_out"?
```

### 3. **Sin Callbacks**
- Flujo secuencial directo con `await`
- No necesitas gestionar conexiones/desconexiones

### 4. **Mejor Tipado**
```gdscript
# Método tipado
static func fade_in(duration: float = 0.3) -> void

vs

# Señal sin tipar (String puede ser cualquier cosa)
signal fade_requested(mode: String, duration: float)
```

---

## 🏗️ Arquitectura

### Flujo de Fade

```
[Código del usuario]
    ↓
DisplayManager.fade_in(0.5)
    ↓
DisplayManager.instance.fade_layer.fade_in(0.5)
    ↓
FadeLayer.fade_in()
    ├── Crear tween
    ├── Animar modulate.a
    └── Emitir fade_finished (señal local de FadeLayer)
```

**Nota:** `FadeLayer.fade_finished` se mantiene como señal local del FadeLayer, pero ya no se propaga a `SignalManager.fade_finished`.

---

## 📊 Estadísticas

### Archivos Modificados
- ✅ `GameSession.gd` - Migrado a DisplayManager
- ✅ `FadeCommand.gd` - Simplificado
- ✅ `FadeExample.gd` - Reescrito con flujo lineal
- ✅ `FadeLayer.gd` - Limpiado de emisiones a SignalManager
- ✅ `SignalManager.gd` - Señales comentadas

**Total: 5 archivos actualizados**

### Reducción de Código
- **Antes:** ~20 líneas para manejar fades (emit + await + callbacks)
- **Después:** ~6 líneas (await directo)
- **Reducción:** ~70% menos código

---

## ✅ Conclusión

La migración de fades a `DisplayManager` está completa:

- ✅ API directa y simple
- ✅ ~70% menos código boilerplate
- ✅ Sin callbacks ni conversiones de string
- ✅ Flujo secuencial claro

**Fecha de Migración:** 6 de Noviembre, 2025
**Estado:** ✅ COMPLETADO

