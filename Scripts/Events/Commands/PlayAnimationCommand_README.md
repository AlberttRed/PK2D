# PlayAnimationCommand

## Descripción

EventCommand para reproducir animaciones en el ActorAnimator de un evento. Permite animar eventos contextuales como puertas que se abren, cofres, interruptores, NPCs realizando acciones específicas, etc.

## Ubicación

- **Archivo**: `Scripts/Events/Commands/PlayAnimationCommand.gd`
- **Clase**: `PlayAnimationCommand` (extends `EventCommand`)

## Características

✅ Reproduce animaciones personalizadas en eventos con ActorAnimator  
✅ Espera opcional a que termine la animación antes de continuar  
✅ Validación automática de existencia de ActorAnimator y animaciones  
✅ Warnings informativos cuando faltan componentes  
✅ Compatible con cualquier evento que tenga ActorAnimator  

## Uso Básico

### 1. Preparar el Evento

Para que un evento pueda usar `PlayAnimationCommand`, debe tener un **ActorAnimator** como nodo hijo:

```
Event
 ├── AnimatedSprite2D (heredado, puede ocultarse)
 ├── Occupancy
 └── ActorAnimator
      └── AnimatedSprite2D
```

**Nota**: Los NPCs ya incluyen ActorAnimator por defecto. Para eventos estáticos (puertas, cofres, etc.), debes añadirlo manualmente.

### 2. Configurar Animaciones

El `ActorAnimator` debe tener un `SpriteFrames` con las animaciones que quieres reproducir:

```gdscript
# En el SpriteFrames del ActorAnimator, define animaciones como:
- "door_open"   (puerta abriéndose)
- "door_close"  (puerta cerrándose)
- "chest_open"  (cofre abriéndose)
- "switch_on"   (interruptor activado)
- "switch_off"  (interruptor desactivado)
```

### 3. Añadir el Comando

1. Abre el evento en el editor
2. Selecciona o crea una EventPage
3. En la lista `commands`, añade un nuevo elemento
4. Asigna `PlayAnimationCommand.tres` (o crea un nuevo Resource)
5. Configura las propiedades en el inspector

## Propiedades Configurables

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `animation_name` | String | Nombre de la animación a reproducir (debe existir en el SpriteFrames) |
| `wait_until_finished` | bool | Si true, espera a que termine la animación antes de continuar el evento |

## Ejemplos Completos

### Ejemplo 1: Puerta que se Abre

```gdscript
# Evento "Puerta Principal" con ActorAnimator
EventPage:
  trigger_type = ACTION
  commands = [
    ShowMessageCommand {
      message = "La puerta se abre..."
    },
    PlayAnimationCommand {
      animation_name = "door_open",
      wait_until_finished = true
    },
    WarpCommand {
      map_id = "interior_house",
      spawn_id = "entrance"
    }
  ]
```

### Ejemplo 2: Cofre que se Abre (sin esperar)

```gdscript
# Evento "Cofre" con ActorAnimator
EventPage:
  trigger_type = ACTION
  commands = [
    PlayAnimationCommand {
      animation_name = "chest_open",
      wait_until_finished = false  # Continuar inmediatamente
    },
    ShowMessageCommand {
      message = "¡Encontraste una Poción!"
    },
    # Comando para añadir item al inventario (futuro)
  ]
```

### Ejemplo 3: Interruptor con Dos Animaciones

```gdscript
# Evento "Interruptor" con dos páginas
# Página 0: Estado OFF
EventPage 0:
  trigger_type = ACTION
  required_flag = "switch_activated"
  required_flag_value = false
  commands = [
    PlayAnimationCommand {
      animation_name = "switch_on",
      wait_until_finished = true
    },
    SetFlagCommand {
      flag_name = "switch_activated",
      value = true
    },
    ShowMessageCommand {
      message = "¡El interruptor está activado!"
    }
  ]

# Página 1: Estado ON
EventPage 1:
  trigger_type = ACTION
  required_flag = "switch_activated"
  required_flag_value = true
  commands = [
    PlayAnimationCommand {
      animation_name = "switch_off",
      wait_until_finished = true
    },
    SetFlagCommand {
      flag_name = "switch_activated",
      value = false
    },
    ShowMessageCommand {
      message = "El interruptor está desactivado."
    }
  ]
```

