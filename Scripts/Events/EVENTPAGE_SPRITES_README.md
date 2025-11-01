# EventPage - Sistema de Sprites

## Descripción

El sistema de sprites de `EventPage` ofrece tres formas diferentes de asignar gráficos a un evento, según el tipo de evento que necesites crear.

## Opciones Disponibles

### 1. Character Spritesheet (Para NPCs)

**Cuándo usar**: NPCs con movimiento, personajes animados con direcciones múltiples

**Ventajas**:
- Genera automáticamente 16+ animaciones (walk/run en 4 direcciones)
- Compatible con spritesheets estilo Pokémon/RPG Maker (4x4)
- Ideal para personajes que se mueven por el mapa

**Cómo configurar**:
```gdscript
@export_group("Auto-generate from Spritesheet")
character_spritesheet = preload("res://Sprites/Characters/npc_01.png")
frame_size = Vector2(32, 48)  # Ancho x Alto de cada frame
```

**Layout esperado del spritesheet (4x4)**:
```
Row 0: Down  [idle | step_right | idle | step_left]
Row 1: Left  [idle | step_right | idle | step_left]
Row 2: Right [idle | step_right | idle | step_left]
Row 3: Up    [idle | step_right | idle | step_left]
```

**Animaciones generadas**:
- `walk_down_left`, `walk_down_right`
- `walk_left_left`, `walk_left_right`
- `walk_right_left`, `walk_right_right`
- `walk_up_left`, `walk_up_right`
- `run_down_left`, `run_down_right`
- `run_left_left`, `run_left_right`
- `run_right_left`, `run_right_right`
- `run_up_left`, `run_up_right`
- `idle` (con 4 frames: down, left, right, up)

---

### 2. Simple Texture (Para Eventos Estáticos)

**Cuándo usar**: Items, objetos, cofres, puertas, interruptores, cualquier evento con una imagen estática

**Ventajas**:
- Muy fácil de configurar (solo arrastra una imagen)
- Genera automáticamente un SpriteFrames con animación "default"
- Perfecto para eventos que no necesitan múltiples animaciones
- Ideal para objetos estáticos en el mapa

**Cómo configurar**:
```gdscript
@export_group("Simple Static Sprite")
simple_texture = preload("res://Sprites/Items/potion.png")
```

**Animación generada**:
- `default` (con 1 frame: la imagen asignada)

**Ejemplos de uso**:
- Items en el suelo (Poción, Pokébola, etc.)
- Cofres cerrados
- Interruptores
- Carteles/señales
- Objetos decorativos interactivos
- Puertas (estado inicial)

---

### 3. Sprite Frames Manual (Para Casos Personalizados)

**Cuándo usar**: Eventos con animaciones personalizadas complejas, múltiples estados animados

**Ventajas**:
- Control total sobre las animaciones
- Puedes definir animaciones personalizadas con nombres específicos
- Ideal para eventos únicos o complejos

**Cómo configurar**:
```gdscript
sprite_frames = preload("res://Resources/Animations/custom_event.tres")
```

**Ejemplos de uso**:
- Cofres con animación de apertura (frames: closed, opening_1, opening_2, opened)
- Puertas con animación de apertura/cierre
- Interruptores con animación de cambio de estado
- Eventos especiales con múltiples animaciones personalizadas

**Definir animaciones manualmente**:
1. Crear un recurso `SpriteFrames` desde el inspector
2. Añadir animaciones con nombres específicos:
   - `chest_closed`, `chest_open`, `chest_opening`
   - `door_closed`, `door_open`, `door_opening`
   - `switch_off`, `switch_on`
3. Añadir los frames correspondientes a cada animación
4. Usar `PlayAnimationCommand` para reproducir las animaciones

---

## Orden de Prioridad

El sistema evalúa las opciones en este orden:

1. **character_spritesheet** → Si está asignado, genera automáticamente animaciones de NPC
2. **simple_texture** → Si está asignado, genera un SpriteFrames simple con 1 frame
3. **sprite_frames** → Si está asignado, usa el SpriteFrames personalizado
4. **null** → Sin sprite (evento invisible)

**Importante**: Solo debes asignar **UNA** de estas opciones. Si asignas múltiples, se usará la de mayor prioridad.

---

## Ejemplos Prácticos

### Ejemplo 1: NPC que camina por el mapa

```gdscript
# EventPage del NPC
@export_group("Auto-generate from Spritesheet")
character_spritesheet = preload("res://Sprites/Overworlds/NPC/youngster.png")
frame_size = Vector2(32, 48)

# El NPC puede usar GridMotion y ActorAnimator para moverse
# Las animaciones se generan automáticamente
```

### Ejemplo 2: Item estático (Poción en el suelo)

```gdscript
# EventPage del Item
@export_group("Simple Static Sprite")
simple_texture = preload("res://Sprites/Items/potion_item.png")

# Comando de evento:
EventPage:
  trigger_type = ACTION
  commands = [
    ShowMessageCommand { message = "¡Encontraste una Poción!" },
    # Añadir item al inventario (futuro)
    SetSelfSwitchCommand { switch_letter = "A", value = true }  # Desaparece
  ]
```

### Ejemplo 3: Cofre con animación personalizada

