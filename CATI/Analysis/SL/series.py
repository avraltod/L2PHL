"""Load + validate sl_series.json (flat dotted keys -> nested 'series' tree)."""
import json

class SeriesError(Exception):
    pass

def _unflatten(flat):
    out = {}
    for k, v in flat.items():
        parts = k.split(".")
        cur = out
        for p in parts[:-1]:
            cur = cur.setdefault(p, {})
        cur[parts[-1]] = v
    return out

def load_series(path):
    with open(path, encoding="utf-8") as f:
        return _unflatten(json.load(f))

def indicator_keys(data):
    return sorted(data.get("series", {}).keys())

def validate_series(data):
    series = data.get("series", {})
    if not series:
        raise SeriesError("no series found")
    for name, entry in series.items():
        rounds = entry.get("rounds")
        if not isinstance(rounds, list) or not rounds:
            raise SeriesError(f"{name}: missing/empty rounds")
        n = len(rounds)
        ov = entry.get("overall")
        if not isinstance(ov, list) or len(ov) != n:
            raise SeriesError(f"{name}.overall: length {len(ov) if isinstance(ov,list) else '?'} != {n}")
        for bd_key in [k for k in entry if k.startswith("by_")]:
            for sub, arr in entry[bd_key].items():
                if not isinstance(arr, list) or len(arr) != n:
                    raise SeriesError(f"{name}.{bd_key}.{sub}: length != {n}")
    return data
