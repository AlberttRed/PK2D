# MOSystem - Arquitectura Final

## ✅ Diseño Final Optimizado

---

## 🎯 Problemas Resueltos

### 1. **Dictionary de execute() era innecesario**

**ANTES:**
```gdscript
func execute(player, target) -> Dictionary:
    return {
        "success": true,
        "detect_message": "...",   # ❌ Redundante
        "prompt_message": "...",   # ❌ Redundante
        "success_message": "...",  # ❌ Redundante
        "animation_name": "..."    # ❌ Redundante
    }
```

**Problema:**
- `execute()` retorna los mensajes, pero ya están en propiedades
- Mensajes no pueden ser dinámicos según contexto
- Dictionary demasiado grande

---

### 2. **Solución: Métodos Dinámicos**

**AHORA:**
```gdscript
# execute() solo retorna éxito/fallo
func execute(player, target) -> Dictionary:
    # Lógica de la MO
    return {"success": true}  ✅ Simple

# Métodos separados para UI (sobrescribibles y dinámicos)
func get_detect_message(target: Node) -> String:
    return "¡Un árbol bloquea el camino!"

func get_prompt_message(target: Node) -> String:
    return "¿Usar CORTE?"

func get_success_message(target: Node, result: Dictionary) -> String:
    return "¡El árbol fue cortado!"

func get_fail_message(target: Node, reason: String) -> String:
    return reason

func get_animation_name(target: Node) -> String:
    return "cut_tree"
```

---

## 📊 Ventajas del Nuevo Diseño

### 1. **Mensajes Dinámicos**

Ahora los mensajes pueden cambiar según el target:

```gdscript
func get_detect_message(target: Node) -> String:
    # Diferentes mensajes según tipo de árbol
    if target.has_meta("tree_type"):
        match target.get_meta("tree_type"):
            "small":
                return "¡Un árbol pequeño bloquea el camino!"
            "thick":
                return "¡Un árbol grueso bloquea el paso!"
            _:
                return "¡Un árbol bloquea el camino!"

    return "¡Un árbol bloquea el camino!"
```

### 2. **execute() Limpio**

```gdscript
func execute(player, target) -> Dictionary:
    # Solo lógica del juego
    # Sin preocuparse de mensajes ni UI

    # Hacer cambios en el estado
    # Aplicar efectos

    return {"success": true}  # Simple y claro
```

### 3. **Separación de Responsabilidades**

| Método | Responsabilidad |
|--------|-----------------|
| `can_use()` | Validación (party, medalla, contexto) |
| `execute()` | Lógica del juego (flags, efectos) |
| `get_detect_message()` | UI - Detección |
| `get_prompt_message()` | UI - Confirmación |
| `get_success_message()` | UI - Éxito |
| `get_fail_message()` | UI - Fallo |
| `get_animation_name()` | UI - Animación |

---

## 🔧 Error de Señales Duplicadas - SOLUCIONADO

### Problema

```
Signal 'line_displayed' is already connected
```

**Causa:**
- MessageBox no desconecta señales entre llamadas
- Llamadas rápidas consecutivas causan error

### Solución

Añadir `await process_frame` entre mensajes:

```gdscript
# Mensaje 1
SignalManager.message_requested.emit(...)
await SignalManager.message_finished
await Engine.get_main_loop().process_frame  # ← Limpieza

# Choice (mensaje 2)
await gui.show_message_with_choices(...)
await Engine.get_main_loop().process_frame  # ← Limpieza

# Mensaje 3 de éxito
SignalManager.message_requested.emit(...)
await SignalManager.message_finished
await Engine.get_main_loop().process_frame  # ← Limpieza

# Animación
await _play_animation(...)
```

**Esto da tiempo al MessageBox para desconectar señales.**

---

## 📋 Flujo Completo

