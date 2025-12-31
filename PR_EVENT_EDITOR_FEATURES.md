 Funcionalidades del Editor de Eventos

## Movimiento de Comandos

### Botones de Reordenamiento
- **↑ (Arriba)** y **↓ (Abajo)**: Mueven comandos dentro de su nivel jerárquico
- Los comandos con hijos se mueven como bloque completo
- Funciona para comandos principales y comandos anidados (nested_commands)

### Modo "Mover"
- Permite mover comandos entre diferentes niveles jerárquicos
- Visualización clara de destinos válidos (verde) e inválidos (gris)
- Soporte para mover entre diferentes páginas del evento
- Destinos válidos:
  - Nodo raíz ("Página") para mover al primer nivel
  - `EventBranch`, `ChoiceBranch`, `SwitchCase` y `default_commands`
  - Comandos principales (cuando aplica)

## Duplicación de Comandos

- **Botón "Duplicar"**: Duplica el comando seleccionado
- El comando duplicado se inserta justo debajo del original
- Funciona para comandos principales y comandos anidados
- Disponible también en el menú contextual (clic derecho)

## Mejoras de UI/UX

- **Menú contextual mejorado**: Añadidas opciones "Duplicar" y "Mover"
- **Deshabilitación de controles**: Durante el modo mover, todos los controles del panel izquierdo (enums, checkboxes, botones) se deshabilitan automáticamente
- **Actualización automática del inspector**: Los cambios se reflejan inmediatamente en el inspector de Godot
- **Sistema de backup/restore**: Si un movimiento falla, el comando se restaura automáticamente a su posición original

## Refactorización del Código

- Funciones auxiliares reutilizables para operaciones comunes
- Reducción significativa de código duplicado (~200 líneas)
- Código más mantenible y legible

#




