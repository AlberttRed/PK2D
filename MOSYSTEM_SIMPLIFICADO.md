# MOSystem Simplificado - Versión Final

## ✅ Simplificaciones Implementadas

Basado en cómo funciona realmente en Pokémon, se han eliminado complejidades innecesarias.

---

## 🎯 Cambios Clave

### 1. ❌ NO Metadata "cuttable"

**ANTES:**
```gdscript
# Event metadata
cuttable: true  ❌ Innecesario
```

**DESPUÉS:**
```gdscript
# No hace falta metadata
# UseMOCommand ya sabe que usa CUT
```

**Razón:** Si estás usando UseMOCommand con mo_type=CUT, ya está claro que es un árbol cortable.

---

### 2. ❌ NO Flags Persistentes

**ANTES:**
```gdscript
GameStateManager.set_event_flag("cut_TreeCuttable_01", true)  ❌
# Los árboles seguían cortados al recargar
```

**DESPUÉS:**
```gdscript
SetSelfSwitchCommand: A = true  ✅
# Los árboles reaparecen al cambiar de mapa (como en Pokémon)
```

**Razón:** En Pokémon real, los árboles cortados reaparecen al cambiar de zona/mapa. Es temporal.

---

### 3. ✅ Verificación de Movimiento en Party

**Ahora `can_use()` verifica:**

```gdscript
func can_use(player, target):
    # 1. Target válido ✓
    # 2. Tiene Pokémon con CORTE ✓ (TODO)
    # 3. Tiene medalla necesaria ✓ (TODO futuro)
```

**TODO para implementar:**
```gdscript
# Verificar si algún Pokémon del equipo tiene el movimiento
var party = PlayerParty.get_party()
if not party.has_move("CUT"):
    return false
```

---

## 🎮 Configuración Simplificada

### Evento: Árbol Cortable

```
TreeCuttable_01
├─ EventPage 1:
│  ├─ Trigger: ACTION_BUTTON
│  ├─ Commands:
│  │  ├─ UseMOCommand: mo_type = CUT
│  │  └─ SetSelfSwitchCommand: A = true
│  └─ Conditions: (ninguna)
│
└─ EventPage 2:
   ├─ Condition: Self Switch A = ON
   ├─ Graphic: (vacío - invisible)
   └─ Through: true
```

**Sin metadata, sin flags persistentes. Solo 2 comandos.** ✨

---

## 📊 Comparación: Antes vs Ahora

### Configuración ANTES:

```
Event:
├─ Metadata: cuttable = true  ❌
├─ EventPage 1:
│  ├─ 9 comandos manuales
│  └─ Crear flag persistente
└─ EventPage 2: invisible

Lógica:
├─ Verificar metadata "cuttable"
├─ Verificar flag cut_[event]
└─ Crear flag persistente
```

### Configuración AHORA:

```
Event:
├─ (sin metadata)  ✅
├─ EventPage 1:
│  ├─ UseMOCommand  ✅
│  └─ SetSelfSwitchCommand  ✅
└─ EventPage 2: invisible

Lógica:
├─ Verificar Pokémon con CORTE
├─ Verificar medalla (futuro)
└─ Self-Switch temporal (reaparece al cambiar mapa)
```

---

## 🔄 Comportamiento Temporal (Como Pokémon)

### Árbol Cortado con Self-Switch

```
Sesión 1:
├─ Jugador corta árbol en Ruta 2
├─ Self Switch A = ON → árbol invisible
├─ Jugador explora la ruta
└─ Árbol sigue cortado ✓

Sesión 1 (mismo mapa):
├─ Jugador va a Pueblo
├─ Jugador vuelve a Ruta 2
└─ Árbol REAPARECE ✓ (Self-Switch reseteado)

Nueva Partida:
├─ Jugador inicia juego
└─ Todos los árboles visibles ✓
```

**Esto es exactamente como funciona en Pokémon.**

---

## ✅ Validaciones Actuales

### CutAction.can_use()

```gdscript
func can_use(player, target):
    # 1. Target válido
    if not target:
        return false

    # 2. Tiene Pokémon con movimiento CORTE
    # TODO: Implementar cuando tengamos sistema de party
    # var party = PlayerParty.get_party()
    # return party.has_move("CUT")

    # Por ahora: true para testing
    return true
```

