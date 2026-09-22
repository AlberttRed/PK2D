# Combate

Documentación del sistema de batalla. Página base: completar según el código en `Scripts/Battle/`.

## Ubicación

```text
Scripts/Battle/
  Battle.gd          # Entrada / orquestación
  core/              # Lógica de combate, efectos, IA
  ui/                # Interfaz de batalla
  animations/        # Animaciones
  visuals/           # Presentación visual
  experience/        # Experiencia / recompensas
  debug/             # Herramientas de depuración
```

Escenas relacionadas: `Scenes/Battle/`.

## Alcance previsto

Cuando se rellene esta sección, conviene cubrir:

1. Ciclo de un turno (entrada → acciones → resolución → salida)
2. Efectos de movimiento y estados temporales
3. Efectos de campo
4. IA de entrenadores / salvajes
5. Contrato de animaciones (señales / llamadas entre lógica y visual)
6. Cómo lanzar una batalla de prueba (`TestBattle.gd` u equivalente)

## Notas

!!! note "Empezar desde el código"
    Preferir leer `Scripts/Battle/Battle.gd` y `Scripts/Battle/core/` antes de copiar guías antiguas de la raíz del repo.
