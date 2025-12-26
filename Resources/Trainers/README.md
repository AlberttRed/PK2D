# 📂 Trainers - Sistema de TrainerData

Esta carpeta contiene los archivos `.tres` que definen los datos de cada entrenador del juego.

## 🎯 ¿Qué es un TrainerData?

`TrainerData` es un Resource que centraliza toda la información de un entrenador:
- Identidad (ID, clase, nombre)
- Sprites para combate
- Equipo de Pokémon (como Array[PokemonData])
- IA de combate
- Textos de introducción/derrota/victoria
- Configuración de combate (doble, recompensa)

## 📝 Cómo crear un nuevo entrenador

### Opción 1: Desde el Inspector (Recomendado)

1. En Godot, ve a `FileSystem` → `Resources/Trainers/`
2. Click derecho → `New Resource`
3. Busca y selecciona `TrainerData`
4. Configura los campos:
   ```
   Identification:
   ├─ Trainer Id: 1
   ├─ Trainer Class: "Líder de Gimnasio"
   └─ Display Name: "Brock"
   
   Sprites:
   ├─ Battle Sprite: (arrastra sprite)
   └─ Overworld Sprite: (opcional)
   
   IA:
   └─ Ai Profile: null (o arrastra BattleIA)
   
   Textos:
   ├─ Intro Text: "¡Soy Brock, el líder de gimnasio!"
   ├─ Defeat Text: "Has demostrado tu valía..."
   └─ Victory Text: "¡Gané!"
   
   Equipo:
   ├─ Party Data:
   │  ├─ [0]: (arrastra Pokemon #074 - Geodude)
   │  └─ [1]: (arrastra Pokemon #095 - Onix)
   ├─ Party Levels:
   │  ├─ [0]: 12
   │  └─ [1]: 14
   
   Configuración:
   ├─ Allow Double Battle: false
   └─ Reward Money: 1386
   ```
5. Guarda como `Resources/Trainers/brock.tres`

### Opción 2: Por código (Avanzado)

```gdscript
var trainer_data = TrainerData.new()
trainer_data.trainer_id = 1
trainer_data.trainer_class = "Líder de Gimnasio"
trainer_data.display_name = "Brock"
trainer_data.intro_text = "¡Soy Brock!"
trainer_data.defeat_text = "Has ganado..."
trainer_data.reward_money = 1386

# Equipo
var geodude = DatabaseManager.get_pokemon(74)
var onix = DatabaseManager.get_pokemon(95)
trainer_data.party_data = [geodude, onix]
trainer_data.party_levels = [12, 14]

# Guardar
ResourceSaver.save(trainer_data, "res://Resources/Trainers/brock.tres")
```

## 🎮 Cómo usar un TrainerData

### En un Battler (NPC/Trainer):

```gdscript
# En la escena del NPC/Trainer, en el nodo Battler:
@export var trainer_data: TrainerData = preload("res://Resources/Trainers/brock.tres")

# Al inicializar (_ready), el Battler cargará automáticamente:
# - El equipo de Pokémon
# - Los textos
# - La IA
# - Los sprites
```

### En eventos/comandos:

```gdscript
# Cargar un entrenador para un combate scriptado
var brock = preload("res://Resources/Trainers/brock.tres")

# Crear participante desde TrainerData
var battler = Battler.new()
battler.trainer_data = brock
battler._load_from_trainer_data()
var participant = battler.to_battle_participant()

# Iniciar combate
SignalManager.battle_requested.emit([player_participant, participant], rules)
```

## 📋 Estructura de archivos recomendada

```
Resources/Trainers/
├── gym_leaders/
│   ├── brock.tres
│   ├── misty.tres
│   └── ...
├── elite_four/
│   ├── lorelei.tres
│   └── ...
├── rivals/
│   ├── rival_route1.tres
│   ├── rival_cerulean.tres
│   └── ...
└── trainers/
	├── youngster_joey.tres
	└── ...
```

## ✨ Ventajas del sistema

- ✅ **Centralizado**: Toda la info del entrenador en un archivo
- ✅ **Reutilizable**: Mismo entrenador en múltiples lugares
- ✅ **Fácil de modificar**: Cambios en el .tres se reflejan en todo el juego
- ✅ **Versionable**: Fácil de trackear en Git
- ✅ **Inspector-friendly**: Configuración visual desde Godot
- ✅ **Scriptable**: Compatible con eventos y comandos

## 🔧 Métodos útiles de TrainerData

```gdscript
var trainer = preload("res://Resources/Trainers/brock.tres")

# Crear equipo runtime
var party: Array[Pokemon] = trainer.create_party()

# Obtener información
var full_name = trainer.get_full_name()  # "Líder de Gimnasio Brock"
var intro = trainer.get_intro_message()
var defeat = trainer.get_defeat_message()
var reward = trainer.calculate_reward()

# Verificar estado
if trainer.has_valid_party():
	print("Equipo válido")

# Debug
trainer.print_trainer_info()
```

## 📊 Compatibilidad

El sistema TrainerData es **retrocompatible**:
- Si un Battler NO tiene `trainer_data`, funciona como antes (configuración manual)
- Si un Battler SÍ tiene `trainer_data`, se carga automáticamente desde ahí

Ambos modos pueden coexistir en el mismo proyecto.