```
UseMOCommand.execute()
├─ Obtener MOAction
├─ detect_message = mo_action.get_detect_message(target)
├─ Mostrar detect_message
├─ await process_frame ← Limpieza
│
├─ Si requires_confirmation:
│  ├─ prompt = mo_action.get_prompt_message(target)
│  ├─ choice = await show_message_with_choices(prompt)
│  ├─ await process_frame ← Limpieza
│  └─ Si No/Cancelado → return
│
├─ mo_requested → MOSystem
├─ MOSystem.execute_mo()
│  ├─ can_use() → validación
│  └─ execute() → lógica
├─ mo_finished(success, reason)
│
├─ Si success:
│  ├─ success_msg = mo_action.get_success_message(target, result)
│  ├─ Mostrar success_message
│  ├─ await process_frame ← Limpieza
│  ├─ anim = mo_action.get_animation_name(target)
│  └─ Reproducir animación
│
└─ Si fallo:
   ├─ fail_msg = mo_action.get_fail_message(target, reason)
   └─ Mostrar fail_message
```

---

## 🎮 Ejemplo: CutAction con Mensajes Dinámicos

```gdscript
class_name CutAction extends MOAction

func _init():
    mo_name = "CUT"
    requires_confirmation = true

func can_use(player, target):
    # Validación
    return true

func execute(player, target):
    # Solo lógica
    return {"success": true}

# Mensajes dinámicos según el target
func get_detect_message(target: Node) -> String:
    if target.has_meta("tree_size"):
        if target.get_meta("tree_size") == "big":
            return "¡Un árbol grande bloquea el camino!"

    return "¡Un árbol pequeño bloquea el camino!"

func get_prompt_message(target: Node) -> String:
    return "¿Usar CORTE?"

func get_success_message(target: Node, result: Dictionary) -> String:
    return "¡El árbol fue cortado!"

func get_animation_name(target: Node) -> String:
    # Diferentes animaciones según tipo
    if target.has_meta("tree_size"):
        if target.get_meta("tree_size") == "big":
            return "cut_tree_big"

    return "cut_tree"
```

---

## 📊 Comparación

| Aspecto | Antes (Properties) | Ahora (Métodos) |
|---------|-------------------|-----------------|
| **Ubicación** | Propiedades en _init() | Métodos sobrescribibles |
| **Dinámicos** | ❌ No | ✅ Sí (según target) |
| **execute()** | Retorna todo | Solo success/fail |
| **Flexibilidad** | Baja | Alta |
| **Mantenibilidad** | Media | Alta |

---

## ✅ Ventajas

1. **Más Flexible:**
   - Mensajes dinámicos según target
   - Animaciones diferentes según contexto
   - Fácil personalizar por caso

2. **Más Limpio:**
   - `execute()` solo retorna success/fail
   - No hay Dictionary gigante
   - Separación clara

3. **Más Potente:**
   - Acceso al target en cada método
   - Acceso al result en success_message
   - Lógica contextual

4. **Sin Errores:**
   - `await process_frame` entre mensajes
   - MessageBox se limpia correctamente
   - No hay señales duplicadas

---

## 🎉 Estado Final

- ✅ **Error de señales:** Resuelto con await process_frame
- ✅ **Dictionary innecesario:** Eliminado
- ✅ **Mensajes dinámicos:** Implementado con métodos
- ✅ **execute() limpio:** Solo retorna success/fail
- ✅ **Más flexible:** Mensajes según contexto
- ✅ **Sin errores de compilación**

**Sistema perfecto y muy potente.** 🚀

---

## 💡 Casos de Uso

### Mensaje diferente según metadata

```gdscript
func get_detect_message(target: Node) -> String:
    if target.has_meta("npc_name"):
        return "¡%s bloquea el paso!" % target.get_meta("npc_name")

    return "¡Un árbol bloquea el camino!"
```

### Animación según estado

```gdscript
func get_animation_name(target: Node) -> String:
    if target.has_meta("already_damaged"):
        return "cut_tree_damaged"  # Animación rápida

    return "cut_tree_normal"  # Animación completa
```

### Mensaje de éxito con datos del resultado

```gdscript
func get_success_message(target: Node, result: Dictionary) -> String:
    var data = result.get("data", {})
    var trees_cut = data.get("trees_cut_total", 0)

    if trees_cut > 10:
        return "¡Árbol cortado! ¡Ya llevas %d árboles!" % trees_cut

    return "¡El árbol fue cortado!"
```

**Mucho más potente que propiedades estáticas.** ✨

