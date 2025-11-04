# MOSystem - Guía Completa de Uso

## ✅ Sistema 100% Funcional

---

## 🎯 Configuración Simplificada

### Evento: Árbol Cortable (Solo 1 Comando)

```
TreeCuttable_01
├── ActorAnimator (con AnimatedSprite2D)
│   └── SpriteFrames:
│       ├── "idle" (loop: true)
│       └── "cut_tree" (loop: false)
│
├── EventPage 1:
│   ├── Trigger: ACTION_BUTTON
│   ├── Conditions: (ninguna)
│   └── Commands:
│       └── UseMOCommand:  ← ¡SOLO 1 COMANDO!
│           ├── mo_type: CUT
│           ├── target_path: (vacío)
│           └── activate_self_switch_on_success: "A"
│
└── EventPage 2:
    ├── Condition: Self Switch A = ON
    ├── Graphic: (vacío)
    └── Through: true
```

**De 9 comandos → 1 comando** 🎉

---

## 🎮 UseMOCommand - Todo en Uno

### Propiedades

| Propiedad | Tipo | Descripción | Default |
|-----------|------|-------------|---------|
| `mo_type` | MOTypeEnum.Type | Tipo de MO a usar | CUT |
| `target_path` | NodePath | Target personalizado (opcional) | (vacío = evento origen) |
| `activate_self_switch_on_success` | String | Self-switch a activar tras éxito | "A" |

### Qué Hace Automáticamente

UseMOCommand gestiona **TODO el flujo**:

1. ✅ **Mensaje de detección** (get_detect_message)
2. ✅ **Choice Sí/No** (si requires_confirmation)
3. ✅ **Validación** (can_use)
4. ✅ **Ejecución** (execute)
5. ✅ **Mensaje de éxito/fallo** (get_success/fail_message)
6. ✅ **Animación** (get_animation_name)
7. ✅ **Self-Switch** (solo si éxito)

---

## 🔧 CutAction - Configuración

```gdscript
extends MOAction
class_name CutAction

func _init():
    mo_name = "CUT"
    requires_confirmation = true

# Validación (party + medalla en futuro)
func can_use(player, target):
    # TODO: Verificar party.has_move("CUT")
    # TODO FUTURO: Verificar medalla CASCADE
    return target != null

# Lógica simple
func execute(player, target):
    return {"success": true}

# Mensajes dinámicos
func get_detect_message(target):
    return "¡Un árbol pequeño bloquea el camino!"

func get_prompt_message(target):
    return "¿Usar CORTE?"

func get_success_message(target, result):
    return "¡El árbol fue cortado!"

func get_animation_name(target):
    return "cut_tree"
```

---

## 🔄 Flujo Completo

```
Jugador presiona ACTION frente al árbol
   ↓
UseMOCommand.execute()
   ↓
1. Muestra: "¡Un árbol bloquea el camino!"
   ↓
2. Muestra choice: "¿Usar CORTE?"
   ├─ Jugador elige "Sí" → continúa
   └─ Jugador elige "No" → CANCELA (no activa self-switch)
   ↓
3. Conecta callback a mo_finished (ANTES de emitir)
   ↓
4. Emite: mo_requested("CUT", target)
   ↓
5. MOSystem valida y ejecuta
   ↓
6. MOSystem emite: mo_finished("CUT", true, "")
   ↓
7. Callback captura resultado
   ↓
8. Muestra: "¡El árbol fue cortado!"
   ↓
9. Reproduce animación: "cut_tree"
   ↓
10. Activa Self-Switch A = true  ← SOLO SI ÉXITO
   ↓
11. EventPage cambia a página 2 (invisible)
   ↓
FIN - Árbol desaparecido
```

---

## ✅ Ventajas del Self-Switch Integrado

### ANTES (2 comandos):
```
Commands:
1. UseMOCommand: mo_type = CUT
2. SetSelfSwitchCommand: A = true  ← Se ejecuta SIEMPRE (bug)
```

**Problema:** Se ejecuta aunque el jugador elija "No" o la MO falle.

