# Sistema de NPCs

## Descripción

El sistema de NPCs está construido como una extensión del sistema de eventos (`Event`), permitiendo que los NPCs se comporten como eventos interactivos (diálogos, combates, cutscenes) mientras mantienen capacidades avanzadas de movimiento, animación y colisión.

## Componentes

### ActorAnimator
Componente reutilizable para gestionar animaciones de actores del overworld.

**Ubicación:** `Scripts/Overworld/Core/ActorAnimator.gd`

**Métodos principales:**
- `play(anim_name: String)`: Reproduce una animación por nombre
- `set_direction(dir: Vector2, prefix: String, stride: String)`: Establece dirección y reproduce animación
- `idle(dir: Vector2)`: Reproduce animación idle en una dirección
- `stop()`: Detiene la animación actual
- `set_speed_scale(scale: float)`: Ajusta la velocidad de reproducción
- `set_sprite_frames(frames: SpriteFrames)`: Cambia el conjunto de animaciones

### NPC
Clase que hereda de `Event` y añade capacidades de movimiento.

**Ubicación:** `Scripts/Overworld/Actors/NPC.gd`

**Propiedades exportadas:**
- `movement_type`: Tipo de movimiento (Fixed=0, Random=1, Path=2, LookAtPlayer=3)
- `initial_direction`: Dirección inicial del NPC - Enum (Up=0, Down=1, Left=2, Right=3)
- `movement_speed`: Velocidad de movimiento - Enum (Slowest=0, Slower=1, Normal=2, Faster=3, Fastest=4)
- `random_move_interval_min/max`: Intervalo entre movimientos aleatorios (solo visible si movement_type = Random)
- `path_directions`: Array de direcciones para movimiento por ruta (solo visible si movement_type = Path)
- `look_delay`: Duración del delay cuando ejecuta un comando LOOK (solo visible si movement_type = Path)

**💡 Tip:** Las propiedades se muestran/ocultan automáticamente en el Inspector según el `movement_type` seleccionado para mantener la interfaz limpia.

**Velocidades de movimiento disponibles:**

El `movement_speed` del NPC se convierte a multiplicador y se asigna a `GridMotion.base_speed`:

| Enum | Valor | Multiplicador | Tiempo/Tile | Uso Típico |
|------|-------|---------------|-------------|------------|
| Slowest | 0 | 0.5x | ~0.53s | 🐌 Ancianos, NPCs muy lentos |
| Slower | 1 | 0.75x | ~0.35s | 🚶 Caminata relajada |
| Normal | 2 | 1.0x | ~0.27s | 🚶‍♂️ Velocidad estándar (por defecto) |
| Faster | 3 | 1.5x | ~0.18s | 🏃 Caminata rápida |
| Fastest | 4 | 2.0x | ~0.13s | 🏃‍♂️ Correr |

**Nota:** El Player usa `base_speed = 1.0` y controla la velocidad con el botón "run" (actualiza `GridMotion.is_running`). Los NPCs usan una velocidad fija configurada, pero pueden activar temporalmente `motion.is_running = true` si necesitan "correr" en situaciones específicas (ej: perseguir al jugador).

**Métodos principales:**
- `stop_movement()`: Detiene el movimiento actual
- `set_movement_enabled(enabled: bool)`: Habilita/deshabilita el movimiento
- `teleport_to_tile(tile: Vector2i)`: Teletransporta el NPC a una posición
- `set_facing_direction(direction: Vector2)`: Establece la dirección que mira el NPC

## Estructura de la Escena NPC

```
NPC (hereda de Event)
 ├── GridMotion        # Gestiona el movimiento en grid
 ├── Occupancy         # Gestiona la ocupación de tiles
 ├── ActorAnimator     # Gestiona las animaciones
 │   └── AnimatedSprite2D
 ├── AnimatedSprite2D  # Del Event padre (oculto automáticamente)
 └── Occupancy         # Del Event padre
```

## Tipos de Movimiento

### 1. Fixed (0)
El NPC permanece en su posición sin moverse.

### 2. Random (1)
El NPC elige aleatoriamente una acción de la lista configurada.
- Configura `random_move_interval_min` y `random_move_interval_max` para controlar la frecuencia.

**Configuración de acciones:**
- `random_actions`: Array de acciones disponibles (UP, DOWN, LEFT, RIGHT, LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT)
  - Si está **vacío**: Solo movimiento (UP, DOWN, LEFT, RIGHT) - comportamiento por defecto
  - Si tiene **solo movimientos**: Se moverá aleatoriamente sin LOOK
  - Si tiene **solo LOOK**: Solo girará sin moverse
  - Si tiene **ambos**: Mezclará movimientos y giros
