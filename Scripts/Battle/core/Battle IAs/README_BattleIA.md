# Sistema de IA de Combate

Este sistema permite configurar diferentes niveles de inteligencia artificial para los Pokémon controlados por la IA en combate.

## 📚 Clases Disponibles

### `BattleIA` (Clase Base)
Clase base abstracta que define la interfaz para todas las IAs de combate.

**Método principal:**
- `decide_action(pokemon: BattlePokemon) -> BattleChoice`

**Propiedades configurables desde el editor:**
- `difficulty_name`: Nombre descriptivo de la dificultad
- `use_items`: Si la IA puede usar objetos (futuro)
- `can_switch_strategically`: Si la IA puede cambiar Pokémon estratégicamente (futuro)

---

### `BattleIA_Wild`
IA para Pokémon salvajes.

**Comportamiento:**
- ✅ Elige movimientos completamente al azar
- ❌ No considera efectividad de tipos
- ❌ No usa objetos
- ❌ No cambia de Pokémon

**Uso recomendado:** Pokémon salvajes

---

### `BattleIA_Easy`
IA básica para entrenadores de nivel fácil.

**Comportamiento:**
- ✅ Considera efectividad de tipos al elegir movimientos
- ✅ Calcula el movimiento más efectivo contra los enemigos activos
- ✅ En caso de empate, elige aleatoriamente entre los mejores
- ❌ No considera stats, estado, clima u otros factores
- ❌ No usa objetos
- ❌ No cambia de Pokémon estratégicamente

**Uso recomendado:** Entrenadores novatos, primeras rutas

---

## 🎯 IAs Futuras (Planificadas)

### `BattleIA_Medium` (No implementada)
**Comportamiento previsto:**
- Considera efectividad de tipos
- Evalúa cambios de stats (boosts/drops)
- Puede cambiar Pokémon en situaciones desfavorables
- Usa objetos curativos básicos

### `BattleIA_Hard` (No implementada)
**Comportamiento previsto:**
- Todo lo anterior
- Considera clima, terreno y otras condiciones de campo
- Estrategia avanzada de cambios
- Uso óptimo de objetos
- Predicción básica de movimientos del jugador

---

## 🔧 Cómo Usar

### Opción 1: Desde el Editor de Godot

1. **Crear un Resource de IA:**
   - En el FileSystem, click derecho → "New Resource"
   - Seleccionar `BattleIA_Wild` o `BattleIA_Easy`
   - Guardar el resource (ej: `res://Resources/Battle/wild_ai.tres`)

2. **Asignar al Battler:**
   - Seleccionar el nodo `Battler` del entrenador/salvaje
   - En el Inspector, en la propiedad `Battle IA`
   - Arrastrar el resource creado o usar el selector

### Opción 2: Desde Código

```gdscript
# Crear un Battler con IA Wild
var wild_ia = BattleIA_Wild.new()
var battler = Battler.new().create(
    CONST.BATTLER_TYPES.WILD_POKEMON,
    [pokemon_instance],
    wild_ia  # ← Asignar IA aquí
)

# Crear un Battler con IA Easy
var easy_ia = BattleIA_Easy.new()
var trainer = Battler.new().create(
    CONST.BATTLER_TYPES.TRAINER,
    trainer_team,
    easy_ia  # ← Asignar IA aquí
)

# Convertir a BattleParticipant (la IA se propaga automáticamente)
var participant = battler.to_battle_participant()
```

### Opción 3: Asignar directamente al Participant

```gdscript
var participant = BattleParticipant.new()
participant.ai_controller = BattleIA_Easy.new()
participant.add_pokemon_team(battle_pokemon_array)
# La IA se asignará automáticamente a cada Pokémon
```

---

## 🔄 Flujo de Integración

El sistema se integra automáticamente con el controlador de turnos:

```
BattleTurnController.select_actions()
    ↓ (para cada Pokémon no controlable)
BattleParticipant.decide_action_for(pokemon)
    ↓
BattleIA.decide_action(pokemon)
    ↓
Retorna BattleChoice
    ↓
BattleTurnController ejecuta el choice
```

---

## ✅ Acceptance Criteria (PBI #132)

- [x] La IA siempre elige una acción cuando se le solicita
- [x] El flujo del turno progresa sin intervención del jugador
- [x] Sistema escalable para diferentes niveles de dificultad
- [x] Código limpio y bien documentado
- [x] Integración transparente con BattleTurnController

---

## 📝 Notas Técnicas

- Cada Pokémon recibe una **copia duplicada** de la IA del Participant
- Las IAs son `Resource`, por lo que se pueden guardar y cargar desde archivos
- El método `decide_action()` es **async** (usa `await`) debido a la selección de objetivos
- Si no hay IA asignada, se usa `pokemon.decide_random_action()` como fallback

---

## 🐛 Testing

Para probar las diferentes IAs, modifica el script `TestBattle.gd`:

```gdscript
# Crear un participante con IA Easy en lugar de Wild
var easy_ia = BattleIA_Easy.new()
var trainer_participant = BattleParticipant.new()
trainer_participant.ai_controller = easy_ia
trainer_participant.add_pokemon(pokemon.to_battle_pokemon())
```

