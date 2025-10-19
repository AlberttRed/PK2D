# SpriteFrames Generator

Sistema automático para generar `SpriteFrames` desde spritesheets 4x4.

## Problema que resuelve

Antes tenías que:
1. Crear manualmente un `SpriteFrames` con 16+ animaciones
2. Cortar manualmente cada frame del spritesheet
3. Configurar cada animación (walk_up_left, walk_up_right, etc.)
4. Repetir esto para cada NPC con diferente sprite

**Ahora solo arrastras un PNG** y se genera todo automáticamente.

---

## Formato del spritesheet (4x4)

Layout estándar **RPG Maker / Pokémon** (por filas):

```
       Col 0      Col 1        Col 2      Col 3
       (idle)   (step_right)   (idle)   (step_left)
       
Row 0  [DOWN ]  [DOWN walk]   [DOWN ]  [DOWN walk]  ← Y=0   : Abajo
Row 1  [LEFT ]  [LEFT walk]   [LEFT ]  [LEFT walk]  ← Y=48  : Izquierda
Row 2  [RIGHT]  [RIGHT walk]  [RIGHT]  [RIGHT walk] ← Y=96  : Derecha
Row 3  [UP   ]  [UP walk  ]   [UP   ]  [UP walk  ]  ← Y=144 : Arriba
```

**Cómo funciona:**
- Cada **FILA** = una dirección (down, up, left, right)
- **Col 0 y 2** = frames idle (pose base)
- **Col 1** = step_right (pie derecho adelante)
- **Col 3** = step_left (pie izquierdo adelante)

**Tamaño de cada frame**: 32x48 píxeles (configurable)

---

## Uso en EventPage (NPCs/Eventos)

### Opción 1: Generación automática (recomendado)

En el Inspector del EventPage:

```
EventPage
├── Sprite Frames: null  ← Dejar vacío
└── Auto-generate from Spritesheet
    ├── Character Spritesheet: [arrastrar trchar001.png]
    └── Frame Size: (32, 48)
```

El sistema generará automáticamente:
- `walk_down_left`, `walk_down_right`
- `walk_up_left`, `walk_up_right`
- `walk_left_left`, `walk_left_right`
- `walk_right_left`, `walk_right_right`
- `run_down_left`, `run_down_right`, ... (mismos frames, más rápido)
- `idle` (todos los frames base)

### Opción 2: Manual (para animaciones únicas)

Si necesitas animaciones personalizadas:

```
EventPage
├── Sprite Frames: [asignar SpriteFrames manual]
└── Auto-generate from Spritesheet
    └── Character Spritesheet: null  ← Dejar vacío
```

---

## Ventajas

✅ **Automático**: Solo arrastras el PNG  
✅ **Retrocompatible**: No rompe SpriteFrames existentes  
✅ **Por página**: Cada EventPage puede tener sprite diferente  
✅ **Sin duplicación**: No creas recursos redundantes  
✅ **Estándar**: Funciona con el formato Pokémon clásico  

---

## API del generador

Si necesitas usarlo manualmente en código:

```gdscript
var texture = preload("res://Sprites/Characters/npc_01.png")
var frames = SpriteFramesGenerator.generate_from_4x4_spritesheet(
    texture,
    Vector2(32, 48),  # Frame size
    7.5,              # Walk speed
    15.0              # Run speed
)
```

---

## Notas técnicas

- **Prioridad**: Si hay `character_spritesheet`, se genera automáticamente. Si no, usa `sprite_frames` manual.
- **Cache**: Cada vez que cambias de EventPage se regenera el SpriteFrames (ligero costo de performance, pero imperceptible).
- **Compatibilidad**: Funciona con `Event`, `NPC` y cualquier clase que use `EventPage`.

