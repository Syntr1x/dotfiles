#!/bin/bash
# add-theme.sh — add a theme to themeselector without touching live files
# Source:  ~/.config/hypr/themeselector/shell.qml  (live)
#          ~/.config/hypr/themeselector/apply.sh   (live)
# Target:  ~/.config/hypr/themeselector/theme_preview  (preview/copy, review before copying back)
# Usage:   ./add-theme.sh   (interactive)   or   ./add-theme.sh --help
set -euo pipefail

SRC_DIR="$HOME/.config/hypr/themeselector"
DST_DIR="$HOME/.config/hypr/themeselector/theme_preview"

# allow custom dirs: ./add-theme.sh /path/to/src /path/to/dst
if [[ $# -ge 1 && "$1" != "--help" && "$1" != "-h" ]]; then SRC_DIR="$1"; fi
if [[ $# -ge 2 ]]; then DST_DIR="$2"; fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./add-theme.sh [SRC_DIR] [DST_DIR]
  Default: SRC="$HOME/.config/hypr/themeselector"
           DST="$HOME/.config/hypr/themeselector/theme_preview"

Adds ONE theme to the quickshell selector by editing COPIES in theme_preview,
so live files stay untouched until you review.

Prompts for (in order):
  1. Ghostty theme     e.g. syn-beige (must exist in /usr/share/ghostty/themes/syn-beige and manually add the option to ghostty conf)
  2. Display name      e.g. Beige
  3. Wallpaper file    e.g. Flowers.png  (must exist in ~/.config/hypr/Wallpapers or /usr/share/sddm/themes/silent/backgrounds)
  4. Rofi theme        e.g. rounded-beige.rasi  (must exist in /usr/share/rofi/themes/rounded-beige.rasi)
  5. Waybar color      e.g. #d8c8b3

Copies live -> theme_preview, edits preview only, shows diff and test command.
Then manually:  cp ~/.config/hypr/themeselector/theme_preview/{shell.qml,apply.sh} ~/.config/hypr/themeselector/
EOF
  exit 0
fi

# --- sanity ---
if [[ ! -f "$SRC_DIR/shell.qml" || ! -f "$SRC_DIR/apply.sh" ]]; then
  echo "ERROR: SRC_DIR missing shell.qml/apply.sh: $SRC_DIR" >&2
  exit 1
fi
mkdir -p "$DST_DIR"

# show current count
echo "=== Current themes ($SRC_DIR) ==="
grep -E 'property var themes:' "$SRC_DIR/shell.qml" | sed 's/.*property var themes: //'
echo ""
# alternative: count via python
count=$(python3 -c "import re; t=open('$SRC_DIR/shell.qml').read(); m=re.search(r'property var themes:\s*\[([^\]]*)\]', t, re.S); print(len([x for x in re.findall(r'\"([^\"]+)\"', m.group(1)) if x]))" 2>/dev/null || echo "?")
echo "Count: $count themes"
echo ""

# --- helpers ---
ask() {
  local prompt="$1" varname="$2" default="${3:-}"
  local val=""
  while true; do
    if [[ -n "$default" ]]; then
      read -rp "$prompt [$default]: " val
      val="${val:-$default}"
    else
      read -rp "$prompt: " val
    fi
    val="$(echo "$val" | xargs)" # trim
    if [[ -z "$val" ]]; then
      echo "  -> cannot be empty, try again"
      continue
    fi
    printf -v "$varname" '%s' "$val"
    break
  done
}

# --- interactive prompts ---
ask "Ghostty theme (e.g. syn-beige, IC_Orange_PPL)" ghostty
ask "Display name (e.g. Beige, MyTheme)" display_name
ask "Wallpaper filename (e.g. Flowers.png) — must be in ~/.config/hypr/Wallpapers" wallpaper
ask "Rofi theme (e.g. rounded-beige.rasi or /usr/share/rofi/themes/rounded-beige.rasi)" rofi
ask "Waybar border color hex (e.g. #d8c8b3)" color

# normalize rofi: accept short or full, store preview of both forms
# detect existing style in live files to keep consistent
if grep -q '"/usr/share/rofi/themes/' "$SRC_DIR/shell.qml"; then
  # shell.qml uses full paths
  if [[ "$rofi" != /* ]]; then rofi_full="/usr/share/rofi/themes/$rofi"; else rofi_full="$rofi"; fi
  rofi_qml="$rofi_full"
else
  # shell.qml uses short names (live after fix)
  rofi_full="/usr/share/rofi/themes/$(basename "$rofi")"
  rofi_qml="$(basename "$rofi")"
  # apply.sh lives with short names after fix, but we still want full for rofi config?
  # live apply.sh now uses short names + writes "@theme \"short\"" — keep short for apply.sh too for consistency
  # if you prefer full path in apply.sh, set rofi_sh="$rofi_full" instead
  rofi_sh="$(basename "$rofi")"
fi
# For apply.sh, decide based on its current content
if grep -q '"/usr/share/rofi/themes/' "$SRC_DIR/apply.sh"; then
  rofi_sh="$rofi_full"
else
  rofi_sh="$(basename "$rofi")"
fi

# validation
if [[ ! "$color" =~ ^#[0-9a-fA-F]{6}$ ]]; then
  echo "WARN: color '$color' doesn't look like #rrggbb — continuing anyway" >&2
fi
WALL_DIR="$HOME/.config/hypr/Wallpapers"
if [[ ! -f "$WALL_DIR/$wallpaper" && ! -f "/usr/share/sddm/themes/silent/backgrounds/$wallpaper" ]]; then
  echo "WARN: wallpaper '$wallpaper' not found in $WALL_DIR nor /usr/share/sddm/themes/silent/backgrounds — continuing anyway (preview will show placeholder)" >&2
fi
if [[ ! -f "/usr/share/rofi/themes/$(basename "$rofi")" && ! -f "$rofi_full" ]]; then
  echo "WARN: rofi theme '$(basename "$rofi")' not found in /usr/share/rofi/themes — continuing anyway" >&2
fi
if grep -q "\"$ghostty\"" "$SRC_DIR/shell.qml"; then
  echo "WARN: ghostty theme '$ghostty' already exists — will add duplicate" >&2
fi

echo ""
echo "=== New theme ==="
echo "  ghostty : $ghostty"
echo "  name    : $display_name"
echo "  wallpaper: $wallpaper"
echo "  rofi qml : $rofi_qml"
echo "  rofi sh  : $rofi_sh"
echo "  color   : $color"
echo ""
read -rp "Continue? [Y/n]: " cont
if [[ "$cont" =~ ^[nN] ]]; then echo "Aborted."; exit 0; fi

# --- copy live -> theme_preview (staging) ---
echo "Copying $SRC_DIR -> $DST_DIR ..."
mkdir -p "$DST_DIR"
cp -f "$SRC_DIR/shell.qml" "$DST_DIR/shell.qml"
cp -f "$SRC_DIR/apply.sh" "$DST_DIR/apply.sh"
chmod +x "$DST_DIR/apply.sh" 2>/dev/null || true

# preview is one level deeper than live, fix wallpaperDir relative depth
# live: Quickshell.shellPath("../Wallpapers")  -> hypr/Wallpapers
# preview: "../Wallpapers" -> themeselector/Wallpapers (wrong) => need "../../Wallpapers"
if [[ "$DST_DIR" == *"theme_preview"* ]]; then
  if grep -q 'Quickshell.shellPath("../Wallpapers")' "$DST_DIR/shell.qml"; then
    sed -i 's|Quickshell.shellPath("../Wallpapers")|Quickshell.shellPath("../../Wallpapers")|' "$DST_DIR/shell.qml"
  fi
fi

echo "Editing copies in $DST_DIR (live untouched)..."

# --- edit with python (robust, keeps formatting simple) ---
python3 - "$DST_DIR/shell.qml" "$DST_DIR/apply.sh" "$ghostty" "$display_name" "$wallpaper" "$rofi_qml" "$rofi_sh" "$color" <<'PY'
import re, sys, pathlib
qml_path, sh_path, ghostty, display_name, wallpaper, rofi_qml, rofi_sh, color = sys.argv[1:9]

def add_qml_array(path, var_name, new_val, quoted=True):
    text = pathlib.Path(path).read_text()
    # match property var <var_name>: [ ... ]  (DOTALL, non-greedy)
    pat = re.compile(rf'(property\s+var\s+{re.escape(var_name)}\s*:\s*\[)(.*?)(\])', re.S)
    m = pat.search(text)
    if not m:
        print(f"WARN: {var_name} not found in {path}", file=sys.stderr)
        return
    inner = m.group(2)
    # decide separator: if inner stripped empty -> no comma else comma
    inner_stripped = inner.strip()
    val = f'"{new_val}"' if quoted else new_val
    if inner_stripped == "":
        new_inner = val
    else:
        # ensure trailing comma handling: add comma + space
        new_inner = inner.rstrip() + f',"{new_val}"' if quoted else inner.rstrip() + f',{new_val}'
        # Special handling for rofiThemes multiline: keep newline + indent
        if var_name == "rofiThemes" and "\n" in inner:
            # find indent of last entry line
            lines = inner.splitlines()
            indent = "        "  # default from file
            # try to detect indent from last non-empty line
            for line in reversed(lines):
                if '"' in line:
                    indent = line[:len(line)-len(line.lstrip())]
                    break
            # append with newline
            new_inner = inner.rstrip()
            if new_inner.endswith(","):
                new_inner = new_inner
            else:
                new_inner = new_inner
            # if already has content, add comma if missing
            if not new_inner.rstrip().endswith(","):
                new_inner = new_inner.rstrip() + ","
            new_inner = new_inner + f'\n{indent}"{new_val}"'
            # fix double quotes if quoted path handling already done
            if val.startswith('"') and new_inner.endswith(f'"{new_val}"'):
                pass
        # For themes etc single line, the above simple comma append is fine
        # But we did double handling for rofiThemes; need to avoid duplicate comma logic
        # For non-rofi, use simple
        if var_name != "rofiThemes":
            # we already did, but rofi branch overrides
            pass
        else:
            # rofi already handled, keep as is
            # reformat to avoid duplicate entry: if we used generic path, new_inner already has rofi addition
            # ensure not duplicating generic comma
            if '",\"' in new_inner:
                # generic path already added, remove duplicate?
                pass
    # If generic path for non-rofi, inner already updated above; for rofi we have new_inner
    if var_name == "rofiThemes":
        # new_inner is already correct from branch
        pass
    else:
        # for others, new_inner is simple
        if inner_stripped != "":
            # check if we already have generic handling (non-rofi)
            # new_inner currently is inner.rstrip() + ',"val"'  — ok
            pass
    # Actually recompute correctly for each var to avoid confusion: redo cleanly
    # Re-read logic cleanly per var
    pass

# Simpler: redo with clean functions per var
import pathlib, re, sys
qml = pathlib.Path(qml_path).read_text()

def append_qml_list(qml_text, var, value):
    # value already quoted if needed
    # handle both single-line and multiline arrays
    pat = re.compile(rf'(property\s+var\s+{re.escape(var)}\s*:\s*\[)(.*?)(\])', re.S)
    def repl(m):
        head, inner, tail = m.group(1), m.group(2), m.group(3)
        # detect if inner contains newline -> multiline (rofiThemes)
        if "\n" in inner and var == "rofiThemes":
            # multiline: append on new line with indent
            indent = "        "
            # find indent from existing entries
            for line in reversed(inner.splitlines()):
                if '"' in line:
                    indent = line[:len(line)-len(line.lstrip())]
                    break
            inner_new = inner.rstrip()
            if inner_new and not inner_new.rstrip().endswith(","):
                inner_new += ","
            inner_new += f'\n{indent}"{value}"'
            return head + inner_new + tail
        else:
            inner_stripped = inner.strip()
            if inner_stripped == "":
                return head + f'"{value}"' + tail
            else:
                # single line: add , "value"
                return head + inner.rstrip() + f',"{value}"' + tail
    new, n = pat.subn(repl, qml_text, count=1)
    if n == 0:
        print(f"WARN: var {var} not found", file=sys.stderr)
    return new

qml = append_qml_list(qml, "themes", ghostty)
qml = append_qml_list(qml, "themeNames", display_name)
qml = append_qml_list(qml, "wallpapers", wallpaper)
qml = append_qml_list(qml, "rofiThemes", rofi_qml)
qml = append_qml_list(qml, "waybarColors", color)

# also make Repeater dynamic if it's hardcoded 12
# replace Repeater { model: 12 } or model: 11 etc with model: root.themes.length
qml = re.sub(r'Repeater\s*\{\s*model:\s*\d+', 'Repeater {\n                        model: root.themes.length', qml)
# fallback: if no root.themes.length, at least bump number
if 'root.themes.length' not in qml:
    # count themes now
    m = re.search(r'property var themes:\s*\[([^\]]*)\]', qml, re.S)
    if m:
        cnt = len(re.findall(r'"([^"]+)"', m.group(1)))
        qml = re.sub(r'(Repeater\s*\{\s*model:\s*)\d+', rf'\g<1>{cnt}', qml)

pathlib.Path(qml_path).write_text(qml)
print(f"Edited {qml_path}")

# --- edit apply.sh ---
sh = pathlib.Path(sh_path).read_text()

def append_sh_array(text, var, value):
    # robust: handles ) inside quotes like "Purple(darkmode)"
    # find var assignment manually to avoid regex ) inside strings
    needle = f"{var}="
    idx = text.find(needle)
    if idx == -1:
        print(f"WARN: sh var {var} not found", file=sys.stderr)
        return text
    # find opening '(' after needle
    p1 = text.find("(", idx)
    if p1 == -1:
        print(f"WARN: sh var {var} '(' not found", file=sys.stderr)
        return text
    # scan for matching ')' respecting double quotes
    depth = 0
    in_dq = False
    esc = False
    p2 = -1
    for i in range(p1, len(text)):
        c = text[i]
        if esc:
            esc = False
            continue
        if c == "\\":
            esc = True
            continue
        if c == '"' and not esc:
            in_dq = not in_dq
            continue
        if in_dq:
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                p2 = i
                break
    if p2 == -1:
        print(f"WARN: sh var {var} closing ')' not found", file=sys.stderr)
        return text
    head = text[:p1+1]  # includes '('
    inner = text[p1+1:p2]
    tail = text[p2:]    # includes ')'
    # decide multiline vs single line
    if "\n" in inner:
        lines = inner.splitlines()
        indent = "  "
        for line in reversed(lines):
            if '"' in line:
                indent = line[:len(line)-len(line.lstrip())]
                break
        inner_new = inner.rstrip() + f'\n{indent}"{value}"'
        return text[:p1+1] + inner_new + text[p2:]
    else:
        inner_stripped = inner.strip()
        if inner_stripped == "":
            inner_new = f'"{value}"'
        else:
            inner_new = inner.rstrip() + f' "{value}"'
        return text[:p1+1] + inner_new + text[p2:]

sh = append_sh_array(sh, "themes", ghostty)
sh = append_sh_array(sh, "theme_names", display_name)
sh = append_sh_array(sh, "wallpapers", wallpaper)
sh = append_sh_array(sh, "rofi_themes", rofi_sh)
sh = append_sh_array(sh, "waybar_colors", color)

# update Usage comment 0-11 -> 0-N
m = re.search(r'property var themes:\s*\[([^\]]*)\]', pathlib.Path(qml_path).read_text(), re.S)
if m:
    cnt = len(re.findall(r'"([^"]+)"', m.group(1)))
    sh = re.sub(r'(Usage: apply\.sh <index )0-11', rf'\g<1>0-{cnt-1}', sh)
    sh = re.sub(r'idx required 0-11', f'idx required 0-{cnt-1}', sh)

pathlib.Path(sh_path).write_text(sh)
print(f"Edited {sh_path} count {cnt}")

PY

echo ""
echo "=== Diff preview (Live vs Preview) ==="
# for preview, revert wallpaperDir depth for diff readability (optional)
if command -v diff &>/dev/null; then
  echo "--- shell.qml ---"
  diff -u --color=always "$SRC_DIR/shell.qml" "$DST_DIR/shell.qml" | head -n 160 || true
  echo ""
  echo "--- apply.sh ---"
  diff -u --color=always "$SRC_DIR/apply.sh" "$DST_DIR/apply.sh" | head -n 160 || true
else
  diff -u "$SRC_DIR/shell.qml" "$DST_DIR/shell.qml" | head -n 160 || true
fi

# preview uses ../../Wallpapers, live uses ../Wallpapers

echo ""
echo "=== Done ==="
echo "Staging dir: $DST_DIR (edited copies)"
echo "Live dir:    $SRC_DIR (untouched)"
echo ""
echo "Test with:"
echo "  quickshell -p \"$DST_DIR\""
echo "  # or"
echo "  qs -p \"$DST_DIR\"   # if qs alias"
echo ""
echo "If preview looks good, copy back (auto-fixes wallpaperDir depth):"
echo "  cp \"$DST_DIR/shell.qml\" \"$DST_DIR/apply.sh\" \"$SRC_DIR/\""
echo "  sed -i 's|Quickshell.shellPath(\"../../Wallpapers\")|Quickshell.shellPath(\"../Wallpapers\")|' \"$SRC_DIR/shell.qml\""
echo "  chmod +x \"$SRC_DIR/apply.sh\""
echo ""
echo "New theme index will be $count (0-based, $((count+1)) total)"
