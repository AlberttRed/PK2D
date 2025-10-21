# Configuración de Encuentros Salvajes en el Overworld

## PBI 377 - Detección de zonas de encuentro salvaje

Este documento explica cómo configurar tiles en el Overworld para que generen encuentros salvajes.

## Resumen del Sistema

El sistema funciona en tres pasos:
1. **Tiles marcados**: Los tiles del TileMap tienen un custom_data `encounter_type`
2. **Detección**: `WildEncounterDetector` detecta cuando el jugador pisa estos tiles
3. **Generación**: Se consulta `MapAreaEncounters` y se genera el combate

## Configuración de Tiles (TileSet)

### Paso 1: Configurar Custom Data en el TileSet

1. Abre tu TileSet (ej: `Outside_tileset.tres`)
2. En el Inspector, busca la sección **Custom Data**
3. Agrega una nueva capa custom data:
   - **Name**: `encounter_type`
   - **Type**: `String`

### Paso 2: Asignar Tipos a los Tiles

Para cada tile que debe generar encuentros:

1. Selecciona el tile en el editor de TileSet
2. En la sección **Custom Data**, establece `encounter_type`:
   - `"Land"` - Para hierba alta / tierra
   - `"Water"` - Para agua (surfing)
   - `"Cave"` - Para cuevas
   - `"Sand"` - Para arena/playa
   - `"Fishing"` - Para pescar
   - `"RockSmash"` - Para romper rocas
   - `"Headbutt"` - Para golpear árboles

**Ejemplo**: Para hierba alta:
```
encounter_type: "Land"
```

### Paso 3: Pintar los Tiles en el Mapa

Usa el TileMapLayer para pintar los tiles configurados en tu mapa.

## Configuración del Mapa

Cada mapa debe tener un nodo `MapAreaEncounters` configurado (ver PBI 288).

### Estructura Requerida

```
MapaRuta01.tscn
├── OverworldGrid
│   ├── TileMapLayer (con tiles que tienen encounter_type)
│   └── ...
└── MapAreaEncounters (Node)
    └── LandEncounter (AreaEncounter Node)
        area_type: LAND
        base_encounter_rate: 10.0
        pokemon_encounters: [...]
```

**IMPORTANTE**: El nombre del nodo puede ser "MapAreaEncounters" o "Encounters", pero debe ser de tipo `MapAreaEncounters`.

## Ejemplo Completo

### 1. TileSet: Configurar tile de hierba

En `Outside_tileset.tres`:
- Tile de hierba alta → `encounter_type = "Land"`
- Tile de agua → `encounter_type = "Water"`

### 2. Mapa: Configurar encuentros

En `Route01.tscn`:

```
Route01 (Node2D)
├── OverworldGrid
│   └── TileMapLayer
│       └── (tiles de hierba con encounter_type="Land")
└── MapAreaEncounters
    └── LandEncounter (AreaEncounter)
        area_type: LAND
        base_encounter_rate: 10.0  # 10% por paso
        pokemon_encounters:
          - Pidgey (Lv.2-4): 40%
          - Rattata (Lv.2-4): 30%
          - Pikachu (Lv.3-5): 30%
```

### 3. Probar

1. Ejecuta el juego
2. Camina sobre los tiles de hierba
3. Deberías ver:
   - Efecto visual de hierba al pisar
   - Encuentros aleatorios según la probabilidad configurada

## Flujo del Sistema

```
Jugador pisa tile
    ↓
GridMotion emite step_finished(tile)
    ↓
WildEncounterDetector._on_step_finished()
    ↓
¿encounters_enabled? No → Return
    Sí ↓
¿Mapa tiene MapAreaEncounters? (cache) No → Return (OPTIMIZACIÓN)
    Sí ↓
Leer tile_data.get_custom_data("encounter_type")
    ↓
¿Tiene encounter_type? No → Return
    Sí ↓
¿El área tiene encuentros configurados? (cache) No → Return (OPTIMIZACIÓN)
    Sí ↓
        Mostrar GrassEffect (si es hierba)
        ↓
        MapAreaEncounters.try_wild_encounter(area_type)
        ↓
        AreaEncounter.should_trigger_encounter()  # Random según base_encounter_rate
        ↓
        ¿Ocurre encuentro?
            No → Continuar caminando
            Sí ↓
                AreaEncounter.get_random_pokemon()  # Random según probabilities
                ↓
                WildEncounterDetector._start_wild_battle()
                ↓
                SignalManager.battle_requested.emit(...)
```

### Optimizaciones de Rendimiento

El sistema incluye varias optimizaciones para minimizar el procesamiento:

1. **Desconexión dinámica de señal**: La señal `step_finished` se **desconecta completamente** cuando el mapa no tiene encuentros
   - Al entrar a un mapa con encuentros → señal CONECTADA
   - Al entrar a un mapa sin encuentros → señal DESCONECTADA
   - `_on_step_finished()` ni siquiera se ejecuta si la señal está desconectada
   
2. **Cache de MapAreaEncounters**: Se guarda la referencia al nodo de encuentros del mapa actual
   - Se actualiza automáticamente al cambiar de mapa (seamless o warp)
   - La señal se conecta/desconecta automáticamente según el cache
   
3. **Verificación de área antes de procesar**: Se verifica si el área específica (LAND, WATER, etc.) tiene Pokémon configurados

**Resultado**: 
- En mapas **SIN** encuentros (ciudades, edificios): **0 operaciones por paso** ⚡
- En mapas **CON** encuentros: Solo se ejecuta la lógica cuando es necesario

