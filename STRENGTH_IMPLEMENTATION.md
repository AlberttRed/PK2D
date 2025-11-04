# Implementación de MO FUERZA (STRENGTH)

## ✅ StrengthAction Implementada

Se ha implementado la MO FUERZA siguiendo el mismo patrón que CUT, pero adaptada para empujar rocas.

---

## 🎯 Diferencias con CUT

| Aspecto | CUT | STRENGTH |
|---------|-----|----------|
| **Efecto** | Elimina árbol | Empuja roca |
| **Self-Switch** | Sí (árbol desaparece) | No (roca se mueve) |
| **Estado activo** | No | Posible (modo empuje persistente) |
| **Target** | Evento estático | Evento que se mueve |

---

## 🏗️ StrengthAction.gd

### **1. Validación**

```gdscript
func can_use(player, target):
    // 1. Target válido
    if not target:
        return false

    // 2. Pokémon con STRENGTH en party
    var pokemon = _find_pokemon_with_STRENGTH(player)
    if not pokemon:
        return false

    // 3. TODO: Medalla RAINBOW_BADGE

    return true
```

### **2. Flujo de Ejecución**

```gdscript
func execute(player, target, context):
    var gui = context.get_tree().get_first_node_in_group("GUI")

    // 1. Choice
    var choice = await gui.show_message_with_choices("¿Usas FUERZA?", ["Sí", "No"])
    if choice != 0:
        return {"cancelled": true}

    // 2. Mensaje con nombre del Pokémon
    await gui.show_message("¡%s usó FUERZA!" % pokemon_name)

    // 3. Activar modo de empuje
    var result = await _activate_push_mode(target, player, context)

    return result
```

### **3. Modo de Empuje**

```gdscript
func _activate_push_mode(target, player, context):
    // Verificar que la roca tiene método push()
    if not target.has_method("push"):
        return {"success": false}

    // Obtener dirección del jugador
    var direction = player.get_facing_direction()

    // Empujar la roca
    var can_push = await target.push(direction)

    if not can_push:
        return {"success": false, "error": "Bloqueado"}

    return {"success": true}
```

---

## 🪨 Evento de Roca Empujable

### **Estructura del Evento**

```
RockStrength_01
├── Sprite (roca)
├── GridMotion (para moverse en grid)
└── EventPage 1:
    ├── Trigger: ACTION_BUTTON
    └── Commands:
        └── UseMOCommand:
            ├── mo_type: STRENGTH
            └── activate_self_switch_on_success: ""  ← Vacío (no desaparece)
```

### **Script de la Roca (PushableRock.gd)**

```gdscript
extends Event
class_name PushableRock

## Script para rocas empujables con STRENGTH

# Referencia al GridMotion
@onready var grid_motion = $GridMotion

## Empuja la roca en una dirección
## @param direction: Vector2 (UP, DOWN, LEFT, RIGHT)
## @return: true si se pudo empujar, false si está bloqueado
func push(direction: Vector2) -> bool:
	print("PushableRock: Intentando empujar en dirección %s" % direction)

	# Obtener el grid
	var grid = get_parent()
	if not grid or not grid is OverworldGrid:
		push_error("PushableRock: No está en un OverworldGrid")
		return false

	# Calcular posición siguiente
	var current_tile = grid.world_to_tile(global_position)
	var next_tile = current_tile + Vector2i(direction)

	# Verificar si el tile destino es válido
	if not _can_move_to_tile(next_tile, grid):
		print("PushableRock: Tile bloqueado, no se puede empujar")
		return false

	# Empujar la roca (mover)
	await _move_to_tile(next_tile, grid)

	print("PushableRock: Roca empujada exitosamente a %s" % next_tile)
	return true

## Verifica si la roca puede moverse al tile destino
func _can_move_to_tile(tile: Vector2i, grid: OverworldGrid) -> bool:
	# Verificar colisiones en el grid
	if not grid.is_tile_walkable(tile):
		return false

	# Verificar si hay otro evento/actor en ese tile
	if grid.is_occupied(tile):
		return false

	return true

## Mueve la roca al tile destino con animación suave
func _move_to_tile(tile: Vector2i, grid: OverworldGrid) -> void:
	# Obtener posición mundial del tile
	var target_pos = grid.tile_to_world_center(tile)

	# Actualizar ocupación en el grid
	var current_tile = grid.world_to_tile(global_position)
	grid.vacate(current_tile, self)
	grid.occupy(tile, self)

	# Mover con tween suave
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.3)
	await tween.finished
```

