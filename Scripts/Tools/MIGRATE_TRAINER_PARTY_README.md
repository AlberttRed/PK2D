# Migración de TrainerData.party_data a PokemonDefinition

## Descripción

Este script migra los trainers existentes para usar `PokemonDefinition` en lugar de `Pokemon` runtime directamente en `party_data`.

## Cambios realizados

- `TrainerData.party_data` ahora es `Array[PokemonDefinition]` en lugar de `Array[Pokemon]`
- `TrainerData.create_party()` ahora crea `Pokemon` runtime desde las definiciones
- Los métodos `calculate_reward()` y `has_valid_party()` funcionan con las definiciones

## Cómo usar el script de migración

### Opción 1: Migración automática (recomendada)

1. **Hacer backup** de los trainers en `Resources/Trainers/`
2. Abrir el script `Scripts/Tools/MigrateTrainerPartyToDefinitions.gd` en el editor
3. Configurar `dry_run = false` en el script (línea 10)
4. Ejecutar: `Script > Run`
5. Revisar el reporte en `res://Tools/MigrateTrainerParty_report.txt`

### Opción 2: Migración manual

Si prefieres migrar manualmente:

1. Abrir cada `.tres` de trainer en el inspector
2. Para cada `Pokemon` en `party_data`:
   - Crear un nuevo `PokemonDefinition` (New Resource > PokemonDefinition)
   - Copiar los valores del Pokemon al PokemonDefinition:
     - pokemon_id, level, nickname, gender, shiny, is_wild
     - IVs (hp_IVs, attack_IVs, etc.)
     - EVs (hp_EVs, attack_EVs, etc.)
     - nature_id, ability_id
     - custom_move_ids
     - held_item_id
   - Reemplazar el Pokemon con el PokemonDefinition en el array
3. Guardar el trainer

## Campos mapeados

Los siguientes campos se copian de `Pokemon` a `PokemonDefinition`:

- ✅ `pokemon_id` → `pokemon_id`
- ✅ `level` → `level`
- ✅ `nickname` → `nickname`
- ✅ `gender` → `gender`
- ✅ `shiny` → `shiny`
- ✅ `is_wild` → `is_wild`
- ✅ `hp_IVs`, `attack_IVs`, etc. → `hp_IVs`, `attack_IVs`, etc.
- ✅ `hp_EVs`, `attack_EVs`, etc. → `hp_EVs`, `attack_EVs`, etc.
- ✅ `nature_id` → `nature_id`
- ✅ `ability_id` → `ability_id`
- ✅ `custom_move_ids` → `custom_move_ids`
- ✅ `held_item_id` → `held_item_id`

## Campos NO migrados (runtime)

Los siguientes campos NO se migran porque son específicos del runtime:

- ❌ `hp_actual` (se calcula al crear el Pokemon)
- ❌ `totalExp` (se calcula al crear el Pokemon)
- ❌ `movements` (se cargan al crear el Pokemon)
- ❌ `inBattle`, `inBattleParty` (estado de combate)
- ❌ `trainer_id`, `original_trainer` (se asignan en `create_party()`)
- ❌ `capture_date`, `capture_route`, etc. (datos de captura)

## Verificación post-migración

Después de migrar, verificar:

1. ✅ Los trainers se cargan sin errores en el editor
2. ✅ El inspector muestra `party_data` como `Array[PokemonDefinition]`
3. ✅ Se pueden añadir/editar `PokemonDefinition` desde el inspector
4. ✅ `create_party()` crea Pokemon válidos para combate

## Notas

- El cambio de tipo en `@export` puede hacer que Godot pierda las referencias automáticamente
- Si esto ocurre, el script de migración reconstruirá el party desde los datos guardados
- Si un trainer ya está migrado (tiene `PokemonDefinition`), el script lo saltará automáticamente

