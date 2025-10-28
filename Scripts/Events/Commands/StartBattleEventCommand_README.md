# StartBattleEventCommand

## Descripción

EventCommand para iniciar combates Pokémon desde cualquier evento o secuencia. Permite configurar combates salvajes, contra entrenadores, o personalizados, con integración completa al sistema de TrainerData.

## Ubicación

- **Archivo**: `Scripts/Events/Commands/StartBattleEventCommand.gd`
- **Clase**: `StartBattleEventCommand` (extends `EventCommand`)

## Características

✅ Combates salvajes con PokemonData configurables  
✅ Combates contra entrenadores usando TrainerData  
✅ Mensaje de introducción opcional  
✅ Tracking de estado (entrenadores derrotados)  
✅ Pausa del evento durante el combate  
✅ Compatible con combates Single, Double y Triple  
✅ Integración con SignalManager.battle_requested  

## Uso Básico

### 1. Añadir a un Evento

1. Abre una escena de Event en el editor
2. Selecciona o crea una EventPage
3. En la lista `commands`, añade un nuevo elemento
4. Asigna `StartBattleEventCommand.tres` (o crea un nuevo Resource)
5. Configura las propiedades en el inspector

### 2. Configurar Combate contra Entrenador

```gdscript
# Configuración en el inspector
Battle Configuration:
  battle_type = TRAINER
  trainer_data = preload("res://Resources/Trainers/route_1_youngster_joey.tres")
  battle_mode = SINGLE

State Tracking:
  defeated_flag = "route_1_youngster_joey_defeated"
```

**Flujo:**
1. Muestra automáticamente el `intro_text` del TrainerData
2. Inicia combate usando el equipo del entrenador
3. Al ganar el jugador, guarda `defeated_flag` en GameStateManager
4. Muestra el `defeat_text` del TrainerData
5. Continúa el evento

### 3. Configurar Combate Salvaje

```gdscript
# Configuración en el inspector
Battle Configuration:
  battle_type = WILD
  wild_pokemon = [preload("res://Resources/Pokemon/rattata_lv5.tres")]  # Pokemon runtime con nivel 5
  battle_mode = SINGLE
```

**Nota**: 
- `wild_pokemon` usa `Pokemon` (runtime), no `PokemonData`. Cada Pokemon ya tiene su nivel, IVs, movimientos, etc. configurados desde el inspector.
- Para combates WILD no se muestra mensaje intro automáticamente (debes añadir un ShowMessageCommand antes si lo necesitas)

**Flujo:**
1. Muestra el mensaje intro (si está configurado)
2. Inicia combate salvaje con el Pokémon especificado
3. Continúa el evento tras el combate

### 4. Combate Salvaje Doble

```gdscript
# Configuración en el inspector
Battle Configuration:
  battle_type = WILD
  wild_pokemon = [
    preload("res://Resources/Pokemon/pidgey_lv7.tres"),   # Pokemon runtime nivel 7
    preload("res://Resources/Pokemon/pidgey_lv8.tres")    # Pokemon runtime nivel 8
  ]
  battle_mode = DOUBLE

Messages:
  intro_message = "¡Dos Pidgey salvajes aparecieron!"
```

**Nota**: Cada Pokemon se configura como un Resource `.tres` separado con su nivel, movimientos y stats.

## Propiedades Configurables

### Battle Configuration

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `battle_type` | BattleType | Tipo de combate: WILD, TRAINER, CUSTOM |
| `trainer_data` | TrainerData | TrainerData del enemigo (solo TRAINER) |
| `wild_pokemon` | Array[Pokemon] | Pokémon salvajes runtime con nivel incluido (solo WILD) |
| `battle_mode` | int (enum) | Modo: SINGLE (0), DOUBLE (1), TRIPLE (2) |

**Nota sobre mensajes**: Para combates TRAINER, el mensaje intro se toma automáticamente del `intro_text` del TrainerData.

### Visual

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `transition_type` | int (enum) | Tipo de transición (futuro uso) |

### State Tracking

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `defeated_flag` | String | Flag personalizado (opcional, usa el del Trainer si está vacío) |

## Ejemplos Completos

### Ejemplo 1: Rival al inicio del juego

