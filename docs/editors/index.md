# Editores

Addons de Godot usados para contenido y herramientas internas.

## Plugins activos

Habilitados en `project.godot`:

| Plugin | Ruta | Uso previsto |
| --- | --- | --- |
| Database Editor | `addons/database_editor` | Edición de datos / DB del juego |
| Event Tools | `addons/event_tools` | Edición de eventos en el editor |

## Alcance previsto

### Database Editor

- Qué datos edita
- Dónde se guardan los Resources / archivos
- Cómo los consume `DatabaseService` en runtime

### Event Tools

- Cómo crear / editar un evento en una escena
- Relación con `Scripts/Events/`
- Limitaciones conocidas del editor

## Notas

!!! tip "Documentar flujos de usuario"
    En esta sección prioriza capturas y pasos del editor frente a detalle de implementación.
