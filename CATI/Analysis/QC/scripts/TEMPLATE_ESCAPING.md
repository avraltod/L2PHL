# gen_dashboard.py Template Escaping Rules

**CRITICAL: Read this before editing MODULE_NOTES or any text in the template.**

## The Problem

`gen_dashboard.py` builds the HTML output by **concatenating multiple Python string segments**:

```python
HTML = r"""<!DOCTYPE html>
...
const DQ   = """ + DQ   + """;
const MT   = """ + MT   + """;
const AQ   = """ + AQ   + """;
const PAN  = """ + PAN  + """;
const IVIEW= """ + IVIEW+ """;
const KOBO = """ + KOBO + """;

// ... rest of JS code including MODULE_NOTES, helper functions, etc ...

</html>"""
```

**Only the FIRST segment has `r` (raw) prefix.** Every `"""` after a data placeholder (`DQ`, `MT`, etc.) starts a **non-raw** Python string.

This means:

| Segment | Type | `\'` becomes | `\\` becomes | `\n` becomes |
|---------|------|-------------|-------------|-------------|
| First (`r"""...const DQ = """`) | **Raw** | `\'` (literal backslash + quote) | `\\` (two backslashes) | `\n` (literal) |
| All others (`"""...const MT = """` etc.) | **Non-raw** | `'` (just a quote — **DANGEROUS**) | `\` (single backslash) | newline character |

## What Broke (April 2025)

The M02 Education MODULE_NOTES item contained:

```
text:'... "-99 if Don\'t know".'
```

In the non-raw segment, Python interpreted `\'` as an escape sequence producing just `'`. The output HTML became:

```javascript
text:'... "-99 if Don't know".'
//                     ^ unescaped quote closes the string!
//                      ^ "t" becomes "Unexpected identifier"
```

This **SyntaxError killed the entire `<script>` block** — no functions defined, no modules in sidebar, dashboard completely broken.

## Rules for Editing Text in the Template

### 1. NEVER use apostrophes in single-quoted JS strings
Bad:  `text:'Don\'t know'`  (Python eats the backslash)
Good: `text:'Do not know'`  (no apostrophe)
Good: `text:"Don't know"`   (use double quotes if the JS context allows it)

### 2. For JS regex patterns, use `\\` for a single backslash
The non-raw segment interprets `\\` as a single `\`. So:
- `\\(` in source becomes `\(` in output (correct JS regex)
- `\\s` in source becomes `\s` in output (correct JS regex)
- `\(` in source becomes `(` in output (**WRONG** — backslash eaten)

### 3. For JS `\n` in strings, use `\\n`
- `\\n` in source becomes `\n` in output (JS newline escape)
- `\n` in source becomes an actual newline character (**breaks JS string**)

### 4. Template literals with `${...}` are fine
Python does not interpret `$` specially, so `${variable}` passes through unchanged.

### 5. Always validate after editing
```bash
# Regenerate
python3 gen_dashboard.py

# Check JS syntax
python3 -c "
with open('../output/l2phl_dq_dashboard.html') as f:
    content = f.read()
start = content.find('<script>\n// ── DATA')
end = content.rfind('</script>')
js = content[start+8:end]
with open('/tmp/test.js', 'w') as f:
    f.write(js)
" && node --check /tmp/test.js
```

If `node --check` prints nothing, the JS is valid. If it prints an error, fix it before committing.

### 6. Quick quote-balance check for MODULE_NOTES
Every item line should have exactly **6 single quotes** (3 pairs for `rounds`, `tag`, `text`):
```bash
# In the output HTML, check MODULE_NOTES items
sed -n '/const MODULE_NOTES/,/^  };/p' ../output/l2phl_dq_dashboard.html | \
  grep "rounds:" | while IFS= read -r line; do
    count=$(echo "$line" | tr -cd "'" | wc -c)
    [ "$count" -ne 6 ] && echo "BAD ($count quotes): $(echo "$line" | head -c 100)"
  done
```

## Where Things Live

| What | File | Persists? |
|------|------|-----------|
| Data pipeline | `build_dq.py` | Yes (produces `dq_data.json`) |
| HTML template + all JS | `gen_dashboard.py` | Yes (source of truth) |
| Output dashboard | `output/l2phl_dq_dashboard.html` | **NO — regenerated, never edit directly** |

**ALL customizations must be in `gen_dashboard.py`.** The output HTML is disposable.
