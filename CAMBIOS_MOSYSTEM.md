# Cambios en el Sistema de MOs - Mejoras de Diseño

## 📋 Resumen de Cambios

Se han implementado las siguientes mejoras al sistema de MOs basadas en feedback del usuario:

---

## ✅ Cambios Implementados

### 1. **Nuevo Enum: MOTypeEnum** 🆕

**Archivo:** `/Scripts/Enums/MOTypeEnum.gd`

Se ha creado un enum tipado para los tipos de MO, reemplazando el uso de Strings:

```gdscript
enum Type {
    CUT,           # CORTE
    SURF,          # SURF
    STRENGTH,      # FUERZA
    FLASH,         # DESTELLO
    ROCK_SMASH,    # GOLPE ROCA
    WATERFALL,     # CASCADA
    DIVE,          # BUCEO
    ROCK_CLIMB,    # TREPARROCAS
    FLY,           # VUELO
    WHIRLPOOL,     # TORBELLINO
    DEFOG,         # DESPEJAR
    HEADBUTT       # GOLPE CABEZA
}
```

**Ventajas:**
- ✅ Seguridad de tipos (evita errores de tipeo)
- ✅ Autocompletado en el editor
- ✅ Validación en tiempo de compilación
- ✅ Más mantenible y escalable

**Métodos útiles:**
- `MOTypeEnum.type_to_string(mo_type)` - Convierte enum a String
- `MOTypeEnum.from_string(mo_name)` - Convierte String a enum
- `MOTypeEnum.get_description(mo_type)` - Obtiene descripción
- `MOTypeEnum.requires_target(mo_type)` - Verifica si necesita target

---

### 2. **Simplificación de UseMOCommand** 🔧

**Archivo:** `/Scripts/Events/Commands/UseMOCommand.gd`

#### Propiedades ANTES:
```gdscript
@export var mo_type: String = "CUT"
@export var target_path: NodePath = NodePath()
@export var use_source_event_as_target: bool = true
@export var remove_target_on_success: bool = false
```

#### Propiedades DESPUÉS:
```gdscript
@export var mo_type: MOTypeEnum.Type = MOTypeEnum.Type.CUT
@export var target_path: NodePath = NodePath()
```

**Cambios:**
- ❌ **Eliminado:** `use_source_event_as_target`
- ❌ **Eliminado:** `remove_target_on_success`
- ✅ **Simplificado:** `mo_type` ahora es un enum
- ✅ **Lógica simplificada:** Si `target_path` está vacío → usa evento de origen, sino → usa el path especificado

---

### 3. **Lógica Simplificada de Target** 📍

#### ANTES (compleja):
```gdscript
if use_source_event_as_target:
    usar_evento_origen()
elif not target_path.is_empty():
    usar_node_path()
else:
    fallback_a_evento_origen()
```

#### DESPUÉS (simple):
```gdscript
if target_path.is_empty():
    usar_evento_origen()
else:
    usar_node_path()
```

**Ventaja:** Más claro y fácil de entender.

---

### 4. **Gestión de Target desde EventPage** 🎯

La eliminación o desactivación del target ahora se gestiona **desde las EventPages** usando:

- **SetSelfSwitchCommand:** Para activar/desactivar páginas
- **Condiciones en EventPages:** Mostrar páginas diferentes según estado
- **Comandos de visibilidad:** Control fino desde el evento

#### Ejemplo de Configuración:

**EventPage 1** (árbol visible):
- **Conditions:** Self Switch A = OFF
- **Commands:**
  1. ShowMessageCommand: "¡Árbol cortable!"
  2. UseMOCommand: mo_type = CUT
  3. ShowMessageCommand: "¡Cortado!"
  4. PlayAnimationCommand: "cut_animation"
  5. SetSelfSwitchCommand: A = true

**EventPage 2** (árbol cortado - invisible):
- **Conditions:** Self Switch A = ON
- **Graphic:** (vacío - invisible)
- **Through:** true
- **Commands:** (ninguno)

---

## 📊 Comparación Antes/Después

### Configuración de UseMOCommand

| Aspecto | ANTES | DESPUÉS |
|---------|-------|---------|
| Tipo de MO | `String "CUT"` | `MOTypeEnum.Type.CUT` |
| Propiedades | 4 propiedades | 2 propiedades |
| Target | Lógica compleja (3 opciones) | Lógica simple (2 opciones) |
| Eliminación target | En comando | En EventPage |
| Seguridad tipos | ❌ String sin validar | ✅ Enum validado |

### Ejemplo de Uso

#### ANTES:
```gdscript
UseMOCommand:
  mo_type: "CUT"
  target_path: NodePath()
  use_source_event_as_target: true
  remove_target_on_success: false
```

#### DESPUÉS:
```gdscript
UseMOCommand:
  mo_type: MOTypeEnum.Type.CUT
  target_path: (vacío)
```

**Reducción:** De 4 propiedades a 2 ✨

---

## 📁 Archivos Modificados

### Nuevos Archivos:
- ✅ `Scripts/Enums/MOTypeEnum.gd` (nuevo)
- ✅ `Scripts/Enums/MOTypeEnum.gd.uid` (nuevo)
- ✅ `CAMBIOS_MOSYSTEM.md` (este archivo)

### Archivos Modificados:
- ✏️ `Scripts/Events/Commands/UseMOCommand.gd` (simplificado)
- ✏️ `Scripts/Overworld/Core/MOActions/CutAction_EXAMPLE.gd` (actualizado)
- ✏️ `MOSYSTEM_README.md` (actualizado)
- ✏️ `IMPLEMENTACION_PBI_427.md` (actualizado)

---

## 🎓 Guía de Migración

Si ya tenías eventos configurados con el sistema anterior:

### 1. Cambiar tipo de MO de String a Enum

**Antes:**
```gdscript
mo_type: "CUT"
```

**Después:**
```gdscript
mo_type: MOTypeEnum.Type.CUT
```

### 2. Simplificar target

**Antes:**
```gdscript
target_path: NodePath()
use_source_event_as_target: true
```

**Después:**
```gdscript
target_path: (dejar vacío)
```

### 3. Gestionar eliminación con EventPages

**Antes:**
```gdscript
remove_target_on_success: true
```

**Después:**
```gdscript
# Añadir después del UseMOCommand:
SetSelfSwitchCommand: A = true

# Y crear EventPage 2 con:
# - Condition: Self Switch A = ON
# - Graphic: (vacío)
# - Through: true
```

---

## ✅ Ventajas de los Cambios

1. **Más Simple:** Menos propiedades = menos confusión
2. **Más Seguro:** Enum evita errores de tipeo
3. **Más Flexible:** Control total desde EventPages
4. **Más Claro:** Lógica de target directa y fácil de entender
5. **Más Mantenible:** Cambios futuros son más sencillos

---

## 📖 Recursos

- **MOSYSTEM_README.md** - Documentación completa del sistema
- **IMPLEMENTACION_PBI_427.md** - Detalles de implementación
- **CutAction_EXAMPLE.gd** - Ejemplo actualizado con los nuevos cambios

---

## 🎯 Estado Final

- ✅ MOTypeEnum creado y funcional
- ✅ UseMOCommand simplificado
- ✅ Documentación actualizada
- ✅ Ejemplos actualizados
- ✅ Sin errores de compilación
- ✅ Listo para usar

**El sistema está optimizado y listo para producción.** 🚀

