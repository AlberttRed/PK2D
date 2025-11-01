# Sistema de Restricciones Direccionales por Tile (PBI 454)

## Descripción General

El sistema de restricciones direccionales permite definir para cada tile del mapa las direcciones desde las cuales se puede entrar y hacia las cuales se puede salir. Esto es útil para reproducir comportamientos como:

- **Bordes de acantilados**: Solo accesibles desde un lado (no se puede subir el acantilado)
- **Zonas de hierba alta**: Se puede entrar pero no salir en ciertas direcciones
- **Caminos de sentido único**: Permiten movimiento en una dirección pero no en la opuesta

## Configuración del TileSet

Para usar el sistema, debes configurar dos Custom Data Layers en tu TileSet:

### 1. Custom Data Layer: `entry_mask`

Define desde qué direcciones se puede **ENTRAR** a este tile.

- **Nombre**: `entry_mask`
- **Tipo**: `int` (Integer)
- **Valor por defecto**: `0` (sin restricciones, se permite entrada desde todas las direcciones)

### 2. Custom Data Layer: `exit_mask`

Define hacia qué direcciones se puede **SALIR** de este tile.

- **Nombre**: `exit_mask`
- **Tipo**: `int` (Integer)
- **Valor por defecto**: `0` (sin restricciones, se permite salida hacia todas las direcciones)

## Valores de las Máscaras

Las máscaras utilizan flags de bits definidos en `DirectionFlagsEnum.Values`:

```gdscript
NONE = 0     # 0b0000 - Sin restricciones
UP = 1       # 0b0001
RIGHT = 2    # 0b0010
DOWN = 4     # 0b0100
LEFT = 8     # 0b1000
ALL = 15     # 0b1111
```

Para combinar direcciones, suma los valores:

| Configuración | Valor | Descripción |
|---------------|-------|-------------|
| Sin restricciones | `0` | Permite movimiento en todas las direcciones |
| Solo arriba | `1` | Solo permite movimiento hacia/desde arriba |
| Solo derecha | `2` | Solo permite movimiento hacia/desde derecha |
| Arriba + Derecha | `3` | Permite movimiento hacia/desde arriba y derecha |
| Solo abajo | `4` | Solo permite movimiento hacia/desde abajo |
| Solo izquierda | `8` | Solo permite movimiento hacia/desde izquierda |
| Abajo + Izquierda | `12` | Permite movimiento hacia/desde abajo e izquierda |
| Todas las direcciones | `15` | Permite movimiento en todas las direcciones |

## Ejemplos de Uso

### Ejemplo 1: Borde de Acantilado

Un tile que representa el borde inferior de un acantilado:

- **exit_mask**: `7` (UP + RIGHT + LEFT = 1 + 2 + 4) - No se puede salir hacia abajo
- **entry_mask**: `7` (UP + RIGHT + LEFT = 1 + 2 + 4) - No se puede entrar desde abajo

Resultado: El jugador puede moverse normalmente por el tile, pero no puede caer desde el acantilado ni subir desde abajo.

### Ejemplo 2: Base del Acantilado

El tile justo debajo del acantilado:

- **exit_mask**: `14` (DOWN + LEFT + RIGHT = 4 + 8 + 2) - No se puede salir hacia arriba
- **entry_mask**: `14` (DOWN + LEFT + RIGHT = 4 + 8 + 2) - No se puede entrar desde arriba

Resultado: No se puede subir el acantilado desde abajo.

### Ejemplo 3: Salto de un Solo Sentido

Un tile donde puedes saltar hacia abajo pero no volver:

- **exit_mask**: `4` (DOWN = 4) - Solo se puede salir hacia abajo
- **entry_mask**: `11` (UP + LEFT + RIGHT = 1 + 8 + 2) - Se puede entrar desde cualquier lado excepto desde abajo

### Ejemplo 4: Escalera Mecánica

Escalera que solo permite subir (movimiento hacia arriba):

- **exit_mask**: `1` (UP = 1) - Solo se puede salir hacia arriba
- **entry_mask**: `4` (DOWN = 4) - Solo se puede entrar desde abajo

## Modo Debug

El sistema incluye un modo debug visual para ver las restricciones en tiempo real.

### Activar el Modo Debug

1. Selecciona el nodo `OverworldGrid` en tu escena
2. En el inspector, activa la casilla `Debug Show Directional Restrictions`
3. Las restricciones se mostrarán con flechas de colores:
   - **Flechas ROJAS**: Direcciones de SALIDA permitidas (`exit_mask`)
   - **Flechas VERDES**: Direcciones de ENTRADA permitidas (`entry_mask`)

### Interpretar las Flechas

- Si ves una flecha roja hacia arriba, significa que se puede **salir** del tile hacia arriba
- Si ves una flecha verde hacia la izquierda, significa que se puede **entrar** al tile desde la izquierda
- Si un tile no tiene flechas, significa que no tiene restricciones (todas las direcciones permitidas)