```gdscript
# En el evento del rival al inicio de la aventura
EventPage:
  commands = [
    ShowMessageCommand {
      message = "¡Espera! ¡Tengo que probar mi nuevo Pokémon!"
    },
    StartBattleEventCommand {
      battle_type = TRAINER,
      trainer_data = preload("res://Resources/Trainers/rival_inicio.tres"),
      battle_mode = SINGLE,
      defeated_flag = "rival_inicio_defeated"
    },
    ShowMessageCommand {
      message = "¡Eres fuerte! Nos veremos después."
    }
  ]
```

### Ejemplo 2: Encuentro aleatorio salvaje

```gdscript
# En un evento autorun con probabilidad
EventPage:
  trigger_type = AUTORUN
  commands = [
    # (Aquí habría lógica de probabilidad con flags)
    ShowMessageCommand { message = "¡Un Pokémon salvaje apareció!" },
    StartBattleEventCommand {
      battle_type = WILD,
      wild_pokemon = [preload("res://Resources/Pokemon/caterpie_lv4.tres")],  # Pokemon runtime Lv4
      battle_mode = SINGLE
    }
  ]
```

### Ejemplo 3: Entrenador en ruta (con Event separado del Trainer NPC)

```gdscript
# En un Event con trigger ACTION (interacción)
EventPage:
  trigger_type = ACTION
  commands = [
    StartBattleEventCommand {
      battle_type = TRAINER,
      trainer_data = preload("res://Resources/Trainers/CAZABICHOS JANO.tres"),
      battle_mode = SINGLE,
      defeated_flag = "route_1_jano_defeated"
    },
    ShowMessageCommand {
      message = "Qué fuerte eres... mis bichos necesitan entrenar más."
    }
  ]
```

### Ejemplo 3b: Combate desde el Trainer NPC (detección automática)

```gdscript
# Si el combate se lanza desde el mismo Trainer que tiene detección automática
Trainer "Jano":
  defeated_flag = "route_1_jano_defeated"  # ← Configurado en el Trainer
  pages[0]:
    trigger_type = ACTION
    commands = [
      StartBattleEventCommand {
        battle_type = TRAINER,
        trainer_data = preload("res://Resources/Trainers/CAZABICHOS JANO.tres"),
        battle_mode = SINGLE
        # defeated_flag vacío = usa automáticamente el del Trainer ✅
      }
    ]
```

**Nota**: Si el comando se ejecuta desde un **Trainer NPC**, el sistema:
- ✅ Detecta automáticamente que el Event es un Trainer
- ✅ Usa el `defeated_flag` del Trainer si el del comando está vacío
- ✅ Marca `battler.is_defeated = true` en el Trainer
- ✅ Desconecta las señales de detección automáticamente

### Ejemplo 4: Combate doble con pareja

```gdscript
# Batalla doble (futuro: podría soportar partners del jugador)
EventPage:
  commands = [
    StartBattleEventCommand {
      battle_type = TRAINER,
      trainer_data = preload("res://Resources/Trainers/double_trainer.tres"),
      battle_mode = DOUBLE,
      defeated_flag = "route_5_double_trainer_defeated"
    }
  ]
```

## Integración con TrainerData

El comando se integra completamente con el sistema de TrainerData:

```gdscript
# TrainerData Resource (Resources/Trainers/example.tres)
trainer_id = 1001
trainer_class_id = TrainerClassEnum.Values.BUG_CATCHER
display_name = "Jano"
intro_text = "¡Me encantan los bichos!"
defeat_text = "¡Mis bichos perdieron!"
party_data = [
  Pokemon(Weedle, Lv.4),
  Pokemon(Caterpie, Lv.5)
]
battle_front_sprite = null  # Usa sprite de la clase
ai_profile = null  # IA por defecto
double_battle = false
reward_money = 48
```

El comando:
1. Inicializa el TrainerData
2. Carga el equipo y propiedades
3. Muestra el intro_text (si `use_trainer_intro = true`)
4. Crea el BattleParticipant con toda la información
5. Inicia el combate
6. Guarda el `defeated_flag` si el jugador gana

## Flujo de Ejecución

