# Sistema de Trainers (PBI-311)

## Descripción

Sistema de entrenadores NPCs que detectan al jugador en línea recta y activan batallas Pokémon. Los Trainers heredan de NPC y añaden lógica de detección, secuencia de batalla y persistencia de estado.

## Arquitectura

```
Trainer.gd (extends NPC)
├── Detección en línea recta (detection_range)
├── Transición de batalla configurable (transition_type)
├── Persistencia de derrota (defeated_flag)
└── Battler (nodo hijo)
    └── TrainerData (.tres resource)
```

## Componentes

### 1. **Trainer** (NPC extendido)
- **Archivo**: `Scripts/Overworld/Actors/Trainer.gd`
- **Escena**: `Scenes/Overworld/Actors/Trainer.tscn`
- **Hereda de**: `NPC` (que hereda de `Event`)

### 2. **Battler** (nodo hijo)
- **Archivo**: `Scripts/Battler.gd`
- **Propósito**: Gestiona equipo Pokémon, IA, sprites y conversión a `BattleParticipant`

### 3. **TrainerData** (Resource)
- **Archivo**: `Scripts/Resources/Classes/TrainerData.gd`
- **Guardado**: `Resources/Trainers/*.tres`
- **Contiene**: Equipo, textos, IA, sprites, clase de entrenador

### 4. **BattleTransitionEnum**
- **Archivo**: `Scripts/Enums/BattleTransitionEnum.gd`
- **Propósito**: Define tipos de transiciones visuales para combates

## Uso Básico

### Paso 1: Crear un TrainerData Resource

1. Crear un nuevo recurso `.tres` en `Resources/Trainers/`
2. Configurar:
   - `trainer_id`: ID único del entrenador
   - `trainer_class_id`: Clase (Cazabichos, Nadadora, etc.)
   - `display_name`: Nombre del entrenador
   - `party_data`: Array de Pokémon (configurar desde inspector)
   - `intro_text`: Mensaje antes de la batalla
   - `defeat_text`: Mensaje al perder

**Ejemplo**: `Resources/Trainers/route_1_youngster_01.tres`

```gdscript
# Configuración desde el inspector
trainer_id = 1001
trainer_class_id = TrainerClassEnum.Values.BUG_CATCHER
display_name = "Jano"
intro_text = "¡Me encantan los bichos!"
defeat_text = "¡Mis bichos perdieron!"
party_data = [
    # Pokemon 1: Weedle Lv.4
    # Pokemon 2: Caterpie Lv.5
]
```

### Paso 2: Añadir un Trainer al Mapa

1. Instanciar `Scenes/Overworld/Actors/Trainer.tscn` en tu mapa
2. Colocar dentro del contenedor `Events` del mapa
3. Configurar propiedades del Trainer:

```gdscript
# Propiedades en el inspector
detection_range = 5              # Rango de visión en tiles
transition_type = 0              # Battle1 (ver BattleTransitionEnum)
defeated_flag = "route_1_trainer_jano_defeated"
allow_rematch = false
exclamation_duration = 0.5
approach_speed = 2.0
```

4. Configurar el **Battler hijo**:
   - `trainer_data`: Asignar el TrainerData creado en Paso 1

### Paso 3: Configurar Comportamiento NPC (heredado)

El Trainer hereda todas las propiedades de NPC:

```gdscript
# Propiedades de NPC
movement_type = 0                # None, Random, Path, RandomTurning, LookPattern
orientation_behavior = 0         # Face Player, Fixed, Face and Restore
initial_direction = 1            # Down
movement_speed = 2               # Normal
```

**Recomendación para Trainers**:
- `movement_type = 0` (None) o `3` (RandomTurning) - Los trainers normalmente no se mueven
- `orientation_behavior = 0` (Face Player) - Mirar al jugador al interactuar

## Secuencia de Batalla

Cuando el jugador entra en el campo de visión del Trainer:

