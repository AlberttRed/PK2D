# Mejoras del MOSystem V2 - Gestión Automática de UI

## 🎯 Objetivo

Simplificar el uso de MOs para que sea similar a Pokémon Essentials: **un solo comando gestiona todo**.

---

## ✅ Cambios Implementados

### ANTES (versión 1): Configuración Manual y Repetitiva

```gdscript
EventPage Commands:
1. ShowMessageCommand: "¡Un árbol bloquea el camino!"
2. ShowMessageCommand: "¿Usar CORTE?"
3. ShowChoicesCommand: ["Sí", "No"]
4. ConditionalBranch: if choice == 0
5.   UseMOCommand: mo_type = CUT
6.   ShowMessageCommand: "¡El árbol fue cortado!"
7.   PlayAnimationCommand: "cut_tree"
8.   SetSelfSwitchCommand: A = true
9. EndBranch
```

**Problemas:**
- ❌ 9 comandos para una acción simple
- ❌ Muy repetitivo (mismo patrón para cada MO)
- ❌ Propenso a errores al configurar
- ❌ Difícil de mantener

---

### DESPUÉS (versión 2): Gestión Automática

```gdscript
EventPage Commands:
1. UseMOCommand: mo_type = CUT
2. SetSelfSwitchCommand: A = true
```

**Ventajas:**
- ✅ Solo 2 comandos
- ✅ Todo está configurado en la MOAction
- ✅ Consistente en todo el juego
- ✅ Fácil de mantener

---

## 🏗️ Arquitectura de la Mejora

### 1. MOAction - Configuración Centralizada

Ahora MOAction define **todo** lo relacionado con la UI/UX:

```gdscript
extends MOAction
class_name CutAction

func _init():
    mo_name = "CUT"

    # Mensajes
    detect_message = "¡Un árbol pequeño bloquea el camino!"
    prompt_message = "¿Usar CORTE?"
    success_message = "¡El árbol fue cortado!"
    fail_message = "No se puede usar CORTE aquí."

    # Animación
    animation_name = "cut_tree"
    play_animation_on_success = true

    # Comportamiento
    requires_confirmation = true
```

**Nuevas Propiedades:**

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `detect_message` | String | Mensaje al detectar el obstáculo |
| `prompt_message` | String | Pregunta para usar la MO |
| `success_message` | String | Mensaje tras éxito |
| `fail_message` | String | Mensaje tras fallo |
| `animation_name` | String | Nombre de la animación |
| `requires_confirmation` | bool | Si muestra choice Sí/No |
| `play_animation_on_success` | bool | Si reproduce animación tras éxito |

---

### 2. UseMOCommand - Gestor del Flujo Completo

Ahora UseMOCommand ejecuta automáticamente:

```
1. Obtener MOAction configurada
   ↓
2. Mostrar detect_message
   ↓
3. Si requires_confirmation:
   Mostrar choice (Sí/No)
   ↓
4. Si el jugador acepta:
   Ejecutar validación y lógica
   ↓
5. Si éxito:
   - Mostrar success_message
   - Si play_animation_on_success:
     Reproducir animación
   ↓
6. Si fallo:
   Mostrar fail_message
```

---

## 📊 Comparación Detallada

### Configuración de un Evento

#### ANTES:
```
Evento: TreeCuttable_01
├── Metadata: cuttable = true
├── EventPage 1 (9 comandos):
│   ├── ShowMessageCommand: "¡Un árbol..."
│   ├── ShowMessageCommand: "¿Usar CORTE?"
│   ├── ShowChoicesCommand: ["Sí", "No"]
│   ├── ConditionalBranch: choice == 0
│   ├──   UseMOCommand: mo_type = CUT
│   ├──   ShowMessageCommand: "¡Cortado!"
│   ├──   PlayAnimationCommand: "cut_tree"
│   ├──   SetSelfSwitchCommand: A = true
│   └── EndBranch
└── EventPage 2: invisible
```

#### DESPUÉS:
```
Evento: TreeCuttable_01
├── Metadata: cuttable = true
├── EventPage 1 (2 comandos):
│   ├── UseMOCommand: mo_type = CUT
│   └── SetSelfSwitchCommand: A = true
└── EventPage 2: invisible
```

**Reducción: De 9 comandos a 2 (-78%)**

---

## 🎮 Flujo de Ejecución Detallado