### Ejemplo 4: NPC Haciendo una Acción

```gdscript
# NPC con animación personalizada
EventPage:
  trigger_type = ACTION
  commands = [
    ShowMessageCommand {
      message = "¡Mira esto!"
    },
    PlayAnimationCommand {
      animation_name = "wave",  # NPC saludando
      wait_until_finished = true
    },
    ShowMessageCommand {
      message = "¡Adiós!"
    }
  ]
```

### Ejemplo 5: Puerta Automática (Autorun)

```gdscript
# Evento "Puerta Automática" que se abre al acercarse
EventPage:
  trigger_type = AUTORUN
  required_flag = "player_near_door"
  required_flag_value = true
  commands = [
    PlayAnimationCommand {
      animation_name = "door_open",
      wait_until_finished = true
    },
    WaitCommand {
      duration = 1.0
    },
    SetFlagCommand {
      flag_name = "player_near_door",
      value = false
    }
  ]
```

## Flujo de Ejecución

```
1. execute(context) llamado por EventController
   ↓
2. Validar que animation_name no esté vacío
   ↓
3. Buscar ActorAnimator en el evento actual (source_event)
   ↓
4. Verificar que el ActorAnimator tiene sprite y SpriteFrames válidos
   ↓
5. Verificar que la animación existe en el SpriteFrames
   ↓
6. Reproducir la animación mediante ActorAnimator.play()
   ↓
7. Si wait_until_finished = true:
   - Conectar a la señal animation_finished del AnimatedSprite2D
   - Esperar a que termine la animación
   - Desconectar la señal
   - Continuar ejecución
   Si wait_until_finished = false:
   - Continuar inmediatamente
```

## Validaciones

El comando realiza las siguientes validaciones automáticas:

✅ **animation_name**: Verifica que no esté vacío  
✅ **ActorAnimator**: Busca el componente en el evento, lanza warning si no existe  
✅ **Sprite válido**: Verifica que el ActorAnimator tenga sprite y SpriteFrames configurados  
✅ **Animación existe**: Verifica que la animación especificada exista en el SpriteFrames  

Si alguna validación falla, el comando:
- Imprime un warning en consola
- Salta la animación
- Continúa con el siguiente comando (no bloquea el evento)

## Integración con el Sistema de Eventos

### Source Event

El comando utiliza el campo `source_event` de la `EventPage` actual para encontrar el evento correcto:

```gdscript
EventController → current_page → source_event → ActorAnimator
```

Esto permite que el comando siempre anime el evento correcto, incluso cuando hay múltiples eventos ejecutándose en paralelo.

### Señales del AnimatedSprite2D

El comando se conecta a la señal `animation_finished` del `AnimatedSprite2D` cuando `wait_until_finished = true`:

```gdscript
_actor_animator.sprite.animation_finished.connect(_on_animation_finished)
```

La señal se desconecta automáticamente después de completar la animación para evitar fugas de memoria.

## Compatibilidad

### ✅ Compatible con:
- **Events estáticos** (con ActorAnimator añadido manualmente)
- **NPCs** (incluyen ActorAnimator por defecto)
- **Trainers** (heredan de NPC, tienen ActorAnimator)
- **Eventos animados personalizados**

### ❌ No compatible con:
- Events sin ActorAnimator (lanza warning y continúa)
- Events que usan solo AnimatedSprite2D heredado (requiere ActorAnimator)

## Troubleshooting

