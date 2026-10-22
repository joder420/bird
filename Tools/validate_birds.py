#!/usr/bin/env python3
"""Validates Plumage/Resources/birds.json against the Swift models.

Enum values are read straight from the Swift source, so the check stays in sync when
cases are added. Run from the repository root:

    python3 Tools/validate_birds.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT = "\n".join(p.read_text() for p in (ROOT / "Plumage").rglob("*.swift"))
DATA = json.loads((ROOT / "Plumage/Resources/birds.json").read_text())


def swift_enum(name):
    match = re.search(r"enum %s\s*:[^{]*\{(.*?)\n\s*(?:var|func|static|init|///|// MARK|\})" % name, SWIFT, re.S)
    if not match:
        sys.exit(f"Could not find enum {name} in Swift sources")
    cases = set()
    for line in re.findall(r"^\s*case\s+([^\n]+)$", match.group(1), re.M):
        for item in line.split(","):
            item = item.strip()
            if item and re.fullmatch(r"[A-Za-z]\w*", item):
                cases.add(item)
    return cases


ENUMS = {name: swift_enum(name) for name in [
    "BirdGroup", "Region", "Habitat", "Diet", "ConservationStatus", "MigrationPattern", "NestType",
    "EggShapeKind", "EggPattern", "SongStyle", "BeakShape", "CrestStyle", "TailStyle", "WingPattern",
    "BellyPattern", "MarkingKind", "PerchStyle",
]}

HEX = re.compile(r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")
errors = []


def err(bird, msg):
    errors.append(f"{bird.get('id', '?')}: {msg}")


def need(bird, obj, key, kind, optional=False, where=""):
    if key not in obj or obj[key] is None:
        if not optional:
            err(bird, f"missing {where}{key}")
        return None
    value = obj[key]
    if kind == "str" and not isinstance(value, str):
        err(bird, f"{where}{key} should be a string")
    elif kind == "num" and not isinstance(value, (int, float)):
        err(bird, f"{where}{key} should be a number")
    elif kind == "int" and not isinstance(value, int):
        err(bird, f"{where}{key} should be an integer")
    elif kind == "bool" and not isinstance(value, bool):
        err(bird, f"{where}{key} should be a bool")
    elif kind == "span" and not (isinstance(value, list) and len(value) == 2 and all(isinstance(v, (int, float)) for v in value) and value[0] <= value[1]):
        err(bird, f"{where}{key} should be [min, max]")
    elif kind == "color" and not (isinstance(value, str) and HEX.match(value)):
        err(bird, f"{where}{key} should be a #RRGGBB colour")
    elif kind in ENUMS and value not in ENUMS[kind]:
        err(bird, f"{where}{key} '{value}' is not a valid {kind}")
    return value


def enum_list(bird, key, kind):
    values = bird.get(key)
    if not isinstance(values, list) or not values:
        err(bird, f"{key} should be a non-empty list")
        return
    for v in values:
        if v not in ENUMS[kind]:
            err(bird, f"{key} contains invalid {kind} '{v}'")


APPEARANCE_COLORS = {"body", "belly", "head", "neck", "wing", "wingTip", "tail", "beak", "beakTip", "legs", "eye",
                     "crestColor", "crestTip", "accent", "accent2", "wingPatternColor", "bellyPatternColor"}
APPEARANCE_NUMBERS = {"beakLength", "beakAngle", "crestSize", "tailLength", "tailAngle", "plumpness", "bodyLength", "bodyTilt",
                      "neckLength", "neckLean", "neckCurve", "legLength", "headSize", "eyeSize", "headTilt", "wingLength"}
APPEARANCE_ENUMS = {"beakShape": "BeakShape", "crest": "CrestStyle", "tailStyle": "TailStyle", "wingPattern": "WingPattern",
                    "bellyPattern": "BellyPattern", "perch": "PerchStyle"}

ids = set()
for b in DATA:
    for key in ["id", "name", "scientific", "family", "familyCommon", "order", "tagline", "summary", "dietNote", "migrationNote"]:
        need(b, b, key, "str")
    if b.get("id") in ids:
        err(b, "duplicate id")
    ids.add(b.get("id"))
    need(b, b, "group", "BirdGroup")
    need(b, b, "status", "ConservationStatus")
    need(b, b, "migration", "MigrationPattern")
    need(b, b, "population", "str", optional=True)
    enum_list(b, "regions", "Region")
    enum_list(b, "habitats", "Habitat")
    enum_list(b, "diet", "Diet")
    for key in ["lengthCm", "weightG"]:
        need(b, b, key, "span")
    for key in ["wingspanCm", "lifespanYears"]:
        need(b, b, key, "span", optional=True)
    need(b, b, "speedKmh", "num", optional=True)
    need(b, b, "flightless", "bool")
    traits = b.get("traits", {})
    for key in ["flight", "song", "smarts", "stealth", "social"]:
        v = need(b, traits, key, "int", where="traits.")
        if isinstance(v, int) and not 0 <= v <= 10:
            err(b, f"traits.{key} out of range")
    for i, beh in enumerate(b.get("behaviors", [])):
        for key in ["icon", "title", "detail"]:
            need(b, beh, key, "str", where=f"behaviors[{i}].")
    titles = [beh.get("title") for beh in b.get("behaviors", [])]
    if len(titles) != len(set(titles)):
        err(b, "behaviour titles must be unique (they are used as identifiers)")
    call = b.get("call", {})
    need(b, call, "description", "str", where="call.")
    need(b, call, "mnemonic", "str", where="call.")
    song = call.get("song", {})
    need(b, song, "style", "SongStyle", where="call.song.")
    for key in ["pitch", "range", "tempo", "trill", "harshness"]:
        need(b, song, key, "num", where="call.song.")
    for key in ["notes", "phrases"]:
        need(b, song, key, "int", where="call.song.")
    nest = b.get("nest", {})
    need(b, nest, "type", "NestType", where="nest.")
    need(b, nest, "description", "str", where="nest.")
    egg = b.get("egg", {})
    need(b, egg, "shape", "EggShapeKind", where="egg.")
    need(b, egg, "pattern", "EggPattern", where="egg.")
    need(b, egg, "base", "color", where="egg.")
    need(b, egg, "marking", "color", where="egg.")
    need(b, egg, "lengthMm", "num", where="egg.")
    need(b, egg, "widthMm", "num", where="egg.")
    need(b, egg, "clutch", "span", where="egg.")
    need(b, egg, "incubationDays", "span", where="egg.")
    need(b, egg, "description", "str", where="egg.")
    if not isinstance(b.get("facts"), list) or not b["facts"]:
        err(b, "facts should be a non-empty list")
    app = b.get("appearance", {})
    for key, value in app.items():
        if key in APPEARANCE_COLORS:
            need(b, app, key, "color", where="appearance.")
        elif key in APPEARANCE_NUMBERS:
            need(b, app, key, "num", where="appearance.")
        elif key in APPEARANCE_ENUMS:
            need(b, app, key, APPEARANCE_ENUMS[key], where="appearance.")
        elif key == "eyeDark":
            need(b, app, key, "bool", where="appearance.")
        elif key == "markings":
            for m in value:
                need(b, m, "kind", "MarkingKind", where="appearance.markings.")
                need(b, m, "color", "color", where="appearance.markings.")
        else:
            err(b, f"unknown appearance key '{key}'")

if errors:
    print("\n".join(errors))
    sys.exit(f"\n{len(errors)} problem(s) in birds.json")
print(f"birds.json OK — {len(DATA)} species, enums checked against Swift: " + ", ".join(f"{k}({len(v)})" for k, v in ENUMS.items()))