## Efecto Visual de Hierba

El efecto de hierba se muestra automáticamente cuando:
- El jugador pisa un tile con `encounter_type = "Land"`
- Se instancia `GrassEffect.tscn` en la posición del tile
- Se auto-destruye al terminar la animación

Para cambiar el efecto:
1. Modifica `Scenes/Overworld/Others/GrassEffect.tscn`
2. O cambia `grass_effect_scene` en el `WildEncounterDetector` del Player

## Deshabilitar Encuentros

Para deshabilitar encuentros temporalmente (ej: durante un evento):

```gdscript
# Obtener el detector del player
var detector = player.get_node("WildEncounterDetector")
if detector:
    detector.set_encounters_enabled(false)

# Re-habilitar más tarde
detector.set_encounters_enabled(true)
```

## Debugging

### Ver información del mapa actual

```gdscript
# Desde el Player
var detector = $WildEncounterDetector
if detector:
    # Verificar si el mapa tiene encuentros
    if detector.has_encounters_in_current_map():
        print("✅ Mapa '%s' tiene encuentros" % detector.get_current_map_name())
        print(detector.get_current_map_debug_info())
    else:
        print("❌ Mapa '%s' NO tiene encuentros" % detector.get_current_map_name())
```

Output:
```
Mapa actual 'Route01':
MapAreaEncounters:
AreaEncounter [Land]
  Base Rate: 10.0%
  Pokémon (3):
    - Pidgey (Lv.2-4): 40.0%
    - Rattata (Lv.2-4): 30.0%
    - Pikachu (Lv.3-5): 30.0%
  ✅ TOTAL: 100.00% (OK)
```

### Ver información de encuentros directamente

```gdscript
# En el mapa
var encounters = $MapAreaEncounters
if encounters:
    print(encounters.get_debug_info())
```

### Verificar custom_data de un tile

```gdscript
var grid = $OverworldGrid
var tile = Vector2i(5, 3)
var tile_data_array = grid.get_tile_data(tile)
for tile_data in tile_data_array:
    var encounter_type = tile_data.get_custom_data("encounter_type")
    print("Tile (%d, %d) encounter_type: %s" % [tile.x, tile.y, encounter_type])
```

### Verificar estado del cache y señal

```gdscript
# Ver cuando se actualiza el cache y la señal (en el Output)
# Al cambiar de mapa verás:
# "WildEncounterDetector: Mapa 'Route01' → CON encuentros (señal CONECTADA)"
# o
# "WildEncounterDetector: Mapa 'PewterCity' → SIN encuentros (señal DESCONECTADA)"
```

### Verificar si la señal está conectada

```gdscript
# Desde el detector
var detector = player.get_node("WildEncounterDetector")
print("Señal conectada: ", detector._signal_connected)
print("Mapa actual: ", detector.get_current_map_name())
print("Tiene encuentros: ", detector.has_encounters_in_current_map())
```

## Próximos Pasos

- **PBI 375**: Sistema de cálculo y generación completa de encuentros (movimientos, stats, etc.)
- Agregar más efectos visuales para otros tipos de terreno
- Sistema de repelentes
- Incremento de encuentros con habilidades (Illuminate, etc.)

## Archivos Creados

- `Scripts/Overworld/WildEncounterDetector.gd` - Sistema de detección
- `Scripts/Overworld/GrassEffect.gd` - Efecto visual de hierba
- `Scenes/Overworld/Others/GrassEffect.tscn` - Escena del efecto
- Modificado: `Scenes/Overworld/Actors/Player.tscn` - Agregado WildEncounterDetector

## Señales Emitidas

### SignalManager.battle_requested
```gdscript
SignalManager.battle_requested.emit(participants: Array, rules: BattleRules)
```

**Participants**: Array con 2 elementos
- `[0]`: BattleParticipant del jugador
- `[1]`: BattleParticipant del Pokémon salvaje

**Rules**: BattleRules configurado como:
- `type`: `WILD`
- `mode`: `SINGLE`
- `environment`: `GRASS`

## Troubleshooting

### No aparecen encuentros
1. ✅ Verifica que el tile tenga `encounter_type` configurado
2. ✅ Verifica que existe `MapAreaEncounters` en el mapa
3. ✅ **Verifica que la señal está conectada** (ver Output: "señal CONECTADA")
4. ✅ Verifica que el `area_type` del AreaEncounter coincida con el `encounter_type` del tile
5. ✅ Verifica que `encounters_enabled = true` en WildEncounterDetector
6. ✅ Verifica que las probabilidades del AreaEncounter sumen 100%

### La señal no se conecta
- Revisa el Output al entrar al mapa
- Si dice "señal DESCONECTADA", el mapa no tiene `MapAreaEncounters` o está mal configurado
- Verifica que el nodo se llame "MapAreaEncounters" o sea de tipo `MapAreaEncounters`

### El efecto de hierba no se muestra
1. ✅ Verifica que `grass_effect_scene` esté asignado en WildEncounterDetector
2. ✅ Verifica que `GrassEffect.tscn` existe en `Scenes/Overworld/Others/`
3. ✅ Verifica que el tile tiene `encounter_type = "Land"`

### Error al iniciar batalla
1. ✅ Verifica que el jugador tiene Pokémon en su equipo
2. ✅ Verifica que `DatabaseManager` puede obtener datos del Pokémon salvaje
3. ✅ Verifica que existe un handler para `SignalManager.battle_requested`