- `random_look_delay`: Duración del LOOK en segundos (por defecto 0.5s)

**Ejemplos de configuración:**
- `[]` (vacío) → Solo movimiento
- `[UP, DOWN, LEFT, RIGHT]` → Solo movimiento (igual que vacío)
- `[LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT]` → Solo giros, sin movimiento
- `[UP, DOWN, LOOK_LEFT, LOOK_RIGHT]` → 50% movimiento vertical, 50% giros laterales

### 3. Path (2)
El NPC sigue una ruta predefinida en bucle.
- Define la ruta en `path_directions` como un array de `DirectionEnum.Type`

#### Comandos de Movimiento:
- **UP** (0) - Mueve 1 tile arriba
- **DOWN** (1) - Mueve 1 tile abajo
- **LEFT** (2) - Mueve 1 tile izquierda
- **RIGHT** (3) - Mueve 1 tile derecha

#### Comandos de Orientación (solo mirar, sin moverse):
- **LOOK_UP** (4) - Gira para mirar arriba
- **LOOK_DOWN** (5) - Gira para mirar abajo
- **LOOK_LEFT** (6) - Gira para mirar izquierda
- **LOOK_RIGHT** (7) - Gira para mirar derecha

#### 💡 Sobre el "Initial Step"
En Pokémon, cuando cambias de dirección con el input del jugador, primero haces un giro rápido antes de moverte. **Los NPCs en rutas predefinidas NO tienen este problema** porque el sistema ajusta automáticamente el `hold_time` para evitarlo.

**Los comandos LOOK son opcionales** y útiles para:
- Hacer que el NPC mire en una dirección sin moverse
- Añadir pausas visuales en la ruta (ej: el guardia mira alrededor antes de continuar)
- Control preciso de la orientación del NPC

**Nota:** Los comandos LOOK tienen un delay configurable (`look_delay`, por defecto 0.5 segundos) para que el giro sea visible. Puedes ajustarlo en el Inspector:
- `look_delay = 0.3` → Giro rápido
- `look_delay = 0.5` → Giro normal (por defecto)
- `look_delay = 1.0` → Giro lento / pausa larga

#### Ejemplo: Cuadrado simple (sin LOOK)
```gdscript
# Los movimientos funcionan correctamente sin necesidad de LOOK
path_directions = [RIGHT, RIGHT, DOWN, DOWN, LEFT, LEFT, UP, UP]
# Resultado: Cuadrado perfecto de 2x2 tiles
```

#### Ejemplo: Cuadrado con pausas visuales (con LOOK)
```gdscript
# Añadir LOOK para que el NPC "mire alrededor" antes de girar
path_directions = [
    RIGHT, RIGHT, LOOK_DOWN,      # Derecha y mira abajo
    DOWN, DOWN, LOOK_LEFT,         # Abajo y mira izquierda
    LEFT, LEFT, LOOK_UP,           # Izquierda y mira arriba
    UP, UP, LOOK_RIGHT             # Arriba y mira derecha
]
# El NPC hace un cuadrado y gira la cabeza en cada esquina
```

### 4. Look At Player (3)
El NPC permanece fijo pero gira automáticamente para mirar hacia el jugador.

## Uso Básico

### Crear un NPC en el Editor

1. Instancia la escena `Scenes/Overworld/Actors/NPC.tscn`
2. Configura las propiedades en el Inspector:
   - `movement_type`: Selecciona el tipo de movimiento deseado
   - `initial_direction`: Establece la dirección inicial
   - Configura el `ActorAnimator` con el SpriteFrames apropiado
3. Si el NPC debe tener interacciones, añade `EventPage` como en cualquier evento:
   - Configura trigger_type (Action, Touch, Autorun)
   - Añade comandos (ShowMessage, StartBattle, etc.)

### Ejemplo: NPC con Movimiento Aleatorio (Simple)

```gdscript
# Configuración en el Inspector:
movement_type = 1  # Random
movement_speed = 2  # Normal
random_move_interval_min = 2.0
random_move_interval_max = 5.0
initial_direction = 1  # Down
```

### Ejemplo: NPC Anciano Lento

```gdscript
# Configuración en el Inspector:
movement_type = 1  # Random
movement_speed = 0  # Slowest (0.5x) - Movimiento muy lento
random_move_interval_min = 3.0
random_move_interval_max = 6.0  # También más tiempo entre movimientos
initial_direction = 1  # Down
```

### Ejemplo: NPC con Movimiento Aleatorio + LOOK (Vigilante)