```gdscript
# EventPage del Cofre
sprite_frames = preload("res://Resources/Animations/chest_animations.tres")

# SpriteFrames "chest_animations.tres" contiene:
# - Animación "closed" (1 frame: cofre cerrado)
# - Animación "opening" (3 frames: animación de apertura)
# - Animación "open" (1 frame: cofre abierto)

# Comando de evento:
EventPage:
  trigger_type = ACTION
  commands = [
    PlayAnimationCommand { animation_name = "opening", wait_until_finished = true },
    ShowMessageCommand { message = "¡Encontraste una Poción!" },
    SetSelfSwitchCommand { switch_letter = "A", value = true }
  ]

# Segunda página (después de abrir)
EventPage:
  required_self_switch = A
  required_self_switch_value = true
  sprite_frames = preload("res://Resources/Animations/chest_animations.tres")
  commands = [
    ShowMessageCommand { message = "El cofre está vacío." }
  ]
  # El sprite mostrará automáticamente el frame "open" si lo configuras
```

### Ejemplo 4: Puerta con dos estados (cerrada/abierta)

```gdscript
# Página 0: Puerta cerrada
EventPage 0:
  @export_group("Simple Static Sprite")
  simple_texture = preload("res://Sprites/Objects/door_closed.png")
  
  required_flag = "door_opened"
  required_flag_value = false
  
  commands = [
    ShowMessageCommand { message = "La puerta está cerrada." }
  ]

# Página 1: Puerta abierta
EventPage 1:
  @export_group("Simple Static Sprite")
  simple_texture = preload("res://Sprites/Objects/door_open.png")
  
  required_flag = "door_opened"
  required_flag_value = true
  
  through = true  # El jugador puede pasar
  commands = []  # Sin comandos, solo atraviesa
```

---

## Casos de Uso Recomendados

### ✅ Usar character_spritesheet:
- NPCs con movimiento aleatorio o en ruta
- Personajes animados con múltiples direcciones
- Trainers que detectan al jugador
- Cualquier evento que necesite animaciones direccionales

### ✅ Usar simple_texture:
- Items en el suelo
- Objetos estáticos interactivos
- Carteles/señales
- Eventos con una sola imagen
- Cofres cerrados (estado inicial simple)
- Interruptores (estado inicial simple)

### ✅ Usar sprite_frames:
- Cofres con animación de apertura
- Puertas con animación de apertura/cierre
- Interruptores con animación de cambio de estado
- Objetos con múltiples estados animados
- Eventos especiales con animaciones únicas

### ✅ No usar sprite (null):
- Eventos invisibles que solo ejecutan lógica
- Triggers de zona
- Eventos AUTORUN sin representación visual

---

## Integración con PlayAnimationCommand

El comando `PlayAnimationCommand` funciona con cualquiera de las opciones, pero es más útil con **sprite_frames** personalizado:

### Con character_spritesheet (generado):
```gdscript
# Puedes usar las animaciones generadas automáticamente
PlayAnimationCommand { animation_name = "idle", wait_until_finished = false }
# Nota: Las animaciones de movimiento ya se manejan automáticamente por GridMotion
```

### Con simple_texture (generado):
```gdscript
# Solo tiene animación "default"
PlayAnimationCommand { animation_name = "default", wait_until_finished = false }
# Nota: No es muy útil para simple_texture ya que solo tiene 1 frame
```

### Con sprite_frames (manual) - ¡Ideal!:
```gdscript
# Aquí es donde PlayAnimationCommand brilla
PlayAnimationCommand { animation_name = "chest_opening", wait_until_finished = true }
PlayAnimationCommand { animation_name = "door_open", wait_until_finished = true }
PlayAnimationCommand { animation_name = "switch_on", wait_until_finished = false }
```

---

## Tips y Trucos

### 💡 Tip 1: Usar self-switches para cambiar de página
```gdscript
# Página 0: Cofre cerrado
EventPage 0:
  simple_texture = preload("res://Sprites/Objects/chest_closed.png")
  required_self_switch = A
  required_self_switch_value = false
  commands = [
    ShowMessageCommand { message = "¡Encontraste una Poción!" },
    SetSelfSwitchCommand { switch_letter = "A", value = true }
  ]

# Página 1: Cofre abierto
EventPage 1:
  simple_texture = preload("res://Sprites/Objects/chest_open.png")
  required_self_switch = A
  required_self_switch_value = true
  commands = [
    ShowMessageCommand { message = "El cofre está vacío." }
  ]
```

### 💡 Tip 2: Combinar simple_texture con flags globales
```gdscript
# Ideal para eventos que afectan el mundo (interruptores, puertas)
EventPage 0:
  simple_texture = preload("res://Sprites/Objects/switch_off.png")
  required_flag = "puzzle_solved"
  required_flag_value = false
  commands = [
    PlayAnimationCommand { animation_name = "activating", wait_until_finished = true },
    SetFlagCommand { flag_name = "puzzle_solved", value = true },
    ShowMessageCommand { message = "¡El puzzle se resolvió!" }
  ]

EventPage 1:
  simple_texture = preload("res://Sprites/Objects/switch_on.png")
  required_flag = "puzzle_solved"
  required_flag_value = true
  commands = []
```

### 💡 Tip 3: Events invisibles con lógica
```gdscript
# No asignar ninguna opción de sprite (null)
EventPage:
  trigger_type = AUTORUN
  commands = [
    # Lógica de evento sin representación visual
    SetFlagCommand { flag_name = "entered_room", value = true },
    ShowMessageCommand { message = "Sientes una presencia..." }
  ]
```

---

## Ver También

- [PlayAnimationCommand_README.md](Commands/PlayAnimationCommand_README.md) - Comando para reproducir animaciones
- [SpriteFramesGenerator.gd](../Tools/SpriteFramesGenerator.gd) - Generador de SpriteFrames desde spritesheets
- [IMPLEMENTACION_PBI_284_350.md](../../IMPLEMENTACION_PBI_284_350.md) - Sistema de NPCs y ActorAnimator
- [Event.gd](Event.gd) - Sistema de eventos principal