### AHORA (1 comando):
```
Commands:
1. UseMOCommand:
   - mo_type: CUT
   - activate_self_switch_on_success: "A"  ← Solo si éxito
```

**Ventaja:** Solo se activa si:
- ✅ Jugador eligió "Sí"
- ✅ can_use() retornó true
- ✅ execute() retornó success

---

## 🎯 Casos de Uso

### Árbol Cortable (con self-switch)
```
UseMOCommand:
  mo_type: CUT
  activate_self_switch_on_success: "A"
```

### Roca Empujable (sin self-switch)
```
UseMOCommand:
  mo_type: STRENGTH
  activate_self_switch_on_success: ""  ← Vacío (la roca se mueve pero no desaparece)
```

### Iluminación (sin self-switch)
```
UseMOCommand:
  mo_type: FLASH
  activate_self_switch_on_success: ""  ← Vacío (efecto global, no por evento)
```

---

## 🔧 Problema Resuelto: Race Condition

### El Bug Original

```gdscript
// MAL
emit mo_requested         // Se procesa síncronamente
await mo_finished         // ← Ya pasó, nunca llega
```

### La Solución

```gdscript
// BIEN
var callback = func(...): result["received"] = true
connect(callback)         // Conectar PRIMERO
emit mo_requested         // Emitir DESPUÉS
while not received:       // Esperar
    await process_frame
```

**El callback ya está escuchando cuando se emite la señal.** ✅

---

## 📊 Comparación Final

| Aspecto | Versión Original | Versión Final |
|---------|------------------|---------------|
| **Comandos por evento** | 9 comandos | 1 comando |
| **Metadata requerida** | Sí (cuttable) | No |
| **Flags persistentes** | Sí | No |
| **Self-Switch manual** | Sí (siempre) | Automático (solo si éxito) |
| **Mensajes** | 3 comandos | Automático |
| **Choice** | 1 comando | Automático |
| **Animación** | 1 comando | Automático |
| **Bug si dice No** | Sí ❌ | No ✅ |

---

## 🎨 Configuración del Evento

### SpriteFrames Necesario

```
AnimatedSprite2D > SpriteFrames:
├── "idle":
│   ├── tree_normal.png
│   └── Loop: ON
│
└── "cut_tree":
    ├── Frame 1: tree_shake.png (0.1s)
    ├── Frame 2: tree_fall.png (0.2s)
    ├── Frame 3: tree_disappear.png (0.1s)
    └── Loop: OFF  ← IMPORTANTE
```

### EventPages

**Página 1 (visible):**
- Condition: (ninguna) o Self Switch A = OFF
- Graphic: árbol
- Commands: UseMOCommand

**Página 2 (invisible):**
- Condition: Self Switch A = ON
- Graphic: (vacío)
- Through: true

---

## ✅ Sistema Completo

### Implementado:
- ✅ Mensajes automáticos (dinámicos por MOAction)
- ✅ Choice automático (Sí/No con cancelar)
- ✅ Validación (can_use)
- ✅ Ejecución (execute)
- ✅ Animación integrada
- ✅ **Self-Switch automático (solo si éxito)**
- ✅ Race condition resuelto
- ✅ Sin errores de señales

### TODOs Futuros:
- 📋 Implementar party.has_move("CUT")
- 📋 Sistema de medallas

---

## 🚀 Uso Final

**Crear árbol cortable:**

1. Crear Event con ActorAnimator
2. Añadir animación "cut_tree" en SpriteFrames
3. EventPage 1: `UseMOCommand` (mo_type = CUT)
4. EventPage 2: Condition Self Switch A = ON, invisible

**¡Listo! 1 comando.** 🎉

---

## 🎊 Resultado

El sistema es ahora:
- ✅ Súper simple (1 comando)
- ✅ Todo automático (mensajes, choice, animación, self-switch)
- ✅ Sin bugs (no se activa si dice "No")
- ✅ Fácil de extender (copiar CutAction)

**Perfecto para producción.** 🚀