---

## 🎮 Configuración del Evento

### **EventPage 1: Roca Empujable**

```
Trigger: ACTION_BUTTON
Graphic: rock_sprite
Through: false
Priority: SAME_AS_PLAYER

Commands:
  UseMOCommand:
    - mo_type: STRENGTH
    - activate_self_switch_on_success: ""  ← No activar (la roca no desaparece)
```

**Nota:** NO hay EventPage 2 porque la roca no desaparece, solo se mueve.

---

## 🔄 Flujo Completo

```
Jugador presiona ACTION frente a la roca
   ↓
UseMOCommand ejecuta
   ↓
1. Muestra: "Una roca bloquea el camino."
   ↓
2. MOSystem valida can_use()
   ├─ Verifica Pokémon con STRENGTH
   └─ Si no tiene → mo_finished(false) → FIN
   ↓
3. StrengthAction.execute()
   ├─ Choice: "¿Usas FUERZA?"
   ├─ Si No → return cancelled
   ├─ Mensaje: "¡MACHAMP usó FUERZA!"
   ├─ Obtiene dirección del jugador
   ├─ Llama target.push(direction)
   │  ├─ Verifica tile destino válido
   │  ├─ Si bloqueado → return false
   │  ├─ Mueve roca con tween
   │  └─ return true
   └─ return success
   ↓
4. mo_finished(true)
   ↓
5. UseMOCommand NO activa self-switch (vacío)
   ↓
FIN - Roca movida a nueva posición
```

---

## 🎨 Diferencias Clave con CUT

### **CUT:**
```gdscript
// Árbol desaparece
UseMOCommand:
  activate_self_switch_on_success: "A"  ✅
```

### **STRENGTH:**
```gdscript
// Roca se mueve pero no desaparece
UseMOCommand:
  activate_self_switch_on_success: ""  ❌ Vacío
```

---

## 🚀 Modo Persistente (Opcional - Futuro)

Para activar STRENGTH de forma persistente (como en Pokémon):

```gdscript
// En StrengthAction.execute() después de usar
var mo_system = context.get_tree().get_first_node_in_group("MOSystem")
mo_system.activate_effect("STRENGTH_ENABLED", true)

await gui.show_message("¡Ahora puedes mover rocas!")

// En PushableRock.gd
func _on_player_touch():
    var mo_system = get_tree().get_first_node_in_group("MOSystem")

    if mo_system.is_effect_active("STRENGTH_ENABLED"):
        // Empujar automáticamente sin choice
        push(get_push_direction())
    else:
        // Mostrar mensaje de que necesita STRENGTH
        show_message("¡Es muy pesada!")
```

---

## 📝 Para Crear Roca Empujable

**1. Crear Event:** `RockStrength_01`

**2. Añadir Script:** `PushableRock.gd`

**3. Implementar método push():**
```gdscript
func push(direction: Vector2) -> bool:
    // Verificar destino válido
    // Mover con tween
    return true/false
```

**4. EventPage 1:**
```
UseMOCommand: mo_type = STRENGTH
```

**¡Listo!**

---

## ✅ Estado

- ✅ StrengthAction.gd implementada
- ✅ Registrada en MOSystem
- ✅ Verifica Pokémon con STRENGTH
- ✅ Usa nombre del Pokémon
- ✅ Llama a target.push()
- ✅ Sin errores de compilación

**Falta:**
- 📋 Implementar PushableRock.gd con método push()
- 📋 Crear evento de prueba
- 📋 Testing completo

**StrengthAction lista, falta crear el evento roca.** 🪨

