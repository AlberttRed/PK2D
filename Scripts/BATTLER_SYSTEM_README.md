# Sistema de Battler - Guía de Uso

## 🚀 Inicio Rápido

**Para agregar un Battler a tu Player o NPC:**

1. Selecciona el nodo Player/NPC en el Scene tree
2. Click derecho → "Instantiate Child Scene"
3. Elige `PlayerBattler.tscn` (para Player) o `TrainerBattler.tscn` (para NPCs)
4. Con el nodo `Battler` seleccionado, agrega nodos hijos `PokemonInstance`
5. Configura cada PokemonInstance (pkm_id, level, etc.)
6. ¡Listo! Ya puedes iniciar combates

**Estructura resultante:**
```
Player/
└── Battler
    ├── PokemonInstance (Pikachu Lv25)
    ├── PokemonInstance (Charizard Lv36)
    └── PokemonInstance (Blastoise Lv35)
```

---

## Resumen

`Battler` es un nodo que representa un entrenador (Trainer) o al jugador. Gestiona el equipo de Pokémon y lo convierte en `BattleParticipant` para combates.

## ✨ Sistema Híbrido

### ⚠️ Nota Importante sobre PokemonInstance
`PokemonInstance` actualmente hereda de `Node`, por lo que **debe usarse como nodo hijo**, no como Resource.

### Compatibilidad
🔄 Soporta **dos** modos:
- **Nodos hijos** (actual, recomendado) ⭐
- **Resources** (futuro, cuando PokemonInstance se convierta a Resource)

### Ventajas del sistema actual
✅ **Visual**: Ves el equipo en el Scene tree  
✅ **Fácil configuración**: Agregar nodos en el editor  
✅ **Funciona ya**: Sin cambios necesarios  
✅ **Flexible**: Cambiar equipo agregando/quitando nodos

---

## 📦 Escenas Disponibles

Hay tres escenas preconfiguradas para facilitar la configuración:

| Escena | Ubicación | Uso | Preconfiguración |
|--------|-----------|-----|------------------|
| **Battler.tscn** | `Scenes/Overworld/Core/` | Base genérica | Valores por defecto |
| **PlayerBattler.tscn** | `Scenes/Overworld/Core/` | Para el jugador | `is_player: true`<br>`trainer_name: "Red"` |
| **TrainerBattler.tscn** | `Scenes/Overworld/Core/` | Para NPCs | `is_player: false`<br>Mensajes de batalla |

**Recomendación:** Usa `PlayerBattler` o `TrainerBattler` según necesites, ya vienen preconfigurados.

---

## 📋 Configuración en el Editor

### Método: Usando Nodos Hijos (Actual)

1. **Agregar nodo Battler al Player/NPC**
   
   **Opción A: Instanciar escena preconfigurada** ⭐
   - En el Scene tree, selecciona el Player o NPC
   - Click derecho → "Instantiate Child Scene"
   - Elige:
     - `Scenes/Overworld/Core/PlayerBattler.tscn` (para Player)
     - `Scenes/Overworld/Core/TrainerBattler.tscn` (para NPCs)
   
   **Opción B: Agregar nodo manualmente**
   - Agregar Node → Buscar "Battler"
   - O agregar Node genérico y asignar script `Battler.gd`
   
   ```
   Player (Node2D)
   ├── GridMotion
   ├── Occupancy
   ├── WildEncounterDetector
   └── Battler ← Instanciar PlayerBattler.tscn aquí
   ```

2. **Agregar Pokémon como nodos hijos del Battler**

   Con el nodo `Battler` seleccionado:
   - Click derecho → "Add Child Node"
   - Busca y selecciona `PokemonInstance`
   - Agrega uno por cada Pokémon del equipo
   
   ```
   Player (Node2D)
   └── Battler
       ├── PokemonInstance (Pikachu)    ← Configurar aquí
       ├── PokemonInstance (Charizard)  ← Configurar aquí
       └── PokemonInstance (Blastoise)  ← Configurar aquí
   ```

3. **Configurar cada PokemonInstance**

   Selecciona cada nodo `PokemonInstance` y configura en el Inspector:
   - `pkm_id`: ID del Pokémon (ej: 25 para Pikachu)
   - `level`: Nivel del Pokémon
   - `nickname`: Apodo (opcional)
   - Movimientos, stats, etc.

### Futuro: Usando Resources

Cuando `PokemonInstance` se convierta a `Resource` en lugar de `Node`, podrás usar el array `party_resources` directamente en el Inspector.

1. **Agregar nodo Battler**
   ```
   Player (Node2D)
   └── Battler
       ├── PokemonInstance (Pikachu)
       ├── PokemonInstance (Charizard)
       └── PokemonInstance (Blastoise)
   ```

2. **Configurar Trainer Info**
   - Configura `trainer_name`, `is_player`, etc.
   - **NO** configures `party_resources` (déjalo vacío)
   - Los PokemonInstance hijos se cargan automáticamente

---

## 💻 Uso desde Código

### Iniciar Combate Salvaje