```gdscript
# Configuración en el Inspector:
movement_type = 1  # Random
random_move_interval_min = 1.5
random_move_interval_max = 3.0
random_actions = [UP, DOWN, LEFT, RIGHT, LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT]
random_look_delay = 0.8
initial_direction = 1  # Down

# Resultado: 50% movimiento, 50% LOOK (8 acciones, 4 de cada tipo)
```

### Ejemplo: NPC Guardia que Vigila sin Moverse

```gdscript
# Configuración en el Inspector:
movement_type = 1  # Random
random_move_interval_min = 2.0
random_move_interval_max = 4.0
random_actions = [LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT]
random_look_delay = 1.0
initial_direction = 1  # Down

# Resultado: El NPC se queda en su posición pero mira en todas direcciones (vigilando)
```

### Ejemplo: NPC con Ruta Definida (Patrulla Vertical)

```gdscript
# Configuración en el Inspector:
movement_type = 2  # Path
movement_speed = 2  # Normal
path_directions = [DOWN, DOWN, UP, UP]

# Resultado: Baja 2 tiles, sube 2 tiles (patrulla vertical simple)
```

### Ejemplo: Guardia Rápido en Patrulla

```gdscript
# Configuración en el Inspector:
movement_type = 2  # Path
movement_speed = 4  # Fastest (2.0x) - Patrulla a velocidad de carrera
path_directions = [RIGHT, RIGHT, DOWN, DOWN, LEFT, LEFT, UP, UP]

# Resultado: Cuadrado de 2x2 tiles a velocidad de carrera
```

### Ejemplo Avanzado: NPC que Corre Temporalmente (Futuro)

```gdscript
# Si en el futuro quieres que un NPC corra bajo ciertas condiciones:
func chase_player():
    motion.is_running = true  # Activar carrera temporalmente
    var direction = _calculate_direction_to_player()
    motion.try_step(direction)  # Este paso será a velocidad de carrera (2.0x)
    
func stop_chasing():
    motion.is_running = false  # Volver a velocidad normal
```

### Ejemplo: NPC con Ruta Compleja (Cuadrado)

```gdscript
movement_type = 2  # Path
path_directions = [RIGHT, RIGHT, DOWN, DOWN, LEFT, LEFT, UP, UP]

# Resultado: Cuadrado perfecto de 2x2 tiles
```

### Ejemplo: NPC Guardia con Comportamiento Realista

```gdscript
movement_type = 2  # Path
path_directions = [
    RIGHT, RIGHT, LOOK_DOWN, LOOK_UP, LOOK_LEFT,  # Camina y mira alrededor
    LEFT, LEFT, LOOK_DOWN, LOOK_UP, LOOK_RIGHT    # Regresa mirando alrededor
]

# Resultado: El guardia patrulla 2 tiles y mira en varias direcciones (vigilando)
```

### Ejemplo: NPC Interactivo con Diálogo

1. Crea un NPC con `movement_type = 0` (Fixed)
2. Añade una EventPage al NPC
3. Configura la página:
   - `trigger_type = ACTION` (se activa al presionar el botón de interacción)
   - Añade un comando `ShowMessage` con el texto del diálogo
4. Opcionalmente, añade un SpriteFrames al EventPage para cambiar la apariencia

## Compatibilidad con Sistema de Eventos

Los NPCs son totalmente compatibles con el sistema de eventos:

- Pueden tener múltiples `EventPage` con diferentes condiciones
- Soportan todos los comandos de eventos (ShowMessage, StartBattle, Transfer, etc.)
- Pueden cambiar de página durante la ejecución
- Respetan las propiedades `through`, `blocks_movement`, etc.

## Notas Técnicas

### Animaciones
El ActorAnimator espera animaciones con el siguiente formato de nombres:
- `walk_<direction>_<stride>` (ej: walk_down_left, walk_up_right)
- `run_<direction>_<stride>` (ej: run_down_left, run_up_right)
- `idle` (con frames 0=down, 1=left, 2=right, 3=up)

Donde:
- `<direction>` puede ser: up, down, left, right
- `<stride>` puede ser: left, right (alterna entre pasos)

### Herencia de Event
El NPC hereda de Event, pero oculta automáticamente el AnimatedSprite2D del evento padre para usar el del ActorAnimator. Esto permite mantener compatibilidad con el sistema de eventos mientras se usa el nuevo sistema de animación.

### Integración con GridMotion y Occupancy
El NPC reutiliza los componentes `GridMotion` y `Occupancy` del sistema de overworld, asegurando consistencia con el movimiento del jugador y la gestión de colisiones.

