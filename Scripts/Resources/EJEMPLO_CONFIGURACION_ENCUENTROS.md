# Configuración de Encuentros Salvajes

## Resumen del PBI 288

Este documento explica cómo configurar los datos de encuentros salvajes en el editor de Godot.

## Archivos Creados

### Nodos (Scripts/Resources/)
- **`MapAreaEncounters.gd`** (Node): Contenedor principal de encuentros, se agrega como nodo en la escena del mapa
- **`AreaEncounter.gd`** (Node): Define un tipo de área (LAND, WATER, etc.), hijo de MapAreaEncounters
- **`MapPokemonEncounter.gd`** (Resource): Define un Pokémon con nivel y probabilidad

### Escenas (Scenes/Overworld/Core/)
- `MapAreaEncounters.tscn`: Escena base para el contenedor de encuentros
- `AreaEncounter.tscn`: Escena base para un área de encuentro

### Enums (Scripts/Enums/)
- `EncounterAreaTypeEnum.gd`: Define los tipos de áreas (EncounterAreaTypeEnum.Values: LAND, WATER, CAVE, etc.)

## Estructura de Nodos en el Mapa

```
MapaRuta01.tscn
├── TileMap
├── Player
└── MapAreaEncounters (Node)
    ├── LandEncounter (AreaEncounter Node)
    │   @export pokemon_encounters: Array[MapPokemonEncounter]
    ├── WaterEncounter (AreaEncounter Node)
    │   @export pokemon_encounters: Array[MapPokemonEncounter]
    └── CaveEncounter (AreaEncounter Node)
        @export pokemon_encounters: Array[MapPokemonEncounter]
```

## Cómo Crear Encuentros en el Editor

### Paso 1: Crear MapPokemonEncounter (Resources)

1. En el FileSystem, navega a `Resources/Data/` (o crea una carpeta `Resources/Data/WildEncounters/`)
2. Click derecho → New Resource → MapPokemonEncounter
3. Configura:
   - `pokemon_id`: ID del Pokémon (ej: 25 para Pikachu)
   - `min_level`: Nivel mínimo (ej: 3)
   - `max_level`: Nivel máximo (ej: 5)
   - `probability`: Probabilidad de aparición (ej: 30.0 para 30%)

**Ejemplo**: Crea varios archivos como:
- `Pidgey_Lv2-4_40percent.tres`
- `Rattata_Lv2-4_30percent.tres`
- `Pikachu_Lv3-5_30percent.tres`

💡 **Tip**: Estos resources se pueden reutilizar en diferentes mapas/áreas.

### Paso 2: Agregar MapAreaEncounters al Mapa (Nodo)

1. Abre la escena de tu mapa (ej: `Route01.tscn`)
2. Agrega un nodo hijo al mapa:
   - Opción A: Instancia la escena `Scenes/Overworld/Core/MapAreaEncounters.tscn`
   - Opción B: Agrega un nodo Node y asígnale el script `MapAreaEncounters.gd`
3. Renombra el nodo a "MapAreaEncounters" o "Encounters"

### Paso 3: Agregar AreaEncounter (Nodos hijos)

1. Con el nodo MapAreaEncounters seleccionado, agrega nodos hijos:
   - Opción A: Instancia la escena `Scenes/Overworld/Core/AreaEncounter.tscn`
   - Opción B: Agrega un nodo Node y asígnale el script `AreaEncounter.gd`

2. Configura cada AreaEncounter:
   - **Renombra el nodo** según el tipo (ej: "LandEncounter", "WaterEncounter")
   - `area_type`: Selecciona el tipo (LAND, WATER, CAVE, etc.)
   - `base_encounter_rate`: Probabilidad por paso (ej: 10.0 = 10%)
   - `pokemon_encounters`: Array de resources
     - Click "Add Element" y arrastra los .tres del Paso 1
   - `time_of_day_filter`: Opcional, déjalo vacío

**⚠️ CRÍTICO**: La suma de todos los `probability` en `pokemon_encounters` **DEBE** ser **exactamente 100.0%**