```gdscript
# Obtener el Battler del Player
var player_battler = player.get_node("Battler")

# Crear Pokémon salvaje
var wild_pokemon = PokemonInstance.new().create(true, 25, 15)  # Pikachu Lv15
wild_pokemon.is_wild = true

# Crear participantes
var player_participant = player_battler.to_battle_participant()
var wild_participant = BattleParticipantWild.new([wild_pokemon.to_battle_pokemon()])

# Crear reglas
var rules = BattleRules.new(
    BattleRules.BattleTypes.WILD,
    BattleRules.BattleModes.SINGLE
)

# Iniciar combate
SignalManager.battle_requested.emit([player_participant, wild_participant], rules)
```

### Iniciar Combate contra Entrenador

```gdscript
# Obtener Battler del jugador y del NPC
var player_battler = player.get_node("Battler")
var npc_battler = npc.get_node("Battler")

# Verificar que ambos puedan pelear
if not player_battler.can_battle():
    push_error("¡El jugador no tiene Pokémon vivos!")
    return

if not npc_battler.can_battle():
    push_warning("El entrenador ya fue derrotado")
    return

# Crear participantes
var player_participant = player_battler.to_battle_participant()
var trainer_participant = npc_battler.to_battle_participant()

# Crear reglas
var rules = BattleRules.new(
    BattleRules.BattleTypes.TRAINER,
    BattleRules.BattleModes.SINGLE
)

# Iniciar combate
SignalManager.battle_requested.emit([player_participant, trainer_participant], rules)
```

### Gestión Dinámica del Equipo

```gdscript
var battler = player.get_node("Battler")

# Agregar Pokémon
var new_pokemon = PokemonInstance.new().create(true, 150, 50)  # Mewtwo Lv50
battler.add_pokemon_to_party(new_pokemon)

# Eliminar Pokémon
var pokemon_to_remove = battler.party[0]
battler.remove_pokemon_from_party(pokemon_to_remove)

# Verificar si tiene un Pokémon
if battler.has_pokemon(some_pokemon):
    print("El entrenador tiene este Pokémon")

# Obtener info
print("Equipo: %d Pokémon, %d vivos" % [
    battler.get_party_size(),
    battler.get_alive_pokemon_count()
])

# Debug
battler.print_party_info()
```

---

## 🎮 Configuración del Player para Encuentros Salvajes

El `WildEncounterDetector` busca automáticamente el `Battler` del Player:

### Setup Recomendado

```
Player (Node2D)
├── GridMotion
├── Occupancy
├── WildEncounterDetector
└── Battler ← El detector usa esto automáticamente
    party_resources: [...]
```

**El detector hace:**
1. Busca `player.get_node("Battler")`
2. Si existe → usa `battler.to_battle_participant()`
3. Si no existe → usa `GameStateManager.get_player_party()` (fallback)

---

## 📊 Propiedades Exportadas

### Trainer Info
- `trainer_id`: ID único del entrenador
- `trainer_name`: Nombre que aparece en combate
- `is_player`: ¿Es el jugador? (true/false)

### Battle Settings
- `battler_type`: TRAINER, WILD_POKEMON, etc.
- `battle_ia`: BattleIA para NPCs (null para jugador)
- `allow_double_battle`: Permite batallas dobles

### Sprites
- `battle_front_sprite`: Sprite del frente (rival)
- `battle_back_sprite`: Sprite de espalda (jugador)

### Messages
- `before_battle_message`: Mensaje antes del combate
- `init_battle_message`: Mensaje al iniciar
- `end_battle_message`: Mensaje al terminar

### State
- `is_defeated`: ¿Ya fue derrotado?

### Partner
- `partner_path`: NodePath al partner (batallas dobles)

### Equipo
- `party_resources`: **Array[PokemonInstance]** - Equipo (resources)

---

## 🔧 Métodos Principales

### to_battle_participant() → BattleParticipant
Convierte el Battler en un BattleParticipant para combate

### add_pokemon_to_party(pokemon: PokemonInstance)
Agrega un Pokémon al equipo

### remove_pokemon_from_party(pokemon: PokemonInstance)
Elimina un Pokémon del equipo

### can_battle() → bool
Retorna true si tiene al menos 1 Pokémon vivo

### get_party_size() → int
Retorna el número total de Pokémon

### get_alive_pokemon_count() → int
Retorna el número de Pokémon no debilitados

### print_party_info()
Imprime información del equipo (debug)

---

## 🆚 Comparación: Antiguo vs Nuevo

| Aspecto | Antiguo | Nuevo (Mejorado) |
|---------|---------|------------------|
| **Configuración** | Nodos hijos | ✅ Nodos hijos (igual) |
| **Inicialización** | Manual en _ready | ✅ Automática |
| **Validación** | Sin validar | ✅ `can_battle()`, etc. |
| **Conversión** | Manual | ✅ `to_battle_participant()` |
| **Métodos útiles** | Básico | ✅ add/remove, counts |
| **Debug** | Limitado | ✅ `print_party_info()` |
| **Grupos en UI** | Mezclado | ✅ Organizado por grupos |

