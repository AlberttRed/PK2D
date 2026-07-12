#!/usr/bin/env python3
"""Migra ailment_entries en MoveData .tres sin Godot (paridad con MigrateMoveAilmentEntriesCore)."""

from __future__ import annotations

import re
import sys
from pathlib import Path

MOVES_DIR = Path(__file__).resolve().parents[2] / "Resources/Data/Moves"
ENTRY_SCRIPT = "res://Scripts/Resources/Classes/MoveAilmentEntry.gd"
ENTRY_SCRIPT_UID = "uid://blt82k8rhh5uu"
AILMENT_CATEGORY = "AilmentMoveCategory.tres"
SWAGGER_CATEGORY = "SwaggerMoveCategory.tres"
FLINCH_AILMENT = "FLINCH.tres"


def parse_ext_resources(text: str) -> dict[str, str]:
    resources: dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(
            r'^\[ext_resource .* path="([^"]+)".* id="([^"]+)"\]', line
        )
        if m:
            resources[m.group(2)] = m.group(1)
    return resources


def parse_int_field(text: str, field: str) -> int:
    m = re.search(rf"^{field} = (\d+)", text, re.MULTILINE)
    return int(m.group(1)) if m else 0


def resolve_chance(text: str, ext_resources: dict[str, str]) -> int:
    meta_chance = parse_int_field(text, "meta_ailment_chance")
    if meta_chance > 0:
        return meta_chance
    flinch_chance = parse_int_field(text, "meta_flinch_chance")
    ailment_path = ""
    m = re.search(r'^ailment = ExtResource\("([^"]+)"\)', text, re.MULTILINE)
    if m:
        ailment_path = ext_resources.get(m.group(1), "")
    if flinch_chance > 0 and ailment_path.endswith(FLINCH_AILMENT):
        return flinch_chance
    effect_chance = parse_int_field(text, "effect_chance")
    cat_path = ""
    m = re.search(r'^category = ExtResource\("([^"]+)"\)', text, re.MULTILINE)
    if m:
        cat_path = ext_resources.get(m.group(1), "")
    if effect_chance > 0 and cat_path.endswith("DamageAilmentMoveCategory.tres"):
        return effect_chance
    if cat_path.endswith(AILMENT_CATEGORY) or cat_path.endswith(SWAGGER_CATEGORY):
        return 100
    return 0


def next_free_id(ext_resources: dict[str, str], base: str = "migrate_entry") -> str:
    candidate = f"2_{base}"
    n = 0
    while candidate in ext_resources:
        n += 1
        candidate = f"2_{base}{n}"
    return candidate


def migrate_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "ailment_entries = Array" in text:
        return False
    if not re.search(r"^ailment = ExtResource", text, re.MULTILINE):
        return False

    ext_resources = parse_ext_resources(text)
    chance = resolve_chance(text, ext_resources)
    if chance <= 0:
        print(f"  SKIP (sin chance): {path.name}")
        return False

    m = re.search(r'^ailment = ExtResource\("([^"]+)"\)', text, re.MULTILINE)
    if not m:
        return False
    ailment_ext_id = m.group(1)

    entry_ext_id = next_free_id(ext_resources)
    if ENTRY_SCRIPT not in ext_resources.values():
        entry_line = (
            f'[ext_resource type="Script" uid="{ENTRY_SCRIPT_UID}" '
            f'path="{ENTRY_SCRIPT}" id="{entry_ext_id}"]\n'
        )
        # Insertar tras el bloque ext_resource existente
        insert_at = text.find("\n\n[resource]")
        if insert_at == -1:
            insert_at = text.find("\n[resource]")
        text = text[:insert_at] + "\n" + entry_line + text[insert_at:]
    else:
        # Reutilizar id existente del script MoveAilmentEntry
        for eid, epath in ext_resources.items():
            if epath == ENTRY_SCRIPT:
                entry_ext_id = eid
                break

    sub_resource = (
        '\n[sub_resource type="Resource" id="Resource_migrated_ailment_entry"]\n'
        f'script = ExtResource("{entry_ext_id}")\n'
        f'ailment = ExtResource("{ailment_ext_id}")\n'
        f"chance = {chance}\n"
    )
    text = text.replace("\n[resource]", sub_resource + "\n[resource]", 1)

    entries_line = (
        f'ailment_entries = Array[ExtResource("{entry_ext_id}")]'
        f'([SubResource("Resource_migrated_ailment_entry")])\n'
    )
    if re.search(r"^ailment_id = ", text, re.MULTILINE):
        text = re.sub(r"^(ailment_id = )", entries_line + r"\1", text, count=1, flags=re.MULTILINE)
    else:
        text = re.sub(
            r"^(ailment = ExtResource\([^\n]+\n)",
            entries_line + r"\1",
            text,
            count=1,
            flags=re.MULTILINE,
        )

    path.write_text(text, encoding="utf-8")
    print(f"  OK: {path.name} (chance={chance})")
    return True


def main() -> int:
    if not MOVES_DIR.is_dir():
        print(f"No existe {MOVES_DIR}", file=sys.stderr)
        return 1
    updated = 0
    skipped = 0
    for path in sorted(MOVES_DIR.glob("*.tres")):
        if migrate_file(path):
            updated += 1
        else:
            skipped += 1
    print(f"[migrate_move_ailment_entries_py] Actualizados: {updated} | Sin cambios: {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
