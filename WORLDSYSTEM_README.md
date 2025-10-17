# WorldSystem - Sistema de Mundo Seamless

## 🎯 Resumen Ejecutivo

Se ha implementado un **sistema de mundo seamless** estilo Pokémon donde múltiples mapas pueden estar visibles simultáneamente y el jugador puede cruzar entre ellos sin transiciones ni pantallas de carga.

---

## 📁 Archivos Creados/Modificados

### ✅ **Nuevos Archivos:**
1. `Scripts/Overworld/Overworld.gd` - Coordinador principal (inyección de dependencias)
2. `Scripts/Overworld/Core/WorldSystem.gd` - Gestor global de mapas
3. `Scripts/Overworld/Core/MapScene.gd` - Script base para todos los mapas

### 🔧 **Modificados:**
1. `Scripts/Overworld/Core/MapSystem.gd` - Soporte para múltiples mapas visibles
2. `Scripts/Overworld/Core/WarpSystem.gd` - Integración con WorldSystem
3. `Scripts/GameStart.gd` - Usa OverworldCoordinator
4. `Scenes/Overworld/Overworld.tscn` - Añadido OverworldCoordinator script
5. `Scenes/Overworld/Maps/TestMap2/MapaPuebloTest.tscn` - Usa MapScene.gd
6. `Scenes/Overworld/Maps/MapHouseTest.tscn` - Usa MapScene.gd

---

## 🏗️ Arquitectura Final

```
Overworld (OverworldCoordinator)
    ├── Inyecta dependencias entre sistemas
    └── Método: configure_from_gamestate()
    
    ├── WorldSystem
    │   ├── Registro de mapas con world_position
    │   ├── Precarga de vecinos (renderizados)
    │   ├── Descarga de no-vecinos
    │   ├── Detección automática de cruce de mapa
    │   └── Sincronización con GameState
    │
    ├── MapSystem
    │   ├── active_map (mapa donde está el jugador)
    │   ├── Múltiples mapas visibles simultáneamente
    │   └── Solo el activo procesa eventos
    │
    ├── WarpSystem
    │   └── Integrado con WorldSystem
    │
    └── EventSystem
```

---

## 🎮 Funcionamiento del Sistema Seamless

### **Precarga de Vecinos:**
```
Estás en PuebloPaleta (position: 0, 0)
  ├─ Activo: PuebloPaleta ✅ procesa eventos
  └─ Vecinos renderizados:
      ├─ Ruta1 (position: 0, -480) visible pero sin procesar
      └─ Ruta21 (position: 0, 480) visible pero sin procesar

Caminas hacia arriba → cruzas a Ruta1
  ├─ Detección automática: global_position está en Ruta1
  ├─ Cambio seamless:
  │   ├─ Desactiva: PuebloPaleta (visible pero sin procesar)
  │   ├─ Activa: Ruta1 ✅ (ahora procesa eventos)
  │   └─ Emite: active_grid_changed(Ruta1.grid)
  ├─ Precarga vecino: CiudadVerde (position: 0, -960)
  └─ Descarga: Ruta21 (no es vecino de Ruta1)
```

---

## 📝 Configuración de Mapas

### **1. Cada mapa debe usar MapScene.gd:**

En el inspector de cada escena de mapa:
- **Script:** `MapScene.gd`
- **World Position:** Coordenadas mundiales (ej: `Vector2(0, -480)`)
- **Map ID:** Auto-detectado del nombre (opcional configurar)

### **2. Configurar vecinos en WorldSystem:**

```gdscript
# En WorldSystem._register_maps()
register_map_with_position("PuebloPaleta", Vector2(0, 0))
register_map_with_position("Ruta1", Vector2(0, -480))
register_map_with_position("Ruta21", Vector2(0, 480))

set_map_neighbors("PuebloPaleta", ["Ruta1", "Ruta21"])
set_map_neighbors("Ruta1", ["PuebloPaleta", "CiudadVerde"])
```

### **3. Calcular world_position:**

**Fórmula:**
```
world_position = tamaño_mapa_anterior * tile_size * dirección

Ejemplo:
- PuebloPaleta: 30 tiles alto, tile_size: 16px
- Ruta1 está arriba → Y negativo
- Position: Vector2(0, -30 * 16) = Vector2(0, -480)
```

---

## 🔍 Componentes Clave

### **MapScene.gd** (Script Base de Mapas)
- `world_position`: Configurable desde inspector
- `contains_world_position()`: Detecta si una posición está en este mapa
- `activate()` / `deactivate()`: Control de procesamiento
- `get_grid()`: Acceso al OverworldGrid

### **WorldSystem** (Gestor Global)
- `_preload_neighbors()`: Renderiza vecinos en MapSystem
- `_unload_non_neighbors()`: Oculta mapas lejanos
- `_on_player_step_finished_seamless()`: Detecta cruces
- `_switch_active_map_seamless()`: Cambio sin descarga

### **MapSystem** (Mapa Activo)
- Mantiene múltiples mapas como hijos
- Solo `active_map` procesa eventos
- Los vecinos están visibles pero desactivados

---

## ⚙️ Flujo de Inicialización

```
[Frame 0] Overworld.tscn carga
  └── Sistemas _ready() completan

[Frame 1] OverworldCoordinator inyecta dependencias
  ├── WorldSystem.map_system = MapSystem
  ├── MapSystem.world_system = WorldSystem
  └── WarpSystem recibe ambos

[Frame 2] GameStart llama configure_from_gamestate()
  ├── WorldSystem.change_to_map("MapaPuebloTest")
  │   ├── Carga mapa principal
  │   ├── Precarga y RENDERIZA vecinos
  │   └── Descarga no-vecinos
  ├── MapSystem.load_player()
  └── Posiciona jugador

[Frame 3+] Sistema seamless activo
  └── En cada paso: detecta si cambió de mapa
```

---

## 🎁 Beneficios

✅ **Transiciones fluidas** - Sin fade negro entre mapas conectados  
✅ **Precarga inteligente** - Vecinos ya cargados y visibles  
✅ **Optimización** - Solo el mapa activo procesa lógica  
✅ **Escalable** - Fácil añadir más mapas configurando vecinos  
✅ **Configurable** - World_position desde inspector  
✅ **Memoria eficiente** - Descarga mapas lejanos automáticamente  

---

## 🔧 Próximos Pasos

1. **Configurar world_position** de cada mapa desde el inspector
2. **Definir relaciones de vecinos** en `WorldSystem._register_maps()`
3. **Probar** caminando entre mapas
4. **Ajustar posiciones** según sea necesario

---

## 🐛 Debug

```gdscript
# En consola de Godot durante el juego:
world_system.print_registry_status()

# Salida:
# === WorldSystem Registry Status ===
# Total mapas registrados: 2
# Mapas cacheados: 2
# Mapa activo: MapaPuebloTest
#   - MapaPuebloTest: cacheado (vecinos: ["MapHouseTest"])
#   - MapHouseTest: cacheado (vecinos: ["MapaPuebloTest"])
```

---

## ⚠️ Notas Importantes

- **Interiores (casas, edificios)** pueden usar la misma `world_position` que el exterior (no seamless)
- **Warps a interiores** mantienen el sistema de fade tradicional
- **Sistema de detección** solo funciona entre mapas seamless (misma world_position diferente = no detecta)
- **Coordenadas** se configuran manualmente o desde inspector de MapScene

