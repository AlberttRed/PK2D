# Sistema de Saltos (Ledges) - PBI 455

## Descripción General

El sistema de ledges permite al jugador saltar hacia abajo desde tiles especiales tipo "acantilado" (como en los juegos originales de Pokémon). Cuando el jugador intenta **entrar a un tile ledge**, salta automáticamente **2 tiles en total** (pasa por el ledge y aterriza 1 tile después) en una dirección específica con una animación de arco (el sprite sube y baja), pero no puede subir ni entrar al ledge desde la dirección opuesta.

## Características Implementadas

✅ Tiles pueden definirse como "ledge" con una dirección específica mediante metadata `ledge_direction`
✅ El jugador salta automáticamente cuando se mueve en la dirección del ledge
✅ No se puede subir desde la dirección contraria (usar `entry_mask` del PBI 454)
✅ El movimiento se bloquea temporalmente durante la animación del salto
✅ Compatible con `OverworldGrid` y colisiones normales
✅ Los NPCs **no** pueden realizar saltos (solo el jugador)
✅ Señales para reaccionar al inicio y fin del salto

## Configuración de Tiles

### 1. Definir un Ledge

En el TileSet, añade una **Custom Data Layer** llamada `ledge_direction` de tipo **String**:

1. Abre tu TileSet en el editor
2. Ve a la pestaña "Custom Data Layers"
3. Añade una nueva layer:
   - **Nombre**: `ledge_direction`
   - **Tipo**: `String`

### 2. Configurar Tiles Individuales

Para cada tile que quieras convertir en ledge:

1. Selecciona el tile en el editor de TileSet
2. En el panel "TileSet" → "Select" → [tu tile]
3. Ve a la sección "Custom Data"
4. Establece `ledge_direction` a uno de estos valores:
   - `"down"` - Se puede saltar hacia abajo
   - `"up"` - Se puede saltar hacia arriba
   - `"left"` - Se puede saltar hacia la izquierda
   - `"right"` - Se puede saltar hacia la derecha

### 3. Bloquear Entrada desde la Dirección Opuesta

Para evitar que el jugador suba al ledge desde abajo, usa el sistema de restricciones direccionales del **PBI 454**:

1. Añade una Custom Data Layer `entry_mask` de tipo `int`
2. Configura la máscara para el tile del ledge:
   - Para un ledge que salta hacia **abajo**: `entry_mask = 11` (permite entrada desde UP, LEFT, RIGHT pero NO desde DOWN)
   - Para un ledge que salta hacia **arriba**: `entry_mask = 14` (permite entrada desde DOWN, LEFT, RIGHT pero NO desde UP)
   - Para un ledge que salta hacia **izquierda**: `entry_mask = 7` (permite entrada desde UP, DOWN, RIGHT pero NO desde LEFT)
   - Para un ledge que salta hacia **derecha**: `entry_mask = 13` (permite entrada desde UP, DOWN, LEFT pero NO desde RIGHT)

### 🎯 Tabla Rápida de entry_mask para Ledges

| Tipo de Ledge | `ledge_direction` | `entry_mask` | Cálculo | Qué Bloquea |
|---------------|-------------------|--------------|---------|-------------|
| Salta hacia ABAJO ⬇ | `"down"` | **11** | 1+8+2 (UP+LEFT+RIGHT) | Entrada desde abajo |
| Salta hacia ARRIBA ⬆ | `"up"` | **14** | 4+8+2 (DOWN+LEFT+RIGHT) | Entrada desde arriba |
| Salta hacia DERECHA ⮕ | `"right"` | **13** | 1+4+8 (UP+DOWN+LEFT) | Entrada desde derecha |
| Salta hacia IZQUIERDA ⬅ | `"left"` | **7** | 1+4+2 (UP+DOWN+RIGHT) | Entrada desde izquierda |

**Valores base** (para cálculos personalizados):
- `UP = 1`
- `RIGHT = 2`
- `DOWN = 4`
- `LEFT = 8`

**Ejemplo**: Para un ledge hacia abajo, quieres permitir entrada desde arriba, izquierda y derecha:
```
entry_mask = UP + LEFT + RIGHT = 1 + 8 + 2 = 11
```

**💡 Tip**: Para más detalles sobre cómo calcular máscaras, consulta `MASCARAS_DIRECCIONALES_GUIA.md`

## Ejemplo de Uso

### Configuración Típica de un Ledge hacia Abajo

```
Tile en posición (10, 4):
  - [tile normal - jugador está aquí]

Tile en posición (10, 5):
  - ledge_direction: "down"  ← EL LEDGE
  - entry_mask: 11  (UP + LEFT + RIGHT = 1 + 8 + 2)
  - blocked: false

Tile en posición (10, 6):
  - [tile de aterrizaje - debe estar libre]
```

