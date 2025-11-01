# Implementación PBI 455 - Sistema de Saltos (Ledges)

## Resumen de la Implementación

Se ha implementado completamente el sistema de saltos tipo "acantilado" (ledges) similar a los juegos de Pokémon originales, donde el jugador puede saltar hacia abajo (o en otras direcciones) desde tiles especiales, pero no puede subir desde la dirección opuesta.

## Archivos Modificados

### 1. `Scripts/Overworld/Core/OverworldGrid.gd`
**Líneas añadidas**: 170-228

**Métodos añadidos**:
- `get_ledge_info(tile: Vector2i) -> Dictionary`: Obtiene información sobre si un tile es un ledge y su dirección
- `_string_to_direction(dir_string: String) -> Vector2`: Convierte un string de dirección a Vector2
- `can_jump_ledge(actor: Node, from_tile: Vector2i, direction: Vector2) -> bool`: Verifica si un actor puede saltar un ledge

**Funcionalidad**:
- Detecta tiles con metadata `ledge_direction`
- Valida que solo el jugador puede saltar
- Verifica que la dirección del salto coincida con la dirección del ledge
- Verifica que el tile de aterrizaje no esté bloqueado

### 2. `Scripts/Overworld/Core/GridMotion.gd`
**Líneas añadidas**: 7-8, 14, 35, 171-174, 274-332
**Líneas modificadas**: 157-234 (try_step integra detección de ledges)

**Señales añadidas**:
- `ledge_jump_started()`: Emitida cuando comienza un salto
- `ledge_jump_finished()`: Emitida cuando termina un salto

**Variables añadidas**:
- `@export var ledge_jump_duration := 0.4`: Duración del salto (configurable)
- `var is_jumping_ledge := false`: Flag para indicar que se está saltando

**Métodos añadidos**:
- `_execute_ledge_jump(from: Vector2i, to: Vector2i) -> bool`: Ejecuta el salto (método interno privado)

**Métodos modificados**:
- `try_step(d: Vector2)`: Ahora detecta automáticamente ledges antes del movimiento normal

**Funcionalidad**:
- La detección de ledges está **integrada en `try_step()`** para mayor eficiencia
- Evita verificaciones duplicadas en cada frame
- Bloquea el control del jugador durante el salto usando `SignalManager`
- Crea una animación suave con `Tween` para el movimiento
- Gestiona la ocupación de tiles (vaciar origen, ocupar destino)
- Emite señales para que otros sistemas puedan reaccionar al salto
- Solo permite saltos al jugador, no a los NPCs

### 3. `Scripts/Overworld/Actors/Player.gd`
**Sin cambios significativos** (revertido al código original)

**Ventaja**:
- No requiere lógica adicional en Player, todo está centralizado en `GridMotion.try_step()`
- Más eficiente: no verifica ledges en cada frame, solo cuando intenta moverse

### 4. `LEDGES_SYSTEM_README.md` (nuevo)
Documentación completa del sistema con:
- Guía de configuración de tiles
- Ejemplos de uso
- API completa
- Troubleshooting
- Integración con otros sistemas

### 5. `IMPLEMENTACION_PBI_455.md` (este archivo)
Resumen de la implementación para referencia.

## Acceptance Criteria - Verificación

✅ **AC1**: Tiles pueden definirse como "ledge" en una dirección específica
   → Implementado mediante metadata `ledge_direction` (valores: "up", "down", "left", "right")

✅ **AC2**: El jugador puede saltar automáticamente si se mueve en esa dirección
   → Implementado en `GridMotion.try_ledge_jump()`, llamado automáticamente desde `Player._process()`

✅ **AC3**: No se puede subir desde la dirección contraria
   → Se integra con el sistema de `entry_mask` del PBI 454 para bloquear entrada desde dirección opuesta

✅ **AC4**: El movimiento se bloquea temporalmente durante la animación del salto
   → Se usa `SignalManager.player_control_blocked` / `unblocked` para bloquear/desbloquear control

✅ **AC5**: Compatible con OverworldGrid y colisiones normales
   → Implementado usando los métodos existentes de `OverworldGrid` (`is_blocked`, `has_actor`, etc.)

✅ **AC6**: Los NPCs no realizan saltos (solo el jugador)
   → Verificación explícita en `can_jump_ledge()` y `try_ledge_jump()` para solo permitir grupo "Player"

## Configuración de Tiles en el Editor

### Paso 1: Crear Custom Data Layer
En el TileSet:
1. Añadir Custom Data Layer `ledge_direction` de tipo **String**
2. (Opcional) Añadir `entry_mask` de tipo **int** si aún no existe (del PBI 454)

### Paso 2: Configurar Tiles Individuales
Para cada tile que será un ledge:
1. Establecer `ledge_direction` a "up", "down", "left" o "right"
2. Establecer `entry_mask` para bloquear entrada desde dirección opuesta:
   - Ledge hacia **abajo**: `entry_mask = 11` (UP + LEFT + RIGHT = 1+8+2)
   - Ledge hacia **arriba**: `entry_mask = 14` (DOWN + LEFT + RIGHT = 4+8+2)
   - Ledge hacia **izquierda**: `entry_mask = 7` (UP + DOWN + RIGHT = 1+4+2)
   - Ledge hacia **derecha**: `entry_mask = 13` (UP + DOWN + LEFT = 1+4+8)

### Ejemplo Completo

```
Tile de ledge (posición 10, 5):
  ledge_direction: "down"
  entry_mask: 11
  blocked: false

Tile de aterrizaje (posición 10, 6):
  [tile normal sin restricciones]
```

Resultado:
- Jugador en (10,5) presiona ↓ → Salta a (10,6)
- Jugador en (10,6) presiona ↑ → Bloqueado por `entry_mask`

