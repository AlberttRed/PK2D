# WorldChunkController - Sistema de Chunks Globales del Mundo

## 📋 Resumen

WorldChunkController gestiona la división del mundo en chunks globales para optimizar la carga y procesamiento de mapas, eventos y tiles según la posición del jugador. Utiliza un sistema de **chunks globales** con **evaluación lazy** para máximo rendimiento.

---

## 🎯 Concepto Clave: Chunks Globales

Los chunks son una **división del MUNDO COMPLETO** (todos los mapas cargados), no de mapas individuales. Cada chunk tiene coordenadas globales basadas en posición mundial y se crean **bajo demanda** cuando se necesita cubrir un área.

### Características

- **Chunks globales**: División del mundo completo, no por mapa
- **Coordenadas globales**: `chunk_<x>_<y>` basadas en posición mundial
- **Creación bajo demanda**: Se crean solo cuando se necesitan
- **Múltiples mapas por chunk**: Un chunk puede contener partes de varios mapas

---

## ⚡ Evaluación Lazy (Sin Coste para Chunks Lejanos)

### Principio Fundamental

- **Chunks inactivos**: Coste = 0, no se calcula nada
- **Chunk se activa (primera vez)**: Se calculan eventos/tiles de ese chunk
- **Chunk se reactiva**: Usa datos ya calculados (sin recalcular)
- **Chunk se desactiva**: Eventos/tiles dejan de procesar

### Flujo de Activación

```
1. Mapa se carga → Solo se registra en chunks globales (rápido, O(1))
2. Chunk está inactivo → NO se calcula nada, coste = 0
3. Player se acerca → Chunk se activa por primera vez
4. Chunk se activa → AHORA se calcula qué eventos/tiles tiene (lazy)
5. Chunk activo → Eventos/tiles procesándose
6. Player se aleja → Chunk se desactiva → Eventos/tiles dejan de procesar
7. Player vuelve → Chunk se reactiva → Usa datos ya calculados (sin recalcular)
```

---

## 🏗️ Arquitectura

```
WorldSystem
    └── WorldChunkController (hijo)
            ├── chunk_registry: {chunk_id: ChunkData}
            └── map_to_chunks: {map_id: Array[chunk_ids]}
```

### Componentes Clave

#### ChunkData
Clase que representa un chunk global:
- `id: String` - Identificador único (formato: `chunk_<x>_<y>`)
- `map_ids: Array[String]` - IDs de mapas que cubre este chunk
- `world_bounds: Rect2` - Bounds del chunk en coordenadas mundiales
- `is_active: bool` - Estado de activación actual
- `events_initialized: bool` - ¿Ya se calcularon los eventos? (lazy)
- `event_refs: Array[WeakRef]` - Referencias a eventos (solo cuando está activo)
- `tiles_initialized: bool` - ¿Ya se calcularon los tiles? (lazy)
- `special_tiles: Array[Vector2i]` - Tiles especiales (solo cuando está activo)

#### chunk_registry
Registro de todos los chunks globales: `{chunk_id: ChunkData}`

#### map_to_chunks
Relación mapa -> chunks que cubre: `{map_id: Array[String]}`

---

## 🔧 Funcionamiento

### Tamaño de Chunks

Los chunks tienen un **tamaño físico fijo de 16x16 tiles** (512x512 píxeles con tiles de 32x32).

Este tamaño está basado en:
- Vista visible: ~6.5 tiles arriba + 1 tile del player + ~6.5 tiles abajo = ~14 tiles verticales
- Margen de 1 tile por cada lado = **16x16 tiles por chunk**

### Registro de Mapas

Cuando un mapa se carga en el mundo:

1. Se calcula su posición mundial y tamaño
2. Se determina qué chunks globales cubre
3. Se crean los chunks que no existen (bajo demanda)
4. Se registra el mapa en esos chunks