## Implementación Técnica

### Funciones Principales

#### `can_exit_tile(from_tile: Vector2i, direction: Vector2) -> bool`

Verifica si se puede salir de un tile en una dirección específica.

```gdscript
# Ejemplo de uso
var can_exit = grid.can_exit_tile(Vector2i(5, 3), Vector2.DOWN)
if can_exit:
    print("Se puede salir del tile hacia abajo")
```

#### `can_enter_tile(to_tile: Vector2i, direction: Vector2) -> bool`

Verifica si se puede entrar a un tile desde una dirección específica.

```gdscript
# Ejemplo de uso
var can_enter = grid.can_enter_tile(Vector2i(5, 4), Vector2.DOWN)
if can_enter:
    print("Se puede entrar al tile desde arriba (movimiento hacia abajo)")
```

#### `can_step_to(actor: Node, from: Vector2i, to: Vector2i) -> bool`

La función principal que verifica si un actor puede moverse de un tile a otro. Ahora incluye las verificaciones direccionales automáticamente.

### Integración con el Sistema Existente

El sistema está completamente integrado con:

- ✅ **Player movement**: El jugador respeta automáticamente las restricciones
- ✅ **NPC movement**: Los NPCs también respetan las restricciones
- ✅ **Seamless world**: Compatible con el sistema de mapas continuos
- ✅ **Colisiones existentes**: No interfiere con el sistema de colisiones actual

## Notas de Diseño

### Comportamiento por Defecto

- **Si no se define custom data**: El tile no tiene restricciones (comportamiento clásico)
- **Si el valor es 0**: Sin restricciones (todas las direcciones permitidas)
- **Si el valor es diferente de 0**: Solo las direcciones con el bit activo están permitidas

### Orden de Verificación

Cuando un actor intenta moverse, el sistema verifica en este orden:

1. ¿El tile destino está bloqueado? (`is_blocked`)
2. ¿Hay otro actor en el tile destino? (`has_actor`)
3. ¿El tile está reservado por otro actor? (`res`)
4. ¿Se puede salir del tile origen en esa dirección? (`can_exit_tile`)
5. ¿Se puede entrar al tile destino desde esa dirección? (`can_enter_tile`)

Si cualquiera de estas verificaciones falla, el movimiento se bloquea.

## Configuración Paso a Paso en Godot

### Paso 1: Configurar el TileSet

1. Abre tu TileSet en el editor
2. Ve a la pestaña "TileSet" en el inspector
3. En "Custom Data Layers", añade dos nuevas capas:
   - Nombre: `entry_mask`, Tipo: `int`
   - Nombre: `exit_mask`, Tipo: `int`

### Paso 2: Configurar Tiles Individuales

1. Selecciona un tile en el TileSet
2. En el inspector, verás las dos propiedades personalizadas
3. Calcula el valor de la máscara según las direcciones que quieres permitir
4. Introduce el valor en `entry_mask` y/o `exit_mask`

### Paso 3: Activar Debug (Opcional)

1. En tu escena del mapa, selecciona el nodo `OverworldGrid`
2. Activa `Debug Show Directional Restrictions`
3. Ejecuta la escena y verás las flechas de colores

### Paso 4: Probar el Sistema

1. Coloca al jugador cerca de un tile con restricciones
2. Intenta moverte en diferentes direcciones
3. El jugador debería respetar las restricciones configuradas

## Solución de Problemas

### Las restricciones no funcionan

- ✅ Verifica que los nombres de custom data son exactamente `entry_mask` y `exit_mask`
- ✅ Asegúrate de que el tipo de dato es `int` (Integer)
- ✅ Verifica que los valores de las máscaras son correctos
- ✅ Comprueba que el tile tiene TileData (no es un tile vacío)

### El modo debug no muestra flechas

- ✅ Asegúrate de que `Debug Show Directional Restrictions` está activado
- ✅ Verifica que el tile tiene valores de `entry_mask` o `exit_mask` diferentes de 0
- ✅ Comprueba que hay una cámara 2D en la escena

### El jugador se mueve de forma extraña

- ✅ Revisa los valores de las máscaras, pueden estar invertidos
- ✅ Verifica que no hay tiles con restricciones superpuestas
- ✅ Asegúrate de que la lógica de entrada/salida es coherente entre tiles adyacentes

## Compatibilidad

- **Godot Version**: 4.x
- **Compatible con**: Player, NPC, Event
- **Compatible con sistemas**: Seamless World, Wild Encounters, Event System

## Referencias

- **PBI**: 454
- **Archivo de implementación**: `Scripts/Overworld/Core/OverworldGrid.gd`
- **Enum de direcciones**: `Scripts/Enums/DirectionFlagsEnum.gd` → `DirectionFlagsEnum.Values`

