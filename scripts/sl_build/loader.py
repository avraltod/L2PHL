# CATI/Analysis/SL/sl_build/loader.py
"""Accept either nested JSON or Stata's flat dotted-key JSON; return nested."""


def unflatten(data):
    if not any("." in k for k in data):
        return data
    out = {}
    for key, val in data.items():
        parts = key.split(".")
        node = out
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        node[parts[-1]] = val
    return out
