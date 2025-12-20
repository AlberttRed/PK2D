# Funcionalidades Añadidas - PBI 529 y PBI 537

## PBI 529: TileMotionSystem - Sistema de movimientos especiales por tile

### Sistema Centralizado de Movimientos
- **TileMotionSystem**: Sistema coordinador que intercepta movimientos de actores y delega en handlers especializados según el tipo de tile
- **TileMotionHandler**: Clase base para handlers de movimiento especial (similar a TileEffectHandler)
- Integración con `OverworldContext` y `WorldSystem` para gestión de actores y chunks

### LedgeMotionHandler
- Migración de la lógica de saltos de ledge desde `GridMotion` a handler dedicado
- Detección automática de tiles con `custom_data["ledge_direction"]`
- Validación de dirección y tile de aterrizaje
- Bloqueo de control del jugador durante el salto
- Animación de arco con múltiples pasos de animación

### Integración con GridMotion
- `GridMotion` consulta `TileMotionSystem` antes de ejecutar movimiento normal
- Los handlers pueden "consumir" el movimiento y reemplazarlo con animaciones especiales
- Soporte para movimientos asíncronos con `await`

---

## PBI 537: StairMotionHandler - Movimiento diagonal de escaleras

### StairMotionHandler
- Detección de tiles con `custom_data["stair_dir"]` ("right" o "left")
- Movimiento diagonal aplicando offset al sprite durante la transición
- Cálculo de offset vertical según `stair_dir` (up/down) y horizontal según dirección del actor
- Duración extendida (4x) con 3 pasos de animación sincronizados
- Fuerza velocidad normal (ignora estado de "run") durante el movimiento

### Lógica de Dirección
- Si `stair_dir` coincide con la dirección del actor → sube (offset negativo en Y)
- Si no coincide → baja (offset positivo en Y)
- Offset horizontal basado en dirección del movimiento (LEFT/RIGHT)

---

## Mejoras Adicionales

### FadeCommand
- Nuevo flag `wait_for_completion` para controlar si el EventController espera a que termine el fade
- Por defecto `true` (mantiene comportamiento actual)
- Permite ejecutar fades en paralelo sin bloquear la ejecución de eventos

### Sistema de Colisiones con entry_mask
- `_check_player_collision` ahora verifica `can_enter_tile()` antes de activar eventos
- Los eventos de tipo `PLAYER_COLLISION` solo se activan si el jugador realmente puede entrar al tile
- Previene activación incorrecta cuando el tile está bloqueado por `entry_mask`

### Corrección en Occupancy
- Al teleportar al jugador a un tile con evento, se preserva la ocupación del evento
- Los eventos mantienen su registro en `occ[tile]` para que las colisiones funcionen correctamente
- Soluciona el problema de eventos que solo funcionaban la primera vez después de un warp
