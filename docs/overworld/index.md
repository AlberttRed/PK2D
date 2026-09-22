# Overworld

Documentación del mundo exterior. Código principal en `Scripts/Overworld/` y escenas en `Scenes/Overworld/`.

Antes de profundizar aquí, lee el [arranque de sesión](../architecture/boot.md): explica cómo se crea el `OverworldCoordinator`, el `OverworldContext` y `configure_from_gamestate()`.

## Ubicación

```text
Scripts/Overworld/
  Overworld.gd       # OverworldCoordinator — orquestación
  Core/              # OverworldContext, grids, chunks, movimiento
  Actors/            # Jugador, NPCs, trainers, etc.
```

## Sistemas registrados en el contexto

| Clave | Nodo | Rol breve |
| --- | --- | --- |
| `World` | `WorldSystem` | Mapas, grid activo, jugador |
| `Event` | `EventSystem` | Cola y ejecución de eventos |
| `Warp` | `WarpSystem` | Transiciones entre mapas |
| `MO` | `MOSystem` | Movimientos de campo (corte, fuerza, …) |
| `TileEffect` | `TileEffectSystem` | Efectos al pisar tiles |
| `TileMotion` | `TileMotionSystem` | Movimiento forzado por tiles |
| `WildEncounter` | `WildEncounterSystem` | Encuentros → `DisplayManager.start_battle` |
| `Overlay` | capa de overlay | UI/overlays de overworld |
| `EffectsLayer` | capa de efectos | FX visuales del mundo |
| `Player` | jugador | Se registra al cargarlo `WorldSystem` |

## Alcance previsto

1. Grid / tiles y colisiones
2. Actores (jugador, NPC) y movimiento
3. Chunks / carga de mundo
4. API de `OverworldContext` (señales, `request_*`)
5. Encuentros, hierba y transiciones a combate
6. Integración con el sistema de eventos
