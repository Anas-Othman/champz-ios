#!/usr/bin/env python3
"""Fail when an endpoint the app uses changed in contracts/openapi.yaml.

contracts/used-endpoints.txt lists `METHOD /path/` lines. For each, the operation's
subtree (with $refs resolved) is hashed and compared to contracts/used-endpoints.lock.json.

    python3 scripts/contract_check.py           # verify (CI)
    python3 scripts/contract_check.py --update  # accept the current contract
"""
import hashlib
import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "contracts/openapi.yaml"
USED = ROOT / "contracts/used-endpoints.txt"
LOCK = ROOT / "contracts/used-endpoints.lock.json"


def resolve(node, spec, seen):
    if isinstance(node, dict):
        if "$ref" in node:
            ref = node["$ref"]
            if ref in seen:
                return {"$cycle": ref}
            target = spec
            for part in ref.lstrip("#/").split("/"):
                target = target[part]
            return resolve(target, spec, seen | {ref})
        return {k: resolve(v, spec, seen) for k, v in sorted(node.items())}
    if isinstance(node, list):
        return [resolve(v, spec, seen) for v in node]
    return node


def main(update: bool) -> int:
    spec = yaml.safe_load(SPEC.read_text())
    used = [line.split() for line in USED.read_text().splitlines() if line.strip() and not line.startswith("#")]
    current = {}
    missing = []
    for method, path in used:
        operation = spec.get("paths", {}).get(path, {}).get(method.lower())
        if operation is None:
            missing.append(f"{method} {path}")
            continue
        canonical = json.dumps(resolve(operation, spec, frozenset()), sort_keys=True)
        current[f"{method} {path}"] = hashlib.sha256(canonical.encode()).hexdigest()[:16]

    if missing:
        print("Endpoints missing from the contract:\n  " + "\n  ".join(missing))
        return 1

    if update or not LOCK.exists():
        LOCK.write_text(json.dumps(current, indent=2, sort_keys=True) + "\n")
        print(f"Accepted {len(current)} endpoints → {LOCK.name}")
        return 0

    locked = json.loads(LOCK.read_text())
    changed = [k for k in current if locked.get(k) != current[k]]
    removed = [k for k in locked if k not in current]
    if changed or removed:
        for k in changed:
            print(f"CHANGED  {k}  — review the DTOs and fixtures, then `just contract-accept`")
        for k in removed:
            print(f"UNLISTED {k}  — in the lock but not in used-endpoints.txt")
        return 1
    print(f"Contract unchanged for {len(current)} endpoints")
    return 0


if __name__ == "__main__":
    sys.exit(main("--update" in sys.argv))