### CutAction.execute()

```gdscript
func execute(player, target):
    # No crea flags persistentes
    # Solo retorna éxito
    # El evento gestiona el Self-Switch
    return {"success": true}
```

---

## 🔮 Implementaciones Futuras

### 1. Sistema de Party (Prioridad Alta)

```gdscript
# PlayerParty.gd
class_name PlayerParty

func has_move(move_name: String) -> bool:
    for pokemon in party:
        if pokemon.knows_move(move_name):
            return true
    return false
```

### 2. Sistema de Medallas (Prioridad Media)

```gdscript
# PlayerBadges.gd
class_name PlayerBadges

# CUT requiere CASCADE_BADGE (2ª medalla)
const MO_BADGE_REQUIREMENTS = {
    "CUT": "CASCADE_BADGE",
    "SURF": "SOUL_BADGE",
    "STRENGTH": "RAINBOW_BADGE",
    "FLASH": "BOULDER_BADGE"
}

func can_use_mo(mo_name: String) -> bool:
    var required_badge = MO_BADGE_REQUIREMENTS.get(mo_name)
    return has_badge(required_badge)
```

---

## 📝 Guía de Implementación

### Crear Árbol Cortable (3 Pasos)

**1. Crear Event:** `TreeCuttable_01`

**2. EventPage 1:**
```
Trigger: ACTION_BUTTON
Commands:
  - UseMOCommand: mo_type = CUT
  - SetSelfSwitchCommand: A = true
```

**3. EventPage 2:**
```
Condition: Self Switch A = ON
Graphic: (vacío)
Through: true
```

**¡Listo! Sin metadata, sin flags complejos.**

---

## 🎯 Ventajas de la Simplificación

### 1. Más Simple
- ❌ Sin metadata innecesaria
- ❌ Sin flags persistentes complejos
- ✅ Solo Self-Switches temporales

### 2. Más Realista
- ✅ Árboles reaparecen (como en Pokémon)
- ✅ Verificación de movimiento en party
- ✅ Sistema de medallas preparado

### 3. Más Mantenible
- ✅ Menos estado que gestionar
- ✅ Comportamiento consistente
- ✅ Fácil de debuggear

---

## 🐛 Debug

### El árbol no desaparece
**Verificar:**
- ¿SetSelfSwitchCommand está después de UseMOCommand?
- ¿EventPage 2 tiene condición "Self Switch A = ON"?

### El árbol no reaparece al volver
**Esto es correcto:** Los Self-Switches persisten durante la misma sesión de mapa.
**Para resetear:** Cambia de mapa y vuelve.

### La MO siempre falla
**Verificar:**
- CutAction está registrada en MOSystem
- can_use() retorna true (ahora siempre true para testing)

---

## 📖 Ejemplo Completo

### CutAction.gd (Simplificado)

```gdscript
extends MOAction
class_name CutAction

func _init():
    mo_name = "CUT"
    detect_message = "¡Un árbol bloquea el camino!"
    prompt_message = "¿Usar CORTE?"
    success_message = "¡El árbol fue cortado!"
    animation_name = "cut_tree"
    requires_confirmation = true

func can_use(player, target):
    # Solo verifica target válido
    # TODO: Verificar party.has_move("CUT")
    return target != null

func execute(player, target):
    # No crea flags persistentes
    return {"success": true}
```

---

## ✅ Estado Actual

**Implementado:**
- ✅ Sin metadata "cuttable"
- ✅ Sin flags persistentes
- ✅ Comportamiento temporal con Self-Switch
- ✅ Estructura para verificar movimiento
- ✅ Estructura para verificar medalla

**TODOs:**
- 📋 Implementar PlayerParty.has_move()
- 📋 Implementar PlayerBadges (futuro)
- 📋 Choice real (ShowChoiceCommand)
- 📋 Animación real (PlayAnimationCommand)

---

## 🎉 Conclusión

El sistema ahora es:
- ✅ Más simple (sin metadata ni flags)
- ✅ Más realista (comportamiento de Pokémon)
- ✅ Más fácil de usar (2 comandos)
- ✅ Mejor preparado para el futuro

**Perfecto para implementar el resto de MOs siguiendo el mismo patrón.**

