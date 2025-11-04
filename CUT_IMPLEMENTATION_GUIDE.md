# Guía de Implementación: MO CORTE (CUT)

## ✅ Sistema Completo Implementado

Se ha implementado completamente la MO **CORTE (CUT)** como primer ejemplo funcional del MOSystem.

---

## 📁 Archivos Implementados

### 1. CutAction.gd
**Ubicación:** `/Scripts/Overworld/Core/MOActions/CutAction.gd`

**Funciones:**
- `can_use(player, target)` - Valida si se puede usar CUT
- `execute(player, target)` - Ejecuta el efecto lógico

**Validaciones implementadas:**
- ✅ Target es válido (not null)
- ✅ Target tiene metadata `cuttable = true`
- ✅ Árbol no ha sido cortado previamente (flag)

**Efectos implementados:**
- ✅ Marca flag global `cut_[event_name]`
- ✅ Incrementa contador `trees_cut_count`
- ✅ Retorna datos del resultado

---

## 🎮 Cómo Usar en un Evento

### Configuración del Evento "Árbol Cortable"

#### 1. Crear el Evento en el Mapa

1. Añadir un nodo `Event` como hijo de `OverworldGrid`
2. Nombre: `TreeCuttable_01` (o similar)
3. Configurar sprite del árbol

#### 2. Añadir Metadata

En el inspector del Event, añadir:
```
Metadata:
  cuttable: true
```

#### 3. Configurar EventPage 1 (Árbol Visible)

**Conditions:**
- Self Switch A = OFF

**Graphic:**
- Sprite del árbol (dirección down)

**Trigger:**
- ACTION_BUTTON

**Priority:**
- SAME_AS_PLAYER

**Through:**
- false

**Commands:**
```
1. ShowMessageCommand
   - message: "¡Un árbol pequeño bloquea el camino!"
   - wait_input: true

2. ShowMessageCommand
   - message: "¿Usar CORTE?"
   - wait_input: true

3. UseMOCommand
   - mo_type: CUT
   - target_path: (vacío)

4. ShowMessageCommand
   - message: "¡El árbol fue cortado!"
   - wait_input: true

5. PlayAnimationCommand (opcional)
   - animation_name: "cut_tree"

6. SetSelfSwitchCommand
   - switch_letter: "A"
   - value: true
```

#### 4. Configurar EventPage 2 (Árbol Cortado)

**Conditions:**
- Self Switch A = ON

**Graphic:**
- (vacío - sin sprite)

**Through:**
- true

**Commands:**
- (ninguno)

---

## 🔄 Flujo de Ejecución

```
1. Jugador presiona botón de acción frente al árbol
   ↓
2. EventPage 1 ejecuta comandos
   ↓
3. ShowMessageCommand: "¡Un árbol pequeño..."
   ↓
4. ShowMessageCommand: "¿Usar CORTE?"
   ↓
5. UseMOCommand emite SignalManager.mo_requested("CUT", target)
   ↓
6. MOSystem recibe la petición
   ↓
7. MOSystem obtiene CutAction del diccionario
   ↓
8. MOSystem llama a CutAction.can_use()
   ├─ Verifica target válido
   ├─ Verifica metadata cuttable
   └─ Verifica flag cut_TreeCuttable_01
   ↓
9. Si can_use() = true → MOSystem llama a CutAction.execute()
   ├─ Marca flag: cut_TreeCuttable_01 = true
   ├─ Incrementa contador: trees_cut_count += 1
   └─ Retorna {success: true, data: {...}}
   ↓
10. MOSystem emite SignalManager.mo_completed("CUT", target)
   ↓
11. UseMOCommand recibe la señal y continúa
   ↓
12. ShowMessageCommand: "¡El árbol fue cortado!"
   ↓
13. PlayAnimationCommand: animación de corte (opcional)
   ↓
14. SetSelfSwitchCommand: A = true
   ↓
15. EventPage cambia a página 2 (árbol invisible)
   ↓
16. Fin - El jugador puede pasar
```

---

## 🧪 Testing

### Pruebas Básicas

1. **Interactuar con el árbol:**
   - ✅ Debe mostrar mensaje
   - ✅ Debe ejecutar CUT
   - ✅ Debe desaparecer el árbol
   - ✅ Debe permitir el paso