**Ejemplo:**
```
Mapa "PuebloPaleta" en posición (0, 0), tamaño 30x30 tiles
→ Cubre chunks: chunk_0_0, chunk_0_1, chunk_1_0, chunk_1_1

Mapa "Ruta1" en posición (0, -480), tamaño 20x20 tiles
→ Cubre chunks: chunk_0_-1, chunk_0_0 (parcialmente)
```

### Gestión de Chunks Activos

- **get_active_chunks(player_position)** → Determina qué chunks están activos usando `world_bounds` y distancia física
- **activate_chunk(chunk_id)** → Activa un chunk (calcula eventos/tiles si es primera vez)
- **deactivate_chunk(chunk_id)** → Desactiva un chunk (detiene procesamiento)
- **update_active_chunks(player_position)** → Actualiza el estado de activación según la posición del jugador

### Integración con WorldSystem

Los métodos `_preload_neighbors()` y `_unload_non_neighbors()` de WorldSystem ahora delegan en WorldChunkController:
- Consultan qué chunks están activos
- Cargar/descargar mapas según los chunks activos
- Mantienen compatibilidad con el sistema anterior (fallback si no hay chunk_controller)

---

## 📝 Interfaz para Futuras Integraciones

### Métodos Públicos Disponibles

#### Obtener Información de Chunks

```gdscript
# Obtener chunks activos según posición del jugador
func get_active_chunks(player_position: Vector2) -> Array[String]

# Obtener los chunks a los que pertenece un mapa
func get_chunks_for_map(map_id: String) -> Array[String]

# Obtener todos los mapas de un chunk
func get_chunk_maps(chunk_id: String) -> Array[String]

# Obtener información completa de un chunk
func get_chunk_info(chunk_id: String) -> ChunkData

# Verificar si un chunk está activo
func is_chunk_active(chunk_id: String) -> bool
```

#### Gestión de Chunks

```gdscript
# Activar un chunk (calcula eventos/tiles si es primera vez - lazy)
func activate_chunk(chunk_id: String) -> void

# Desactivar un chunk
func deactivate_chunk(chunk_id: String) -> void

# Actualizar chunks activos según posición del jugador
func update_active_chunks(player_position: Vector2) -> void

# Registrar un mapa en chunks globales
func register_map_to_global_chunks(map_id: String) -> void
```

---

## 🚀 Guía para Futuras Optimizaciones

### Eventos por Chunk (Ya Implementado - Lazy)

Los eventos se calculan automáticamente cuando un chunk se activa por primera vez:

```gdscript
# En activate_chunk():
if not chunk_data.events_initialized:
    _initialize_chunk_events(chunk_id)  # Calcula eventos solo ahora
    chunk_data.events_initialized = true

# Los eventos se activan/desactivan automáticamente
_activate_chunk_events(chunk_id)
```

### Tiles Especiales por Chunk (Ya Implementado - Lazy)

Los tiles especiales se calculan automáticamente cuando un chunk se activa:

```gdscript
# En activate_chunk():
if not chunk_data.tiles_initialized:
    _initialize_chunk_tiles(chunk_id)  # Calcula tiles solo ahora
    chunk_data.tiles_initialized = true

# Los tiles se activan/desactivan automáticamente
_activate_chunk_tiles(chunk_id)
```

### Extender para Nuevos Tipos de Contenido

Para añadir nuevos tipos de contenido (NPCs, efectos, etc.):

1. Añadir campos a `ChunkData`:
   ```gdscript
   var npcs_initialized: bool = false
   var npc_refs: Array[WeakRef] = []
   ```

2. Implementar inicialización lazy:
   ```gdscript
   func _initialize_chunk_npcs(chunk_id: String) -> void:
       # Calcular NPCs solo cuando se activa
   ```

3. Llamar en `activate_chunk()`:
   ```gdscript
   if not chunk_data.npcs_initialized:
       _initialize_chunk_npcs(chunk_id)
       chunk_data.npcs_initialized = true
   ```

---

## ⚙️ Configuración

### Parámetros Exportables

En `WorldSystem.gd` (configurables desde el Inspector de Godot):