Cuando el jugador:
- **Está en (10,4) y presiona ↓** → Detecta que (10,5) es un ledge → Salta automáticamente **2 tiles** hasta (10,6) con animación de arco
- **Intenta moverse hacia arriba desde (10,6)** → Bloqueado por `entry_mask` del ledge (10,5)
- **Se mueve hacia izquierda/derecha** → Movimiento normal

## API del Sistema

### OverworldGrid

#### `get_ledge_info(tile: Vector2i) -> Dictionary`
Obtiene información sobre si un tile es un ledge y su dirección.

**Retorna**:
```gdscript
{
    "is_ledge": bool,      # true si el tile es un ledge
    "direction": Vector2   # Dirección del salto (Vector2.DOWN, etc.)
}
```

#### `can_jump_ledge(actor: Node, from_tile: Vector2i, direction: Vector2) -> bool`
Verifica si un actor puede saltar un ledge en la dirección especificada.

**Parámetros**:
- `actor`: Actor que intenta saltar (debe estar en el grupo "Player")
- `from_tile`: Tile de origen (debe ser un ledge)
- `direction`: Dirección del salto

**Retorna**: `true` si puede saltar, `false` si no

### GridMotion

#### `try_step(d: Vector2) -> bool`
Intenta realizar un paso (o salto si es un ledge). La lógica de ledges está integrada automáticamente.

**Parámetros**:
- `d`: Dirección del movimiento/salto

**Retorna**: `true` si se realizó el movimiento/salto, `false` si no

**Nota**: Este método detecta automáticamente si el tile es un ledge y ejecuta el salto sin necesidad de verificaciones adicionales.

#### Señales

```gdscript
signal ledge_jump_started()   # Emitida cuando comienza un salto
signal ledge_jump_finished()  # Emitida cuando termina un salto
```

#### Variables

```gdscript
@export var ledge_jump_duration := 0.5   # Duración del salto (en segundos)
@export var ledge_jump_height := 12.0    # Altura del arco del salto (en píxeles)
var is_jumping_ledge := false            # true durante un salto
```

## Flujo de Ejecución

1. El jugador presiona una tecla de dirección
2. `Player._process()` detecta el input y llama a `motion.try_step(input_dir)`
3. `GridMotion.try_step()`:
   - **Primero** verifica si el actor es el jugador Y el tile actual es un ledge
   - Si es un ledge válido:
     - Llama a `_execute_ledge_jump()` (método interno)
     - Emite `ledge_jump_started`
     - Bloquea el control del jugador (`SignalManager.player_control_blocked`)
     - Crea un tween para animar el salto
     - Mueve al jugador al tile de aterrizaje
     - Emite `ledge_jump_finished`
     - Desbloquea el control del jugador (`SignalManager.player_control_unblocked`)
   - Si **no** es un ledge, continúa con la lógica de paso normal
4. Este enfoque evita verificaciones duplicadas y es más eficiente

## Integración con Sistemas Existentes

### Compatibilidad con PBI 454 (Restricciones Direccionales)

El sistema de ledges se integra perfectamente con el sistema de restricciones direccionales:

- **exit_mask**: Controla desde qué direcciones se puede **salir** de un tile
- **entry_mask**: Controla desde qué direcciones se puede **entrar** a un tile
- **ledge_direction**: Define la dirección del salto automático

**Recomendación**: Para ledges, usa `entry_mask` para bloquear la entrada desde la dirección opuesta al salto.

### Compatibilidad con Eventos

Los eventos del sistema de eventos (PBI anterior) funcionan normalmente:
- Si hay un evento en el tile de aterrizaje con trigger `ON_STEP`, se activará al aterrizar
- Los eventos no pueden realizar saltos (solo el jugador)

### Compatibilidad con Seamless World

El sistema de ledges funciona con el sistema de mundo seamless:
- Si el tile de aterrizaje está en otro mapa, el salto no se realizará (bloqueado)
- Para ledges en bordes de mapas, asegúrate de que el tile de aterrizaje existe en el mismo mapa

## Notas Técnicas

### Bloqueo de Control

Durante un salto, el control del jugador se bloquea usando el `SignalManager`:
```gdscript
SignalManager.player_control_blocked.emit()   # Bloquear
SignalManager.player_control_unblocked.emit() # Desbloquear
```

### Animación del Salto

La animación del salto usa dos `Tween` paralelos:

1. **Movimiento horizontal/vertical** (2 tiles):
   - Duración: `ledge_jump_duration` (por defecto 0.5 segundos)
   - Easing: `EASE_IN_OUT`
   - Transición: `TRANS_QUAD`

2. **Arco visual del sprite**:
   - **Sube** en la primera mitad del salto (-ledge_jump_height píxeles)
   - **Baja** en la segunda mitad hasta volver a 0
   - Usa `sprite.offset.y` para no afectar colisiones
   - Altura: `ledge_jump_height` (por defecto 12 píxeles)

