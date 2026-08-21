# Sistema de IA de Combate

Configura perfiles de IA tipados por tipo de participante (entrenador vs salvaje) y por nivel de dificultad de contenido.

## Jerarquía de clases

```
BattleIA                          # Base + utilidades (evaluate_*, build_random_legal_move_choice)
├── TrainerBattleIA               # Solo trainers (TrainerData.ai_profile)
│   └── BattleIA_TrainerEasy      # Contenido actual
│   └── BattleIA_TrainerMedium    # Planificado
│   └── BattleIA_TrainerHard      # Planificado
└── WildBattleIA                  # Solo salvajes
    └── BattleIA_WildBasic        # Contenido actual (+ roaming futuros)
```

**No existe** un `TrainerBasic` de contenido. El random legal es utilidad de **wild + fallback técnico**, no un nivel de dificultad de diseñador.

Debug (no contenido): `BattleIA_MoveFailTest` (`extends WildBattleIA`) en `Scripts/Battle/debug/`.

---

## Contrato de dificultad

| | **WildBasic** | **TrainerEasy** | **TrainerMedium** (futuro) | **TrainerHard** (futuro) |
|---|---|---|---|---|
| **Movimientos** | Random legal | Mejor efectividad de tipo; evita 0x/inmunidades si hay alternativa | Easy + peso simple por daño/HP/status | Medium + field/clima + timing |
| **Items** | No | No | Curas básicas | Uso más óptimo |
| **Switch voluntario** | No | No | Si el matchup es claramente malo | Anti-setup / pivot |
| **Forced switch** | N/A (típicamente 1 mon) | Primer bench vivo | Preferir bench con tipo favorable | Matchup + riesgos |
| **Factores** | Ninguno | Solo tipos | Stats/status básicos | Field + predicción ligera |
| **Flags** | `use_items=false`, `can_switch_strategically=false` | Igual | `use_items` / `can_switch_strategically` = true según diseño | Igual o más agresivo |

### Frontera Easy → Medium → Hard

- **Easy** = “¿qué golpe tipado es mejor ahora?” Miopía de un turno. Por encima del random puro (wild/fallback), por debajo de Medium.
- **Medium** añade: peso por daño/HP/status, **items curativos básicos**, **switch voluntario** ante mal matchup, forced switch con preferencia tipada.
- **Hard** añade: field/clima, timing, items más óptimos, switch anti-setup/pivot, forced switch con riesgos, predicción ligera.

Items y switch voluntario **empiezan en Medium**. Easy no debe absorber esas features.

### Flags en `BattleIA`

- `use_items` — contrato **Medium+**. Easy/WildBasic lo dejan en `false`.
- `can_switch_strategically` — contrato **Medium+** (switch voluntario). Easy/WildBasic en `false`.
- Forced switch por KO es independiente: Easy usa el primer bench vivo sin evaluar matchup.

---

## Clases actuales

### `BattleIA` (base)

- `decide_action(pokemon) -> BattleChoice`
- `decide_forced_switch(...)` / `build_first_available_forced_switch(...)`
- `build_random_legal_move_choice(...)` — movimiento legal aleatorio con `targets` vía `BattleTargetSelector` (nunca `target_handler`)
- `evaluate_best_move_target_combination(...)` — ranking por efectividad de tipos

### `TrainerBattleIA` / `WildBattleIA`

Sub-bases tipadas. `resolve(ai, context)` aplica fallback si la IA es incompatible o null:

- Trainer → `BattleIA_TrainerEasy` (+ `push_warning` si el tipo era inválido)
- Wild → `BattleIA_WildBasic`

### `BattleIA_WildBasic`

- Random legal vía helper
- Sin items / sin switch
- Uso: `BattleParticipantWild` (por defecto)

### `BattleIA_TrainerEasy`

- Mejor combinación (movimiento, objetivo) por efectividad
- Si hay alguna combinación > 0, no elige ≤ 0; si todas son ≤ 0 → helper random
- Empates entre máximos al azar
- Forced switch = primer bench vivo
- Uso: trainers de contenido (suelo de dificultad)

---

## Cómo asignar IA (cableado real)

### Datos de entrenador (preferido)

1. En el resource `TrainerData`, campo tipado **`ai_profile: TrainerBattleIA`**.
2. Si `ai_profile == null`, `Battler` usa `TrainerClassData.default_ai` (también `TrainerBattleIA`).
3. En runtime, `Battler.to_battle_participant()` llama a `set_ai_controller`, que valida el tipo.

El inspector de `TrainerData` solo permite perfiles trainer (no wild).

### Salvajes

`BattleParticipantWild` asigna `BattleIA_WildBasic` automáticamente. No hace falta `TrainerData`.

### Código / tests

```gdscript
# Trainer
var participant := BattleParticipant.new()
participant.is_trainer = true
participant.set_ai_controller(BattleIA_TrainerEasy.new(), "TestTrainer")

# Wild
var wild := BattleParticipantWild.new([battle_pokemon])
# o override tipado wild:
wild.set_ai_controller(BattleIA_WildBasic.new(), "wild")
```

Evitar asignar una IA wild a un trainer (o al revés): el runtime hace fallback + warning, no rompe el combate.

---

## Flujo de integración

```
BattleTurnController.select_actions()
    → BattleParticipant.decide_action_for(pokemon)
        → BattleIA.decide_action(pokemon)
            → BattleChoice (Move / Struggle / Pass / Switch forzado)
```

Cada Pokémon recibe una **copia** (`duplicate`) de la IA del participante al asignarse.

---

## Notas técnicas

- Las IAs son `Resource` (`class_name`); se pueden embeber en `.tres` de trainers.
- Toda `BattleMoveChoice` de las IAs tipadas debe rellenar `targets` con `BattleTargetSelector` (compatible con `BattleMoveChoice.resolve()`).
- No hay “TrainerBasic” de diseñador: null / IA inválida → Easy o WildBasic según el participante.
- Acceptance histórico PBI #132 (IA elige acción, turno progresa) sigue vigente; tipado = PBI #705; Easy endurecido = PBI #342; este contrato = PBI #343.