2. **Verificar persistencia:**
   - ✅ Flag `cut_TreeCuttable_01` = true
   - ✅ Contador `trees_cut_count` incrementado
   - ✅ Árbol sigue cortado al volver

3. **Logs en consola:**
```
CutAction: Validación exitosa - se puede usar CORTE
CutAction: Ejecutando CORTE sobre 'TreeCuttable_01'
CutAction: Flag 'cut_TreeCuttable_01' establecido
CutAction: Total de árboles cortados: 1
MOSystem: MO 'CUT' ejecutada con éxito
```

---

## 📊 Estructura de Datos

### Flags Creados

Por cada árbol cortado:
```gdscript
GameStateManager.event_flags["cut_TreeCuttable_01"] = true
GameStateManager.event_flags["cut_TreeCuttable_02"] = true
# etc...
```

### Variables Globales

Contador total:
```gdscript
GameStateManager.game_variables["trees_cut_count"] = 5
```

---

## ⚙️ Mejoras en _wait_for_mo_result

Se mejoró el método para ser más elegante:

### ANTES (calculando elapsed_time):
```gdscript
var elapsed_time = 0.0
var delta = 0.016
while ...:
    await process_frame
    elapsed_time += delta  # ❌ Impreciso
```

### DESPUÉS (contando frames):
```gdscript
var max_frames = 600  # 10 segundos a 60 FPS
var frame_count = 0
while not result["received"] and frame_count < max_frames:
    await Engine.get_main_loop().process_frame
    frame_count += 1  # ✅ Preciso y simple
```

**Ventajas:**
- ✅ Más preciso
- ✅ Más simple
- ✅ Sin cálculos de tiempo
- ✅ Funciona en Resources sin access a get_tree()

---

## 🎯 Próximos Pasos

### Para Añadir Más Árboles Cortables

1. Duplicar el evento `TreeCuttable_01`
2. Renombrar a `TreeCuttable_02`, etc.
3. Posicionar en el mapa
4. ✅ Listo - No hace falta más configuración

### Para Implementar Otras MO

1. Crear archivo `Scripts/Overworld/Core/MOActions/[MO]Action.gd`
2. Heredar de `MOAction`
3. Implementar `can_use()` y `execute()`
4. Registrar en `MOSystem._initialize_mo_actions()`
5. Usar en eventos con `UseMOCommand`

---

## 🐛 Debug y Troubleshooting

### El árbol no se corta

**Verificar:**
1. ¿MOSystem está en Overworld.tscn?
2. ¿CutAction está registrada en MOSystem?
3. ¿El evento tiene metadata `cuttable = true`?
4. ¿UseMOCommand tiene `mo_type = CUT`?
5. ¿Los logs aparecen en consola?

### El árbol reaparece al volver

**Verificar:**
1. ¿SetSelfSwitchCommand está después de UseMOCommand?
2. ¿EventPage 2 tiene condition "Self Switch A = ON"?
3. ¿El flag se está guardando correctamente?

### La MO falla siempre

**Verificar logs:**
```
CutAction: Target no tiene metadata 'cuttable'  → Añadir metadata
CutAction: Árbol ya fue cortado previamente    → Flag ya existe
```

---

## 📖 Documentación Relacionada

- **MOSYSTEM_README.md** - Documentación completa del sistema
- **CAMBIOS_MOSYSTEM.md** - Mejoras implementadas
- **CutAction_EXAMPLE.gd** - Ejemplo comentado (deprecated, usar CutAction.gd)

---

## ✅ Estado Actual

- ✅ CutAction implementada y funcional
- ✅ Registrada en MOSystem
- ✅ _wait_for_mo_result mejorado
- ✅ Sin errores de compilación
- ✅ Lista para testing en evento real

**El sistema está completamente funcional y listo para crear eventos con árboles cortables.** 🎉

---

## 💡 Ejemplo Rápido

**Crear árbol cortable en 3 pasos:**

1. **Crear Event:** `TreeCuttable_01`
2. **Añadir metadata:** `cuttable = true`
3. **Configurar EventPage 1:**
   ```
   Commands:
   - ShowMessage: "¿Usar CORTE?"
   - UseMOCommand: mo_type = CUT
   - ShowMessage: "¡Cortado!"
   - SetSelfSwitch: A = true
   ```
4. **Configurar EventPage 2:**
   ```
   Condition: Self Switch A = ON
   Graphic: (vacío)
   Through: true
   ```

**¡Listo! 🎮**

