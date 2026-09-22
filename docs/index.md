# PK2D

Documentación técnica del proyecto **PK2D**, un RPG 2D en **Godot 4.7**.

Esta documentación se escribe desde cero. El objetivo es describir cómo está organizado el código y cómo usar cada sistema, no archivar notas de PBI o PRs.

## Contenido

| Sección | Qué cubre |
| --- | --- |
| [Primeros pasos](getting-started.md) | Cómo levantar el proyecto y esta documentación |
| [Arquitectura](architecture/index.md) | Mapa de carpetas, autoloads y [arranque de sesión](architecture/boot.md) |
| [Combate](battle/index.md) | Sistema de batalla |
| [Overworld](overworld/index.md) | Mundo, actores, tiles y contexto |
| [Eventos](events/index.md) | Eventos, comandos y condiciones |
| [Editores](editors/index.md) | Addons `database_editor` y `event_tools` |

## Convención

- Cada página debe responder a *cómo funciona* o *cómo se usa* un sistema.
- Preferir ejemplos cortos y referencias a rutas reales (`Scripts/...`, `Scenes/...`).
- Evitar volcar historial de implementación; eso pertenece a Azure DevOps / git.