1. **Detección**: Verificar si el jugador está en línea recta dentro del `detection_range`
2. **Exclamación**: Mostrar sprite de exclamación sobre el Trainer (`exclamation_duration`)
3. **Aproximación**: El Trainer se mueve hacia el jugador (`approach_speed`)
4. **Diálogo**: Mostrar el mensaje `intro_text` del TrainerData
5. **Batalla**: Emitir `SignalManager.battle_requested` con:
   - Participantes: Jugador y Trainer (convertidos a `BattleParticipant`)
   - Reglas: Tipo TRAINER, modo SINGLE o DOUBLE
6. **Post-batalla**: 
   - Si el Trainer pierde: marcar `is_defeated = true` y guardar flag
   - Reanudar controles del jugador

## Persistencia de Estado

### Marcar como Derrotado

El sistema usa `GameStateManager` para persistir el estado:

```gdscript
# Configurar defeated_flag en el Trainer
defeated_flag = "route_1_youngster_01_defeated"
```

- Al perder la batalla, se guarda: `GameStateManager.set_flag(defeated_flag, true)`
- Al cargar el mapa, se verifica: `GameStateManager.get_flag(defeated_flag, false)`
- Si está derrotado y `allow_rematch = false`, no volverá a detectar al jugador

### Rematches

Para permitir rematches (eventos especiales, gimnasios, etc.):

```gdscript
allow_rematch = true
```

El Trainer podrá volver a iniciar batallas incluso después de ser derrotado.

## Detección en Línea Recta

El Trainer solo detecta al jugador en la dirección que está mirando:

```
Trainer mirando hacia ABAJO (detection_range = 5):

T = Trainer
. = No detecta
X = Detecta

. . . . .
. . T . .
. . X . .
. . X . .
. . X . .
. . X . .
. . X . .
```

**Lógica**:
1. Obtener dirección actual del Trainer (`motion.dir`)
2. Iterar desde 1 hasta `detection_range` tiles en esa dirección
3. Si encuentra al jugador, activar secuencia de batalla

## Tipos de Transición

Configurar `transition_type` en el inspector:

| Valor | Nombre | Máscara |
|-------|--------|---------|
| 0 | Battle1 | `battle1.png` |
| 1 | Battle2 | `battle2.png` |
| 2 | Battle3 | `battle3.png` |
| 3 | Battle4 | `battle4.png` |
| 4 | Normal01 | `021-Normal01.png` |
| 5 | Normal02 | `022-Normal02.png` |
| 6 | Hexatr | `hexatr.png` |
| 7 | Hexatrc | `hexatrc.png` |
| 8 | Hexatzr | `hexatzr.png` |
| 9 | WipeVertical | `wipe-vertical-reflected.png` |

Las máscaras están en `res://Sprites/Transiciones/`

## Integración con Player

El jugador debe tener un nodo **Battler** configurado:

```gdscript
# En Player.tscn
Player (Node2D)
└── Battler (Battler)
    ├── is_player = true
    ├── party = [Array de Pokemon]
    └── (opcional) partner_path para batallas dobles
```

El sistema actual ya tiene esto configurado en `Scenes/Overworld/Actors/Player.tscn`.

## Ejemplo Completo: Ruta 1 - Youngster

### 1. Crear TrainerData

**Archivo**: `Resources/Trainers/route_1_youngster_joey.tres`

```
trainer_id = 1001
trainer_class_id = TrainerClassEnum.Values.YOUNGSTER
display_name = "Joey"
intro_text = "¡Mis shorts son cómodos y fáciles de llevar!"
defeat_text = "¡Mis Pokémon perdieron!"
party_data = [
    Pokemon (Rattata, Lv.3),
    Pokemon (Rattata, Lv.3)
]
battle_front_sprite = null  # Usa sprite de la clase
reward_money = 48  # Calculado automáticamente
```

### 2. Añadir al Mapa

En `Scenes/Overworld/Maps/Route1.tscn`:

```gdscript
Trainer (instance de Trainer.tscn)
├── position = Vector2(320, 480)  # Posición en el mapa
├── detection_range = 4
├── transition_type = 0  # Battle1
├── defeated_flag = "route_1_youngster_joey_defeated"
├── movement_type = 3  # RandomTurning
├── initial_direction = 2  # Right
└── Battler
    └── trainer_data = preload("res://Resources/Trainers/route_1_youngster_joey.tres")
```

### 3. Resultado

- El Youngster Joey mira aleatoriamente en diferentes direcciones
- Si el jugador entra en su línea de visión (4 tiles), Joey:
  1. Muestra una exclamación
  2. Corre hacia el jugador
  3. Dice: "¡Mis shorts son cómodos y fáciles de llevar!"
  4. Inicia batalla con 2 Rattata
- Al perder, queda marcado como derrotado
- Si el jugador interactúa después, muestra mensaje de derrota

## Partner y Batallas Dobles

Para configurar batallas dobles con un partner:

```gdscript
# En el Battler del Trainer
allow_double_battle = true
partner_path = NodePath("../OtherTrainer/Battler")  # Ruta al Battler del partner
```

El sistema automáticamente configurará una batalla doble si:
- `allow_double_battle = true`
- El partner existe y está configurado

## API del Trainer

### Métodos Públicos

```gdscript
# Verificar si está derrotado
func is_defeated() -> bool

# Resetear estado (testing/rematches)
func reset_trainer() -> void
```

### Señales

El Trainer se conecta automáticamente a:

```gdscript
# Señales del sistema
SignalManager.battle_finished  # Para marcar derrota
player_motion.step_finished    # Para detección continua
```

## Debugging

Para debug, el Trainer imprime información útil:

```gdscript
# Al conectar al jugador
"Trainer 'TrainerName': Conectado a movimiento del jugador"

# Al detectar jugador
"Trainer 'TrainerName': ¡Jugador detectado en tile (x, y)!"

# Al iniciar batalla
"Trainer 'TrainerClass TrainerName': Iniciando batalla con PlayerName"

# Al terminar batalla
"Trainer 'TrainerName': Batalla terminada. Ganador: PLAYER"
"Trainer 'TrainerName': Marcado como derrotado (flag: defeated_flag_name)"
```

## Criterios de Aceptación (PBI-311)

✅ Los entrenadores se configuran desde el editor asignando un TrainerData  
✅ Detectan al jugador en línea recta dentro del rango definido  
✅ Muestran animación de exclamación y se mueven hasta el jugador  
✅ Muestran el mensaje previo al combate definido en el TrainerData  
✅ Inician el combate usando SignalManager.battle_requested  
✅ Tras ser derrotados, quedan marcados como vencidos y no vuelven a iniciar combates  
✅ Se puede definir el tipo de transición visual usada para entrar en combate (por defecto, battle1)

## Limitaciones Conocidas

1. **Diálogo integrado**: Actualmente los mensajes se imprimen por consola. Pendiente integración con MessageBox.
2. **Sprite de exclamación**: Por defecto es `null`. Puedes asignar un sprite personalizado.
3. **Transiciones**: El `transition_type` aún no está completamente integrado con el sistema de transiciones de batalla.

## Futuras Mejoras

- [ ] Integración con MessageBox para diálogos
- [ ] Animaciones de exclamación por defecto
- [ ] Soporte para rutas de patrullaje
- [ ] Trainers que buscan activamente al jugador
- [ ] Música de batalla específica por clase de entrenador
- [ ] Eye contact callback (cuando el trainer ve al jugador, antes de moverse)

## Ver También

- `BATTLER_SYSTEM_README.md` - Sistema de Battler y BattleParticipant
- `Resources/Trainers/README.md` - Configuración de TrainerData
- `Scripts/Overworld/Actors/NPC_README.md` - Sistema de NPCs

