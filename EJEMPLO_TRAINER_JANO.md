# Ejemplo de Trainer: Cazabichos Jano

## Descripción

Este documento muestra cómo usar el sistema de Trainers con el ejemplo existente "CAZABICHOS JANO".

## TrainerData Existente

Ya existe un TrainerData configurado en:

**Archivo**: `Resources/Trainers/CAZABICHOS JANO.tres`

**Configuración**:
- **Trainer ID**: 1
- **Clase**: Cazabichos (Bug Catcher)
- **Nombre**: Jano
- **Equipo**:
  - Weedle (Lv.6) - Movimientos: String Shot, Poison Sting
  - Caterpie (Lv.6) - Movimientos: Tackle, String Shot
- **Intro**: "¡Eh! ¡Tienes POKÉMON! ¡Sí! ¡Al ataque!"
- **Derrota**: "¡No! ¡Mi CATERPIE no pudo más!"
- **Recompensa**: 72₽
- **IA**: Easy (básica)

## Cómo Añadir al Mapa

### Opción A: Desde el Editor de Godot (Recomendado)

1. **Abrir un mapa** (ej: `Scenes/Overworld/Maps/Route1.tscn`)

2. **Instanciar Trainer**:
   - En el árbol de escena, buscar el contenedor `Events`
   - Click derecho → `Instantiate Child Scene`
   - Navegar a `Scenes/Overworld/Actors/Trainer.tscn`
   - Click en `Open`

3. **Posicionar el Trainer**:
   - Colocar en una posición estratégica del mapa
   - Ejemplo: cerca de la hierba alta en la Ruta 1

4. **Configurar propiedades del Trainer**:
   ```
   Trainer
   ├─ Detection Range: 5
   ├─ Transition Type: Battle1 (0)
   ├─ Defeated Flag: "route_1_jano_defeated"
   ├─ Allow Rematch: false
   ├─ Exclamation Duration: 0.5
   ├─ Approach Speed: 2.0
   └─ [NPC Properties]
      ├─ Movement Type: Random Turning (3)
      ├─ Orientation Behavior: Face Player (0)
      ├─ Initial Direction: Down (1)
      └─ Movement Speed: Normal (2)
   ```

5. **Configurar el Battler**:
   - Expandir `Trainer → Battler`
   - En el inspector, buscar `Trainer Data`
   - Click en `[empty]` → `Quick Load`
   - Seleccionar `Resources/Trainers/CAZABICHOS JANO.tres`

6. **Guardar el mapa**

### Opción B: Por Script (Avanzado)

```gdscript
# En un script de configuración del mapa
func _setup_trainers() -> void:
    # Crear instancia de Trainer
    var trainer_scene = preload("res://Scenes/Overworld/Actors/Trainer.tscn")
    var jano = trainer_scene.instantiate()
    
    # Configurar Trainer
    jano.name = "Jano"
    jano.position = Vector2(320, 480)  # Posición en el mapa
    jano.detection_range = 5
    jano.transition_type = 0  # Battle1
    jano.defeated_flag = "route_1_jano_defeated"
    jano.allow_rematch = false
    jano.movement_type = 3  # RandomTurning
    jano.initial_direction = 1  # Down
    
    # Cargar TrainerData en el Battler hijo
    var battler = jano.get_node("Battler")
    battler.trainer_data = preload("res://Resources/Trainers/CAZABICHOS JANO.tres")
    
    # Añadir al mapa
    $Events.add_child(jano)
```

## Comportamiento Esperado

### 1. En el Overworld

**Estado inicial**:
- Jano está parado en su posición
- Gira aleatoriamente mirando en diferentes direcciones (RandomTurning)

**Cuando el jugador se acerca**:
- Si el jugador entra en el campo de visión de Jano (5 tiles en línea recta)
- Jano muestra una exclamación (!)
- Jano corre hacia el jugador a velocidad x2

**Diálogo**:
- Jano se detiene a 1 tile del jugador
- Muestra el mensaje: "¡Eh! ¡Tienes POKÉMON! ¡Sí! ¡Al ataque!"

### 2. En la Batalla

**Inicio**:
- Transición de batalla (máscara battle1)
- Aparece "¡Cazabichos Jano quiere combatir!"
- Jano envía su primer Pokémon: Weedle (Lv.6)

**Durante el combate**:
- Jano usa IA Easy (movimientos aleatorios, no usa objetos)
- Si Weedle es derrotado, envía Caterpie (Lv.6)

**Fin del combate**:
- Si el jugador gana:
  - Jano dice: "¡No! ¡Mi CATERPIE no pudo más!"
  - El jugador recibe 72₽
  - Jano queda marcado como derrotado
  - Se guarda el flag `route_1_jano_defeated = true`

### 3. Post-Batalla

**Si el jugador vuelve a interactuar**:
- Jano NO vuelve a desafiar al jugador (está derrotado)
- Si se habla con él, muestra mensaje de derrota