3. **Animación del sprite** (2 pasos alternados en el aire):
   - Se emite `step_started` al **inicio del salto** → PASO 1 (ej: walk_down_left)
   - Se alterna `stride_is_left` para cambiar de pie
   - Se emite `step_started` a **mitad del salto** → PASO 2 (ej: walk_down_right)
   - Se alterna `stride_is_left` de nuevo para el siguiente movimiento
   - El sprite hace 2 pasos completos **alternando el pie** (left → right)
   - Simula que el jugador está caminando 2 tiles en el aire (como en Pokémon)

Para personalizar:
- `GridMotion.ledge_jump_duration`: Duración total del salto
- `GridMotion.ledge_jump_height`: Altura del arco en píxeles

### NPCs y Ledges

Los NPCs **no pueden** saltar ledges. Si un NPC intenta moverse hacia un ledge:
- `try_ledge_jump()` retorna `false` (no está en el grupo "Player")
- El movimiento se bloquea como un tile normal bloqueado

## Troubleshooting

### El jugador no salta

**Posibles causas**:
1. El tile no tiene `ledge_direction` configurado
2. La dirección del movimiento no coincide con `ledge_direction`
3. El tile de aterrizaje está bloqueado o ocupado
4. El jugador no está en el grupo "Player"

**Solución**: Verifica la configuración del tile y los logs de consola.

### El jugador puede subir al ledge

**Causa**: No está configurado el `entry_mask` correctamente.

**Solución**: Configura `entry_mask` para bloquear la entrada desde la dirección opuesta al salto.

### El salto es muy rápido/lento

**Solución**: Ajusta `ledge_jump_duration` en `GridMotion` (inspector o código).

### El arco del salto es muy alto/bajo

**Solución**: Ajusta `ledge_jump_height` en `GridMotion` (inspector o código). Valores típicos: 8-16 píxeles.

### El sprite no mantiene el frame durante el salto

**Solución**: Verifica que el AnimatedSprite2D se llama exactamente `AnimatedSprite2D` en la escena del Player.

## Ejemplos de Configuración

### Ledge Simple hacia Abajo
```
Tile (10, 4):
  [césped normal - jugador está aquí]

Tile (10, 5):
  ledge_direction: "down"  ← LEDGE
  entry_mask: 11  # UP + LEFT + RIGHT = 1+8+2
  blocked: false

Tile (10, 6):
  [tile de aterrizaje - césped normal]
```

**Resultado**: Jugador en (10,4) presiona ↓ → Entra al ledge (10,5) y salta con arco hasta (10,6) (2 tiles total)

### Serie de Ledges en Escalera
```
Tile (10, 4):
  [césped - jugador empieza aquí]

Tile (10, 5):
  ledge_direction: "down"  ← LEDGE 1
  entry_mask: 11

Tile (10, 6):
  [césped - aterrizaje del primer salto]

Tile (10, 7):
  ledge_direction: "down"  ← LEDGE 2
  entry_mask: 11

Tile (10, 8):
  [césped - aterrizaje final]
```

El jugador:
1. En (10,4) presiona ↓ → Salta de (10,4) hasta (10,6) pasando por ledge (10,5)
2. En (10,6) presiona ↓ → Salta de (10,6) hasta (10,8) pasando por ledge (10,7)

**⚠️ Importante**: El ledge debe tener 1 tile libre después (no bloqueado) para el aterrizaje.

## Testing

Para probar el sistema:

1. Crea un mapa de prueba con ledges
2. Configura algunos tiles con:
   - `ledge_direction: "down"`
   - `entry_mask: 11` (para bloquear entrada desde abajo)
3. Ejecuta el juego y prueba:
   - Saltar hacia abajo (debe funcionar automáticamente)
   - Intentar subir (debe estar bloqueado)
   - Moverse en direcciones laterales (debe hacer paso normal)

## Changelog

### v1.0 (PBI 455)
- ✅ Implementado sistema de detección de ledges en `OverworldGrid`
- ✅ Implementado salto automático de **2 tiles** en `GridMotion`
- ✅ Añadida **animación de arco** usando sprite.offset.y
- ✅ El sprite **hace 2 pasos alternados** (emite `step_started` dos veces y alterna `stride_is_left`)
- ✅ **Soporte para sombra circular** durante el salto (opcional, ver `SHADOW_SETUP_GUIDE.md`)
- ✅ Bloqueado saltos para NPCs
- ✅ Añadidas señales `ledge_jump_started` y `ledge_jump_finished`
- ✅ Integración con sistema de control del jugador
- ✅ Compatible con restricciones direccionales (PBI 454)
- ✅ Variables configurables: `ledge_jump_duration` y `ledge_jump_height`

## Sombra durante el Salto (Opcional)

El sistema incluye soporte para mostrar una **sombra circular** debajo del sprite durante el salto, como en los juegos de Pokémon originales.

**Configuración**:
1. Añade un nodo `Sprite2D` llamado `Shadow` como hijo del `Player`
2. Asigna el sprite de sombra (círculo negro difuminado)
3. Establece `Visible: false` y `Z Index: -1`

**Consulta la guía completa**: `SHADOW_SETUP_GUIDE.md`