### ❌ "El evento no tiene un ActorAnimator"
**Causa**: El evento no tiene un nodo ActorAnimator hijo  
**Solución**: Añadir un ActorAnimator al evento desde la escena `res://Scenes/Overworld/Core/ActorAnimator.tscn`

### ❌ "La animación 'xxx' no existe en el SpriteFrames"
**Causa**: El nombre de la animación no coincide con las definidas en el SpriteFrames  
**Solución**: Verificar el nombre exacto de la animación en el SpriteFrames del ActorAnimator

### ❌ "El ActorAnimator no tiene un sprite o SpriteFrames configurado"
**Causa**: El ActorAnimator no tiene el AnimatedSprite2D configurado o el SpriteFrames está vacío  
**Solución**: Asignar un SpriteFrames válido al AnimatedSprite2D del ActorAnimator

### ❌ La animación no se reproduce visualmente
**Causa 1**: El sprite del evento está oculto  
**Solución**: Verificar que `sprite.visible = true` en el ActorAnimator

**Causa 2**: La animación tiene loop = false y ya se reprodujo antes  
**Solución**: Configurar `loop = true` en la animación o resetear el frame antes de reproducir

## Casos de Uso

### ✅ Recomendado para:
- Puertas (abrir/cerrar)
- Cofres (abrir)
- Interruptores/botones (on/off)
- Objetos interactivos (movimientos, rotaciones)
- NPCs realizando acciones contextuales (saludar, señalar, etc.)
- Efectos visuales de eventos (brillos, partículas simuladas con frames)

### ❌ No recomendado para:
- Animaciones de movimiento de NPCs (usar GridMotion y ActorAnimator automático)
- Animaciones del jugador (usa el ActorAnimator del Player directamente)
- Efectos de partículas complejos (usar GPUParticles2D o CPUParticles2D)

## Diferencias con ActorAnimator.play()

| Característica | ActorAnimator.play() | PlayAnimationCommand |
|----------------|----------------------|---------------------|
| **Uso** | Código GDScript | Inspector/Eventos |
| **Espera** | Manual (await) | Automático con wait_until_finished |
| **Contexto** | Requiere referencia directa | Busca automáticamente el evento |
| **Validación** | Manual | Automática con warnings |
| **Limpieza** | Manual | Automática (desconecta señales) |

## Métodos y wait_until_finished

### Si wait_until_finished = true (por defecto)

El comando es **asíncrono** y espera a que termine la animación:

```gdscript
func is_async() -> bool:
    return wait_until_finished  # true
```

La ejecución del evento se pausa hasta que:
1. La animación termina completamente
2. Se emite la señal `animation_finished`
3. Se desconecta la señal automáticamente
4. Se llama a `context.continue_execution()`

### Si wait_until_finished = false

El comando es **síncrono** y continúa inmediatamente:

```gdscript
# La animación se inicia pero el evento continúa sin esperar
```

Útil cuando quieres que la animación se reproduzca en el fondo mientras continúan otros comandos.

## Criterios de Aceptación (PBI-351)

✅ Existe un comando PlayAnimationCommand con parámetros animation_name y wait_until_finished  
✅ El comando busca un ActorAnimator en el evento que lo ejecuta y reproduce la animación indicada  
✅ Si wait_until_finished está activado, la ejecución del evento espera a que termine la animación  
✅ Si el evento no tiene ActorAnimator, el comando lanza un warning y se salta  
✅ PlayAnimationCommand puede usarse en cualquier evento con animaciones configuradas  

## Ver También

- [ActorAnimator.gd](../../Overworld/Core/ActorAnimator.gd) - Componente de animación
- [EventCommand.gd](../EventCommand.gd) - Clase base de comandos
- [Event.gd](../Event.gd) - Sistema de eventos
- [IMPLEMENTACION_PBI_284_350.md](../../../IMPLEMENTACION_PBI_284_350.md) - Documentación de ActorAnimator


