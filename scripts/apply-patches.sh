#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PATCH_DIR="${PROJECT_DIR}/SOURCES/patches"

SOURCE_DIR="${1:?Usage: apply-patches.sh <inkscape-source-dir>}"

if [[ ! -d "$SOURCE_DIR/src" ]]; then
    echo "ERROR: Invalid Inkscape source directory: $SOURCE_DIR"
    exit 1
fi

if [[ ! -d "$PATCH_DIR" ]]; then
    echo "ERROR: Patch directory not found: $PATCH_DIR"
    exit 1
fi

# Check whether the recent manager is guarded by _with_gui.
# This checks the actual C++ block structure, not just the presence
# of both strings somewhere in the source file.
check_recent_manager_guard() {
    local source_file="$1"

    python3 - "$source_file" <<'PY'
import re
import sys

path = sys.argv[1]

with open(path, encoding="utf-8") as f:
    source = f.read()

# Remove comments and string/character literals to avoid counting
# braces inside them.
pattern = re.compile(
    r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
    re.DOTALL
)
code = pattern.sub(lambda m: '\n' * m.group().count('\n'), source)

guard = re.search(r'\bif\s*\(\s*_with_gui\s*\)\s*\{', code)

if not guard:
    sys.exit(1)

def find_block_end(text, opening_brace):
    depth = 1

    for pos in range(opening_brace + 1, len(text)):
        if text[pos] == '{':
            depth += 1
        elif text[pos] == '}':
            depth -= 1
            if depth == 0:
                return pos

    return None

opening = code.find('{', guard.start())
closing = find_block_end(code, opening)

if closing is None:
    sys.exit(1)

guard_body = code[opening + 1:closing]

if re.search(r'Gtk::RecentManager\s*::\s*get_default\s*\(', guard_body):
    sys.exit(0)

sys.exit(1)
PY
}

shopt -s nullglob
PATCHES=("$PATCH_DIR"/*.patch)

if [[ ${#PATCHES[@]} -eq 0 ]]; then
    echo "No patch files found."
    exit 0
fi

for PATCH_FILE in "${PATCHES[@]}"; do
    PATCH_NAME="$(basename "$PATCH_FILE")"

    echo
    echo "Checking: $PATCH_NAME"

    # 1. Check whether the exact patch is already applied.
    if git -C "$SOURCE_DIR" apply --reverse --check "$PATCH_FILE" \
        >/dev/null 2>&1; then
        echo "Already applied: $PATCH_NAME"
        continue
    fi

    # 2. Check whether the functionality is already implemented.
    case "$PATCH_NAME" in
        0001-guard-gtk-recent-manager-in-headless.patch)
            if check_recent_manager_guard \
                "$SOURCE_DIR/src/inkscape-application.cpp"; then
                echo "Functionality already present: $PATCH_NAME"
                echo "Skipping patch."
                continue
            fi
            ;;
    esac

    # 3. Check whether the patch can be applied.
    if git -C "$SOURCE_DIR" apply --check "$PATCH_FILE" \
        >/dev/null 2>&1; then
        echo "Applying: $PATCH_NAME"
        git -C "$SOURCE_DIR" apply "$PATCH_FILE"
        echo "Successfully applied: $PATCH_NAME"
        continue
    fi

    echo "ERROR: Cannot apply patch: $PATCH_NAME"
    echo "The source may have changed or require manual inspection."
    exit 1
done

echo
echo "Patch processing completed."