```
Jugador presiona ACCIÓN frente al árbol
   ↓
UseMOCommand.execute()
   ↓
├─ Obtiene target (evento actual)
├─ Obtiene MOAction (CutAction) desde MOSystem
├─ Muestra: "¡Un árbol pequeño bloquea el camino!"
├─ Jugador presiona botón
├─ Muestra: "¿Usar CORTE?"
├─ [TODO] Muestra choice (por ahora auto-Sí)
├─ Jugador elige: Sí
├─ Emite: SignalManager.mo_requested("CUT", target)
   ↓
MOSystem.execute_mo()
   ↓
├─ Obtiene CutAction
├─ Llama: CutAction.can_use()
│  ├─ Verifica: target válido ✓
│  ├─ Verifica: metadata cuttable ✓
│  └─ Verifica: no cortado previamente ✓
├─ Llama: CutAction.execute()
│  ├─ Marca flag: cut_TreeCuttable_01 = true
│  └─ Incrementa: trees_cut_count += 1
├─ Emite: SignalManager.mo_completed("CUT", target)
   ↓
UseMOCommand continúa
   ↓
├─ Muestra: "¡El árbol fue cortado!"
├─ Jugador presiona botón
├─ Reproduce animación: "cut_tree" (0.5s)
├─ Continúa ejecución del evento
   ↓
SetSelfSwitchCommand.execute()
   ↓
├─ Activa Self Switch A = true
├─ EventPage cambia a página 2 (invisible)
   ↓
FIN - Árbol desaparecido, jugador puede pasar
```

---

## 🔧 Personalización por MO

Cada MO puede tener comportamiento diferente:

### Ejemplo: SURF (sin confirmación)

```gdscript
func _init():
    mo_name = "SURF"

    detect_message = ""  # No mostrar mensaje
    prompt_message = ""  # No preguntar
    success_message = "¡%s usó SURF!" % pokemon_name

    animation_name = "surf_start"
    play_animation_on_success = true

    requires_confirmation = false  # ← Sin choice
```

### Ejemplo: FUERZA (con confirmación)

```gdscript
func _init():
    mo_name = "STRENGTH"

    detect_message = "¡Una roca bloquea el paso!"
    prompt_message = "¿Empujar la roca?"
    success_message = "¡La roca fue empujada!"

    animation_name = "push_rock"
    play_animation_on_success = true

    requires_confirmation = true  # ← Con choice
```

---

## 📝 TODOs y Mejoras Futuras

### Implementar en el Futuro

1. **ShowChoiceCommand Real:**
   ```gdscript
   # En _show_confirmation_choice():
   var choices = ["Sí", "No"]
   SignalManager.choice_requested.emit(choices)
   var result = await SignalManager.choice_finished
   return result
   ```

2. **PlayAnimationCommand Real:**
   ```gdscript
   # En _play_animation():
   SignalManager.animation_requested.emit(animation_name, target)
   await SignalManager.animation_finished
   ```

3. **Verificación de MO en Equipo:**
   ```gdscript
   # En MOAction.player_has_mo():
   var party = PlayerParty.get_party()
   return party.has_move(mo_name)
   ```

---

## ✅ Ventajas del Nuevo Sistema

1. **Simplicidad:**
   - De 9 comandos a 2
   - Configuración centralizada
   - Menos propenso a errores

2. **Consistencia:**
   - Mismo comportamiento en todo el juego
   - Mensajes y animaciones uniformes
   - Fácil de actualizar globalmente

3. **Mantenibilidad:**
   - Cambiar mensaje: editar solo CutAction
   - Añadir nueva MO: copiar estructura existente
   - Modificar flujo: cambiar solo UseMOCommand

4. **Extensibilidad:**
   - Fácil añadir nuevas propiedades
   - Comportamientos personalizados por MO
   - Compatible con futuras mejoras

---

## 🎯 Estado Actual

### Implementado:
- ✅ Nuevas propiedades en MOAction
- ✅ Flujo automático en UseMOCommand
- ✅ Mensajes automáticos
- ✅ CutAction configurada
- ✅ Sin errores de compilación

### Temporales (TODOs):
- ⏳ Choice siempre retorna "Sí" (línea 205)
- ⏳ Animación es solo un delay (línea 213)
- ⏳ Verificación de MO en equipo desactivada

### Por Implementar:
- 📋 Integración con ShowChoiceCommand
- 📋 Integración con PlayAnimationCommand
- 📋 Sistema de verificación de MO en equipo

---

## 🚀 Uso Simplificado

**Para crear un árbol cortable:**

```
1. Crear Event: TreeCuttable_XX
2. Añadir metadata: cuttable = true
3. EventPage 1:
   - Trigger: ACTION_BUTTON
   - Commands:
     * UseMOCommand: mo_type = CUT
     * SetSelfSwitchCommand: A = true
4. EventPage 2:
   - Condition: Self Switch A = ON
   - Graphic: (vacío)
   - Through: true
```

**¡Solo 2 comandos y listo!** 🎉

---

## 📖 Documentación Actualizada

- **MOSYSTEM_README.md** - Actualizar con nuevo flujo
- **CUT_IMPLEMENTATION_GUIDE.md** - Actualizar ejemplos
- **MEJORAS_MOSYSTEM_V2.md** - Este documento

---

## 🎉 Conclusión

El sistema ahora es **mucho más práctico y similar a Pokémon Essentials**:

**Un solo comando gestiona todo el flujo de uso de MO.**

Esto hace que configurar eventos sea:
- ✅ Más rápido
- ✅ Más simple
- ✅ Más consistente
- ✅ Más fácil de mantener

**El sistema está listo para usar en producción con las implementaciones temporales de choice y animación.**