- **chunk_size: Vector2i** = `Vector2i(16, 16)` - Tamaño de chunk en tiles
  - **Configurable**: Puedes cambiar este valor desde el Inspector cuando seleccionas el nodo WorldSystem
  - **Valor por defecto**: 16x16 tiles (512x512 píxeles con tiles de 32x32)
  - **Uso**: Todos los mapas se dividirán en chunks de este tamaño
- **chunk_activation_radius: int** = `1` - Distancia de activación (en chunks) desde la posición del jugador
  - **Configurable**: Puedes ajustar cuántos chunks alrededor del jugador se mantienen activos

---

## 📌 Notas Importantes

1. **Registro Bajo Demanda**: Los mapas se registran en chunks cuando se cargan en el mundo, no cuando se registran en WorldSystem
2. **Chunks Globales**: Los chunks son una división del mundo completo, no de mapas individuales
3. **Evaluación Lazy**: Los eventos/tiles solo se calculan cuando el chunk se activa por primera vez
4. **Sin Coste para Chunks Lejanos**: Los chunks inactivos no tienen ningún coste de procesamiento
5. **Reutilización de Datos**: Si un chunk se desactiva y reactiva, usa los datos ya calculados
6. **Creación Automática**: Los chunks se crean automáticamente cuando se necesita cubrir un área

---

## ✅ Acceptance Criteria Cumplidos

- ✅ Existe el nodo WorldChunkController como hijo de WorldSystem
- ✅ WorldChunkController mantiene una estructura interna (chunk_registry) que relaciona mapas con chunks globales
- ✅ WorldSystem puede consultar qué chunks deben estar activos según la posición del jugador
- ✅ Los métodos de carga de vecinos de WorldSystem pueden delegar en WorldChunkController
- ✅ No se rompen las funcionalidades actuales de carga de mapas y precarga de vecinos
- ✅ Se deja documentado el contrato de interfaz para integración con optimizaciones posteriores
- ✅ Sistema de evaluación lazy implementado (sin coste para chunks inactivos)

---

## 🔮 Próximos Pasos (PBIs Futuros)

1. **Activar eventos por proximidad**: Ya implementado con evaluación lazy
2. **Activar tiles especiales por proximidad**: Ya implementado con evaluación lazy
3. **Optimizar NPCs por chunks**: Extender el sistema para NPCs
4. **Mejorar cálculo de proximidad**: Ajustar radio de activación según necesidades
5. **Debug visual**: Mostrar chunks activos en el editor

---

## 🔍 Debugging

### Métodos de Utilidad

```gdscript
# Imprimir estado de todos los chunks
chunk_controller.print_chunk_status()

# Acceder desde WorldSystem
var chunk_controller = world_system.get_chunk_controller()
chunk_controller.print_chunk_status()
```

### Salida de Ejemplo

```
=== WorldChunkController Status ===
Tamaño de chunk: 16x16 tiles
Radio de activación: 1 chunks
Total chunks registrados: 12
Chunks activos: 9

Mapas y sus chunks:
  - MapaPuebloTest: 4 chunk(s)
  - Ruta1: 2 chunk(s)
  - Ruta21: 2 chunk(s)

Chunks individuales:
  - chunk_0_0: ACTIVO (15 eventos) (8 tiles)
  - chunk_0_1: ACTIVO (12 eventos) (5 tiles)
  - chunk_1_0: inactivo
  - chunk_1_1: inactivo
```

---

## 💡 Ventajas del Sistema

✅ **Sin coste para chunks lejanos** - Chunks inactivos no procesan nada
✅ **Cálculo una sola vez** - Eventos/tiles se calculan solo cuando se activa por primera vez
✅ **Reutilización de datos** - Si un chunk se reactiva, usa datos ya calculados
✅ **Escalable** - Funciona con cualquier cantidad de mapas sin impacto hasta que se activan
✅ **Chunks globales** - División consistente del mundo, no por mapa
✅ **Creación bajo demanda** - Los chunks se crean solo cuando se necesitan