**Mejoras principales:**
- ✅ Código más limpio y organizado
- ✅ Métodos de utilidad (add/remove/count)
- ✅ Mejor organización en el Inspector
- ✅ Validaciones automáticas
- ✅ Preparado para futuro con Resources

---

## 📝 Ejemplo Completo: NPC Trainer

### Paso 1: Crear la escena del NPC

```
NPC_Brock (Node2D)
├── GridMotion
├── AnimatedSprite2D
└── Battler  ← Instanciar TrainerBattler.tscn aquí
```

### Paso 2: Agregar Pokémon como nodos hijos

Con el nodo `Battler` seleccionado:
- Click derecho → "Add Child Node" → `PokemonInstance`
- Agrega dos nodos PokemonInstance
- Renombra y configura cada uno:

```
NPC_Brock/
└── Battler
    ├── Geodude (PokemonInstance)
    │   pkm_id: 74 (Geodude)
    │   level: 12
    │   
    └── Onix (PokemonInstance)
        pkm_id: 95 (Onix)
        level: 14
```

### Paso 3: Configurar el Battler en el Inspector

Selecciona el nodo `Battler` y configura:

```gdscript
[Trainer Info]
trainer_id: 42
trainer_name: "Brock"
is_player: false  # (ya configurado)

[Battle Settings]
battler_type: TRAINER
battle_ia: res://Battle/IAs/BattleIA_Trainer.tres

[Sprites]
battle_front_sprite: res://Sprites/Trainers/brock.png

[Messages]
before_battle_message: "¡Soy el líder de gimnasio de Ciudad Plateada!"
init_battle_message: "¡Vamos!"
end_battle_message: "Has ganado... Aquí tienes la Medalla Roca."
```

**Nota:** NO necesitas configurar `party_resources`, los Pokémon se cargan automáticamente desde los nodos hijos.

### Paso 4: Script de interacción del NPC

Cuando el jugador interactúa:
```gdscript
func _on_player_interact():
    var npc_battler = $Battler
    
    if npc_battler.is_defeated:
        show_message(npc_battler.end_battle_message)
        return
    
    show_message(npc_battler.before_battle_message)
    await message_finished
    
    start_trainer_battle(npc_battler)
```

---

## 🔄 Migración desde Sistema Antiguo

### Si ya tienes Battler con nodos hijos:

**No hay cambios necesarios**. El nuevo sistema es compatible:
- Si `party_resources` está vacío → usa nodos hijos (automático)
- Si `party_resources` tiene datos → usa resources (prioridad)

### Para migrar gradualmente:

1. **Mantén los nodos hijos** (funcional)
2. **Crea resources** de los mismos Pokémon
3. **Asigna al array** `party_resources`
4. **Elimina nodos hijos** cuando todo funcione

---

## ⚠️ Troubleshooting

### "Battler no tiene Pokémon"
✅ Verifica que `party_resources` tenga resources válidos  
✅ O que tenga nodos `PokemonInstance` hijos  
✅ Llama a `battler.print_party_info()` para debug  

### "No se puede iniciar combate"
✅ Verifica con `battler.can_battle()` que tenga Pokémon vivos  
✅ Asegúrate de llamar `to_battle_participant()`  

### "WildEncounterDetector no encuentra al jugador"
✅ El Player debe tener un nodo hijo llamado `"Battler"`  
✅ O configura `GameStateManager.get_player_party()`  

---

## 📚 Ver También

- `PokemonInstance.gd` - Clase de Pokémon individual
- `BattleParticipant.gd` - Participante en combate
- `BattleParticipantWild.gd` - Pokémon salvaje
- `WildEncounterDetector.gd` - Sistema de encuentros
- `TestBattle.gd` - Ejemplos de uso

---

## 🎯 Resumen

**Para el Player:**
```
Player/
└── Battler (is_player: true)
    ├── PokemonInstance (Pikachu)
    ├── PokemonInstance (Charizard)
    └── PokemonInstance (...)
```

**Para NPCs Trainers:**
```
NPC/
└── Battler (is_player: false, battle_ia: ...)
    ├── PokemonInstance (Geodude)
    ├── PokemonInstance (Onix)
    └── PokemonInstance (...)
```

**Para Pokémon Salvajes (encuentros aleatorios):**
```gdscript
# No necesitan Battler, se crean dinámicamente en WildEncounterDetector
var wild = PokemonInstance.new().create(true, pokemon_id, level)
var participant = BattleParticipantWild.new([wild.to_battle_pokemon()])
```

## ✅ Configuración Completa

1. ✅ **Battler.tscn** - Escena base genérica
2. ✅ **PlayerBattler.tscn** - Para Player (preconfigurado)
3. ✅ **TrainerBattler.tscn** - Para NPCs (preconfigurado)
4. ✅ Sistema de nodos hijos funcional
5. ✅ Integración con WildEncounterDetector
6. ✅ Compatible con sistema antiguo

¡El sistema está listo para usar! 🚀

