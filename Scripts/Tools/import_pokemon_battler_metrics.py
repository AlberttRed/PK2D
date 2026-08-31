#!/usr/bin/env python3
"""Import battlerAltitude + shadow_size/shadow_x into Gen1 PokemonData .tres files."""

from __future__ import annotations

import re
from pathlib import Path

POKEMON_DIR = Path("/mnt/qnap_iscsi/PK2D/Resources/Data/Pokemon")
POKEMON_TXT = Path("/home/kerrmind/Godot/Docs Projecte/pokemon.txt")
METRICS_TXT = Path("/home/kerrmind/Godot/Docs Projecte/pokemon_metrics.txt")
START_ID = 1
END_ID = 151
# Essentials multiplica BattlerAltitude ×2 al aplicar; PK2D calibra en import.
ALTITUDE_SCALE = 2

SPECIAL_INTERNAL_TO_PBS = {
    "nidoran-f": "NIDORANfE",
    "nidoran-m": "NIDORANmA",
    "farfetchd": "FARFETCHD",
    "mr-mime": "MRMIME",
}


def internal_to_pbs_key(internal_name: str) -> str:
    key = internal_name.strip().lower()
    if not key:
        return ""
    return SPECIAL_INTERNAL_TO_PBS.get(key, key.upper().replace("-", ""))


def parse_pokemon_txt(path: Path) -> dict[str, int]:
    out: dict[str, int] = {}
    current = ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("InternalName="):
            current = line.split("=", 1)[1].strip()
            out.setdefault(current, 0)
        elif current and line.startswith("BattlerAltitude="):
            out[current] = int(line.split("=", 1)[1].strip())
    return out


def parse_metrics_txt(path: Path) -> dict[str, dict[str, int]]:
    out: dict[str, dict[str, int]] = {}
    current = ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1].strip()
            out[current] = {"shadow_size": 0, "shadow_x": 0}
            continue
        if not current or "=" not in line:
            continue
        field, value = [p.strip() for p in line.split("=", 1)]
        if field == "ShadowSize":
            out[current]["shadow_size"] = int(value)
        elif field == "ShadowX":
            out[current]["shadow_x"] = int(value)
    return out


def resolve_tres(species_id: int) -> Path | None:
    prefix = f"{species_id:03d}"
    matches = sorted(POKEMON_DIR.glob(f"{prefix} - *.tres"))
    return matches[0] if matches else None


def read_internal_name(content: str) -> str:
    m = re.search(r"^internal_name\s*=\s*\"([^\"]+)\"", content, re.MULTILINE)
    return m.group(1) if m else ""


def set_field(content: str, field: str, value: int) -> str:
    line = f"{field} = {value}"
    pattern = rf"^{re.escape(field)}\s*=\s*.*$"
    if re.search(pattern, content, flags=re.MULTILINE):
        return re.sub(pattern, line, content, count=1, flags=re.MULTILINE)
    anchor = "icon_sprite ="
    if anchor in content:
        return content.replace(anchor, f"{line}\n{anchor}", 1)
    return content.rstrip() + "\n" + line + "\n"


def main() -> int:
    bes = parse_pokemon_txt(POKEMON_TXT)
    metrics = parse_metrics_txt(METRICS_TXT)
    updated = errors = skipped = 0
    missing_bes: list[str] = []
    missing_metrics: list[str] = []

    for species_id in range(START_ID, END_ID + 1):
        tres_path = resolve_tres(species_id)
        if tres_path is None:
            print(f"[SKIP] no .tres for id={species_id}")
            skipped += 1
            continue

        content = tres_path.read_text(encoding="utf-8")
        internal = read_internal_name(content)
        pbs_key = internal_to_pbs_key(internal)
        if not pbs_key:
            print(f"[ERROR] empty internal_name in {tres_path.name}")
            errors += 1
            continue

        if pbs_key not in bes:
            missing_bes.append(pbs_key)
        if pbs_key not in metrics:
            missing_metrics.append(pbs_key)

        altitude = bes.get(pbs_key, 0) * ALTITUDE_SCALE
        shadow_size = metrics.get(pbs_key, {}).get("shadow_size", 0)
        shadow_x = metrics.get(pbs_key, {}).get("shadow_x", 0)

        new_content = content
        new_content = set_field(new_content, "battlerAltitude", altitude)
        new_content = set_field(new_content, "shadow_size", shadow_size)
        new_content = set_field(new_content, "shadow_x", shadow_x)

        if new_content != content:
            tres_path.write_text(new_content, encoding="utf-8")
            updated += 1
            print(
                f"[OK] id={species_id:03d} {pbs_key} alt={altitude} shadow={shadow_size} x={shadow_x}"
            )
        else:
            updated += 1

    print("========================================")
    print(f"Fin | actualizados={updated} omitidos={skipped} errores={errors}")
    if missing_bes:
        print(f"sin BES ({len(missing_bes)}): {', '.join(missing_bes)}")
    if missing_metrics:
        print(f"sin metrics ({len(missing_metrics)}): {', '.join(missing_metrics)}")
    print("========================================")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