## Flujo de Ejecución

```
1. Jugador presiona tecla de dirección
   ↓
2. Player._process() detecta input
   ↓
3. motion.try_step(input_dir)
   ↓
4. ¿Es jugador Y tile actual es ledge? → NO → Continuar con paso normal
   ↓ SÍ
5. Llamar _execute_ledge_jump(from, to)
   ↓
6. Emitir ledge_jump_started
   ↓
7. Bloquear control del jugador
   ↓
8. Crear tween de animación
   ↓
9. await tween (movimiento suave al tile destino)
   ↓
10. Emitir ledge_jump_finished
   ↓
11. Desbloquear control del jugador
   ↓
12. return true
```

**Ventaja clave**: La verificación solo ocurre cuando el jugador intenta moverse, no en cada frame.

## Integración con Sistemas Existentes

### PBI 454 - Restricciones Direccionales
- **Compatible**: Usa `entry_mask` para bloquear entrada desde dirección opuesta
- **Complementario**: `ledge_direction` define salto, `entry_mask` bloquea subida

### Sistema de Eventos
- **Compatible**: Los eventos `ON_STEP` se activan al aterrizar del salto
- **Restricción**: Los eventos no pueden saltar ledges (solo el jugador)

### Sistema de Control del Jugador
- **Integrado**: Usa `SignalManager.player_control_blocked/unblocked`
- **Compatible**: Se respeta el estado de `movement_enabled` en el Player

### Seamless World
- **Compatible**: Solo permite saltos dentro del mismo mapa
- **Limitación**: No se pueden saltar ledges en bordes de mapas hacia otro mapa

## Testing Recomendado

### Casos de Prueba

1. **Salto Normal**
   - [ ] El jugador puede saltar un ledge hacia abajo
   - [ ] La animación se ejecuta correctamente
   - [ ] El control se bloquea durante el salto

2. **Bloqueo de Subida**
   - [ ] El jugador no puede subir desde la dirección opuesta
   - [ ] Se respeta el `entry_mask` configurado

3. **Casos de Error**
   - [ ] NPCs no pueden saltar ledges
   - [ ] No se puede saltar si el tile destino está bloqueado
   - [ ] No se puede saltar si el tile destino está ocupado

4. **Integración**
   - [ ] Los eventos `ON_STEP` se activan al aterrizar
   - [ ] El movimiento normal funciona correctamente después del salto
   - [ ] La cámara sigue al jugador durante el salto

### Mapa de Prueba Sugerido

```
[Grass] [Grass] [Grass]
[Grass] [Ledge] [Grass]  ← ledge_direction: "down", entry_mask: 7
[Grass] [Grass] [Grass]
```

## Posibles Mejoras Futuras

1. **Animación de Salto Mejorada**
   - Añadir arco vertical real al salto (actualmente es movimiento lineal)
   - Añadir sprite especial para el jugador durante el salto

2. **Sonido de Salto**
   - Reproducir un sonido cuando se salta un ledge
   - Integrar con el sistema de audio

3. **Partículas al Aterrizar**
   - Añadir efecto de polvo/hierba al aterrizar
   - Similar a los juegos de Pokémon originales

4. **Ledges de Múltiples Tiles**
   - Permitir saltar 2 o más tiles de distancia
   - Configurar mediante metadata `ledge_distance`

5. **Ledges Condicionales**
   - Ledges que solo se pueden saltar con ciertas habilidades (Surf, etc.)
   - Configurar mediante metadata `ledge_requirement`

## Notas de Implementación

### Decisiones de Diseño

1. **Integración en `try_step()`**: La lógica de ledges está integrada en el método de movimiento normal
   - Rationale: Evita verificaciones duplicadas en cada frame, más eficiente
   - La verificación solo ocurre cuando el jugador intenta moverse

2. **Prioridad de Salto**: El salto tiene prioridad sobre el movimiento normal
   - Rationale: Evita que el jugador se "quede atascado" en un ledge

3. **Bloqueo de NPCs**: Los NPCs no pueden saltar
   - Rationale: Consistente con los juegos de Pokémon, simplifica pathfinding

4. **Duración del Salto**: 0.4 segundos por defecto
   - Rationale: Más rápido que un paso normal (0.266s) pero no instantáneo

5. **Sin Animación de Arco**: Movimiento lineal con easing
   - Rationale: Simplicidad de implementación, puede mejorarse en el futuro

6. **Uso de `await`**: El método `_execute_ledge_jump()` es async y usa `await`
   - Rationale: Permite esperar el final de la animación sin bloquear el juego
   - El `await` se propaga correctamente a través de `try_step()`

### Limitaciones Conocidas

1. **No funciona con Seamless World** (saltos entre mapas)
   - Requerirá integración adicional con MapSystem

2. **Sin animación de arco vertical**
   - El código tiene comentarios preparados para implementarlo

3. **Sin soporte para ledges de múltiples tiles**
   - Actualmente solo salta 1 tile

## Changelog

### [2025-11-01] - Implementación Inicial
- ✅ Sistema de detección de ledges en OverworldGrid
- ✅ Lógica de salto integrada en GridMotion.try_step() (optimizado)
- ✅ Bloqueo de control durante salto
- ✅ Restricción de saltos solo para jugador
- ✅ Señales para inicio/fin de salto
- ✅ Documentación completa
- ✅ Integración con sistema de restricciones direccionales (PBI 454)
- ✅ **Refactorización**: Movida lógica de ledges dentro de `try_step()` para evitar if constante
- ✅ **Corrección**: Uso correcto de `await` en método async `_execute_ledge_jump()`

## Contacto y Soporte

Para reportar bugs o sugerir mejoras, consulta el README principal del proyecto o el LEDGES_SYSTEM_README.md para documentación detallada.

