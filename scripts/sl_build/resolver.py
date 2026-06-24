# CATI/Analysis/SL/sl_build/resolver.py
"""Resolve a dotted key path into a nested dict."""


class MissingKey(KeyError):
    pass


def resolve(data, dotted):
    node = data
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            raise MissingKey(dotted)
        node = node[part]
    return node
