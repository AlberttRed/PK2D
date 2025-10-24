# 📂 TrainerClasses - Clases de Entrenadores

Esta carpeta contiene los archivos `.tres` que definen las **clases/tipos de entrenadores** del juego.

## 🎯 ¿Qué es un TrainerClassData?

Un `TrainerClassData` define las características generales de un **tipo de entrenador**:
- Nombre localizado ("Líder de Gimnasio", "Alto Mando", etc.)
- Multiplicador de recompensa
- IA por defecto (opcional)
- Sprite por defecto (opcional)

## 🔄 Diferencia entre TrainerClassData y TrainerData

| TrainerClassData | TrainerData |
|------------------|-------------|
| **Define el TIPO** (ej: "Líder de Gimnasio") | **Define un ENTRENADOR** (ej: "Brock") |
| Compartido por múltiples entrenadores | Único para cada entrenador |
| Multiplicador de recompensa | Equipo específico |
| IA genérica | Textos personalizados |
| Ej: `gym_leader.tres` | Ej: `brock.tres` |

## 📝 TrainerClassData por defecto a crear

### Necesarios (mínimo):
- `pokemon_trainer.tres` - Entrenador genérico (multiplicador 1.0)
- `gym_leader.tres` - Líder de gimnasio (multiplicador 5.0)
- `elite_four.tres` - Alto Mando (multiplicador 10.0)
- `champion.tres` - Campeón (multiplicador 15.0)
- `rival.tres` - Rival (multiplicador 3.0)

### Adicionales:
- `youngster.tres`, `lass.tres`, `bug_catcher.tres`
- `cooltrainer.tres`, `ace_trainer.tres`
- `rocket_grunt.tres`, `team_rocket_boss.tres`
- etc.

## 📋 Ejemplo de creación

### Líder de Gimnasio (gym_leader.tres):

```gdscript
id: 100
internal_name: "gym_leader"
display_name: "Líder de Gimnasio"
reward_multiplier: 5.0
default_battle_sprite: null  # Cada líder tiene su propio sprite
default_ai: null  # Cada líder puede tener su IA
description: "Líder de un gimnasio Pokémon"
```

### Entrenador genérico (pokemon_trainer.tres):

```gdscript
id: 202
internal_name: "pokemon_trainer"
display_name: "Entrenador Pokémon"
reward_multiplier: 1.0
default_battle_sprite: null
default_ai: null
description: "Entrenador Pokémon estándar"
```

## 🎮 Cómo se usa

### En TrainerData:

```gdscript
TrainerData (brock.tres):
├─ Trainer Class Id: GYM_LEADER_BROCK  ← Selecciona del dropdown
│  (Automáticamente cargará gym_leader.tres)
├─ Display Name: "Brock"
└─ ...

# Al inicializar:
trainer_data.initialize()  # Carga TrainerClassData
trainer_data.get_full_name()  # "Líder de Gimnasio Brock"
trainer_data.calculate_reward()  # Usa el multiplicador 5.0 de gym_leader
```

## ⚙️ Sistema de carga

1. Seleccionas `trainer_class_id` del enum (ej: `GYM_LEADER_BROCK`)
2. Al llamar `initialize()`, se carga el `.tres` correspondiente
3. Si no existe el `.tres`, crea uno temporal con el nombre del enum

**Nota:** Hasta que creemos los `.tres`, el sistema creará automáticamente TrainerClassData temporales con los nombres correctos. El juego funcionará perfectamente.

## 🚀 Próximos pasos

1. Abrir Godot para que compile las nuevas clases
2. Crear los `.tres` básicos (gym_leader, elite_four, pokemon_trainer)
3. (Opcional) Crear todos los tipos de entrenador
4. Actualizar DatabaseManager para cargar TrainerClasses automáticamente