**Si allow_rematch fuera true**:
- Jano podría volver a desafiar al jugador

## Diagrama de Flujo

```
┌─────────────────────────────────────┐
│  Jugador entra en campo de visión  │
│         (5 tiles adelante)          │
└───────────────┬─────────────────────┘
                │
                ▼
        ┌───────────────┐
        │  ¿Derrotado?  │
        └───┬───────┬───┘
            │       │
          No│       │Sí
            │       │
            ▼       └──► No hacer nada
    ┌────────────┐
    │Exclamación │
    │   (0.5s)   │
    └─────┬──────┘
          │
          ▼
    ┌────────────┐
    │ Moverse    │
    │hacia Player│
    └─────┬──────┘
          │
          ▼
    ┌────────────┐
    │  Diálogo   │
    └─────┬──────┘
          │
          ▼
    ┌────────────┐
    │  Batalla   │
    └─────┬──────┘
          │
          ▼
    ┌────────────┐
    │  ¿Ganó?    │
    └───┬────┬───┘
        │    │
     Sí│    │No
        │    │
        ▼    ▼
    ┌────┐ ┌────┐
    │72₽ │ │Game│
    │    │ │Over│
    └─┬──┘ └────┘
      │
      ▼
┌───────────────┐
│Marcar derrotado│
│ (flag = true) │
└───────────────┘
```

## Pruebas

### Test 1: Detección Frontal

```
Escenario: Jano mira hacia abajo
Acción: El jugador camina hacia él desde abajo
Resultado esperado:
  ✓ Jano detecta al jugador a 5 tiles de distancia
  ✓ Muestra exclamación
  ✓ Se mueve hacia el jugador
  ✓ Inicia batalla
```

### Test 2: Detección Lateral (No detecta)

```
Escenario: Jano mira hacia abajo
Acción: El jugador pasa a su lado (izquierda o derecha)
Resultado esperado:
  ✓ Jano NO detecta al jugador (solo detecta en línea recta)
  ✓ Continúa girando aleatoriamente
```

### Test 3: Post-Derrota

```
Escenario: Jano ya fue derrotado (flag = true)
Acción: El jugador pasa frente a él
Resultado esperado:
  ✓ Jano NO inicia batalla
  ✓ Si se interactúa, muestra mensaje de derrota
```

### Test 4: Persistencia

```
Escenario: Derrotar a Jano y salir del mapa
Acción: Volver a entrar al mapa
Resultado esperado:
  ✓ Jano sigue marcado como derrotado
  ✓ NO vuelve a desafiar al jugador
```

## Debugging

Si hay problemas, verificar en la consola:

```
# Al iniciar el mapa
Trainer 'Jano': Battler encontrado (Cazabichos Jano)
Trainer 'Jano': Conectado a movimiento del jugador

# Al detectar al jugador
Trainer 'Jano': ¡Jugador detectado en tile (10, 15)!

# Al iniciar batalla
Trainer 'Cazabichos Jano': Iniciando batalla con Red

# Al terminar batalla
Trainer 'Jano': Batalla terminada. Ganador: PLAYER
Trainer 'Jano': Marcado como derrotado (flag: route_1_jano_defeated)
```

## Variaciones del Ejemplo

### Variación 1: Jano con Path Movement

Cambiar `movement_type` a `Path` (2) y configurar una ruta de patrullaje:

```
path_directions = [
    DirectionEnum.Type.DOWN,
    DirectionEnum.Type.DOWN,
    DirectionEnum.Type.RIGHT,
    DirectionEnum.Type.RIGHT,
    DirectionEnum.Type.UP,
    DirectionEnum.Type.UP,
    DirectionEnum.Type.LEFT,
    DirectionEnum.Type.LEFT
]
```

Jano patrullará en un cuadrado y detectará al jugador mientras camina.

### Variación 2: Jano con Rematch

Cambiar `allow_rematch` a `true` para permitir rematches:

```
allow_rematch = true
```

Útil para entrenadores especiales que quieren revancha.

### Variación 3: Jano Estático

Cambiar `movement_type` a `None` (0):

```
movement_type = 0  # None
initial_direction = 2  # Right (mirando a la derecha)
```

Jano quedará mirando fijamente hacia la derecha, perfecto para "guardianes" de áreas.

## Conclusión

Este ejemplo muestra cómo el sistema de Trainers:
- ✅ Reutiliza TrainerData existentes
- ✅ Configura comportamiento desde el inspector
- ✅ Detecta jugadores inteligentemente
- ✅ Gestiona persistencia automáticamente
- ✅ Integra con el sistema de batallas

Para crear nuevos trainers, simplemente:
1. Crear un nuevo TrainerData (.tres)
2. Instanciar Trainer.tscn
3. Asignar el TrainerData al Battler
4. ¡Listo!