Si las probabilidades no suman 100%, el juego mostrará un **ERROR CRÍTICO** al cargar el mapa y la configuración será rechazada.

### Paso 4: Guardar la Escena

Guarda la escena del mapa. Los encuentros quedarán configurados como parte de la jerarquía de nodos.

## Validaciones

El sistema incluye validaciones automáticas **al cargar el mapa**:

### ✅ Validaciones de MapPokemonEncounter
- Los niveles min/max son válidos (min ≤ max, ambos ≥ 1)
- El pokemon_id es válido (> 0)

### ✅ Validaciones de AreaEncounter
- Si hay Pokémon definidos, sus probabilidades **DEBEN** sumar **exactamente 100.0%**
- No hay MapPokemonEncounter nulos en el array
- Todos los MapPokemonEncounter son válidos

### ✅ Validaciones de MapAreaEncounters
- No hay áreas duplicadas (mismo area_type)
- Todos los AreaEncounter hijos son válidos

### 🔍 Cómo Probar las Validaciones

**Opción 1: Automática (al ejecutar el juego)**
```gdscript
# Al cargar el mapa, se ejecuta automáticamente _ready() en cada AreaEncounter
# Si hay errores, verás mensajes en el Output
```

**Opción 2: Manual desde código**
```gdscript
# En el script del mapa o en _ready()
var encounters = $MapAreaEncounters
if encounters:
    if encounters.validate():
        print("✅ Encuentros configurados correctamente")
    else:
        push_error("❌ Error en la configuración de encuentros")
```

**Opción 3: Debug Info**
```gdscript
# Muestra información detallada de un AreaEncounter
var land_encounter = $MapAreaEncounters/LandEncounter
land_encounter.print_validation()
```

### ❌ Ejemplo de Error

Si las probabilidades no suman 100%, verás:
```
ERROR: AreaEncounter [Land]: ERROR CRÍTICO - Las probabilidades suman 95.00% 
pero DEBEN sumar exactamente 100.0% (diferencia: 5.00%)
  → Revisa los valores de 'probability' en cada MapPokemonEncounter
```

**Solución**: Ajusta los valores de `probability` en tus MapPokemonEncounter hasta que sumen 100.0%

## Ejemplo Completo de Configuración

### Ruta 1 - Hierba Alta

**1. Crear Resources (Resources/Data/WildEncounters/Route01/):**

`Pidgey_Route01.tres` (MapPokemonEncounter)
```
pokemon_id: 16 (Pidgey)
min_level: 2
max_level: 4
probability: 40.0  # 40%
```

`Rattata_Route01.tres` (MapPokemonEncounter)
```
pokemon_id: 19 (Rattata)
min_level: 2
max_level: 4
probability: 30.0  # 30%
```

`Pikachu_Route01.tres` (MapPokemonEncounter)
```
pokemon_id: 25 (Pikachu)
min_level: 3
max_level: 5
probability: 30.0  # 30%
```

**Total: 40% + 30% + 30% = 100% ✅**

**2. Estructura en la Escena Route01.tscn:**

```
Route01 (Node2D o TileMap)
├── TileMap
├── Player
└── MapAreaEncounters (Node - script: MapAreaEncounters.gd)
    └── LandEncounter (Node - script: AreaEncounter.gd)
        area_type: LAND
        base_encounter_rate: 10.0
        pokemon_encounters: [
            res://Resources/Data/WildEncounters/Route01/Pidgey_Route01.tres,
            res://Resources/Data/WildEncounters/Route01/Rattata_Route01.tres,
            res://Resources/Data/WildEncounters/Route01/Pikachu_Route01.tres
        ]
        time_of_day_filter: []
```

**3. Llamar desde código (opcional):**

```gdscript
# Validar encuentros al cargar el mapa
var encounters = $MapAreaEncounters
if encounters:
    if not encounters.validate():
        push_error("Configuración de encuentros inválida")
    
    # Debug info
    print(encounters.get_debug_info())
```

## Próximos Pasos

- **PBI 377**: Detección de zonas de encuentro en el Overworld
- **PBI 375**: Sistema de cálculo y generación de encuentros