```
1. execute(context) llamado por EventController
   ↓
2. _validate_configuration() - Verificar configuración
   ↓
3. _get_player_battler() - Obtener Battler del jugador
   ↓
4. _show_intro_message() - Mostrar mensaje (opcional)
   ↓
5. _create_trainer_participant() o _create_wild_participant()
   ↓
6. Crear BattleRules con tipo y modo
   ↓
7. SignalManager.battle_requested.emit(participants, rules)
   ↓
8. Esperar SignalManager.battle_finished
   ↓
9. Guardar defeated_flag (si aplica)
   ↓
10. context.continue_execution() - Continuar evento
```

## Validaciones

El comando realiza las siguientes validaciones automáticas:

✅ **TRAINER**: Verifica que `trainer_data` esté asignado y tenga equipo válido  
✅ **WILD**: Verifica que `wild_pokemon` no esté vacío  
✅ **Niveles**: Crea niveles por defecto (5) si `wild_pokemon_levels` está vacío  
✅ **Player**: Verifica que el jugador tenga un Battler configurado  

Si alguna validación falla, el comando:
- Imprime un error en consola
- Salta el combate
- Continúa con el siguiente comando

## Diferencias con Trainer.gd

| Característica | Trainer.gd (NPC) | StartBattleEventCommand |
|----------------|------------------|------------------------|
| **Detección** | Automática (línea de visión) | Manual (desde evento) |
| **Exclamación** | Sí, con animación | No |
| **Aproximación** | Sí, camina hacia el jugador | No |
| **Mensaje intro** | Siempre muestra | Opcional/configurable |
| **Uso** | NPCs en el overworld | Eventos forzados/scripted |
| **Flexibilidad** | Fijo al NPC | Reutilizable en cualquier evento |

## Casos de Uso

### ✅ Recomendado para:
- Batallas forzadas por historia (rival, jefes, etc.)
- Encuentros especiales scripted
- Batallas tutorial
- Eventos únicos (legendarios, etc.)
- Batallas programadas (gimnasios, liga, etc.)

### ❌ No recomendado para:
- NPCs entrenadores en rutas (usar Trainer.gd)
- Encuentros salvajes aleatorios en hierba (usar sistema de encuentros)

## Troubleshooting

### ❌ "No se encontró el Battler del jugador"
**Causa**: El Player no tiene un nodo Battler hijo  
**Solución**: Añadir un Battler al Player con `is_player = true`

### ❌ "TrainerData no tiene un equipo válido"
**Causa**: El `party_data` del TrainerData está vacío  
**Solución**: Configurar Pokémon en el `party_data` del TrainerData

### ❌ "Hay un Pokemon null en wild_pokemon"
**Causa**: Algún elemento del array `wild_pokemon` es null  
**Solución**: Asegurar que todos los Pokemon estén asignados correctamente en el array

### ❌ El mensaje intro no se muestra
**Causa**: El TrainerData no tiene `intro_text` configurado  
**Solución**: Configurar `intro_text` en el TrainerData Resource

### ❌ El Trainer NPC sigue detectando después de vencerlo
**Causa**: El Trainer no tiene `defeated_flag` configurado o el sistema no lo detectó  
**Solución**: 
- Asignar `defeated_flag` en el Trainer NPC
- O asignar `defeated_flag` en el comando
- El sistema detecta automáticamente si el Event es un Trainer

## Criterios de Aceptación (PBI-315)

✅ Puede añadirse a cualquier evento o secuencia  
✅ Permite seleccionar el tipo de combate (salvaje, entrenador, personalizado)  
✅ En modo entrenador, usa un TrainerData como fuente de datos  
✅ Lanza el combate correctamente mediante SignalManager.battle_requested  
✅ Pausa el evento durante el combate y se reanuda al finalizar  
✅ Se puede configurar el tipo de transición visual usada (preparado para futuro)  
✅ Compatible tanto en Overworld como en secuencias forzadas  

## Ver También

- [TRAINER_SYSTEM_README.md](../../../TRAINER_SYSTEM_README.md) - Sistema de Trainers NPC
- [BATTLER_SYSTEM_README.md](../../../BATTLER_SYSTEM_README.md) - Sistema de Battler
- [TrainerData.gd](../../Resources/Classes/TrainerData.gd) - Estructura de TrainerData
- [EventCommand.gd](../EventCommand.gd) - Clase base de comandos

