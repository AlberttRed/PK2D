# Eventos

Sistema de eventos estilo RPG Maker (páginas, comandos, condiciones, triggers). Código en `Scripts/Events/`.

## Ubicación

```text
Scripts/Events/
  Event.gd / EventPage.gd / EventController.gd / EventSystem.gd
  Commands/      # Comandos ejecutables (mover, diálogo, batalla, etc.)
  Conditions/    # Condiciones de página
  Triggers/      # Cómo se dispara un evento
  Enums/
```

Editor asociado: `addons/event_tools` (ver [Editores](../editors/index.md)).

## Alcance previsto

1. Modelo Event → Page → Commands
2. Orden de evaluación de condiciones y páginas activas
3. Catálogo de comandos más usados
4. Cómo iniciar una batalla desde un evento
5. Sprites / apariencia de páginas de evento
6. Flujo de ejecución en runtime (`EventController`)

## Notas

!!! note "Empezar desde el código"
    Punto de partida: `EventSystem.gd`, `EventController.gd` y un comando concreto en `Commands/`.
