#!/bin/bash

# Adds the Ctrl+Z -> Ctrl+_ remap to every installed terminal config that
# doesn't already bind Ctrl+Z. Safe to run repeatedly: a config that already
# has the guard block (or any Ctrl+Z binding of the user's own) is left alone.
# Only appends/inserts lines between the markers below, which Service.qml
# deletes again when the plugin is disabled or removed.

set -uo pipefail

BEGIN="# >>> ctrlz-guard (Omarchy plugin; disable it to remove this block) >>>"
END="# <<< ctrlz-guard <<<"

cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

has_guard() { grep -q '^# >>> ctrlz-guard' "$1"; }

# Appends to the file in place (>>), so a symlinked config stays a symlink.
append_block() {
  local file="$1" body="$2"
  [[ -n $(tail -c1 "$file") ]] && echo >>"$file"
  printf '%s\n%s\n%s\n' "$BEGIN" "$body" "$END" >>"$file"
}

guard_foot() {
  local f="$cfg/foot/foot.ini"
  [[ -f $f ]] && ! has_guard "$f" || return 0
  if grep -qiE '^[^#]*=.*\bcontrol\+z\b' "$f"; then
    echo "foot: Ctrl+Z is already bound in $f, leaving it alone" >&2
    return 0
  fi
  append_block "$f" $'[text-bindings]\n\\x1f=Control+z'
}

guard_kitty() {
  local f="$cfg/kitty/kitty.conf"
  [[ -f $f ]] && ! has_guard "$f" || return 0
  if grep -qiE '^\s*map\s+(ctrl|control)\+z\b' "$f"; then
    echo "kitty: Ctrl+Z is already mapped in $f, leaving it alone" >&2
    return 0
  fi
  append_block "$f" 'map ctrl+z send_text all \x1f'
}

guard_ghostty() {
  local f="$cfg/ghostty/config"
  [[ -f $f ]] && ! has_guard "$f" || return 0
  if grep -qiE '^\s*keybind\s*=\s*(ctrl|control)\+z\s*=' "$f"; then
    echo "ghostty: Ctrl+Z is already bound in $f, leaving it alone" >&2
    return 0
  fi
  append_block "$f" 'keybind = ctrl+z=text:\x1f'
}

# alacritty's keyboard bindings are a single TOML array, so the entry has to go
# inside the existing array rather than in a new section at the end.
guard_alacritty() {
  local f="$cfg/alacritty/alacritty.toml"
  [[ -f $f ]] && ! has_guard "$f" || return 0
  if grep -qiE 'key\s*=\s*"z".*mods\s*=\s*"control"|mods\s*=\s*"control".*key\s*=\s*"z"' "$f"; then
    echo "alacritty: Ctrl+Z is already bound in $f, leaving it alone" >&2
    return 0
  fi

  local entry='{ key = "Z", mods = "Control", chars = "\u001f" },'
  local open='^[[:space:]]*(keyboard\.)?bindings[[:space:]]*=[[:space:]]*\[[[:space:]]*$'

  if grep -qE "$open" "$f"; then
    local out
    # Values go in via ENVIRON, not -v, which would expand the \u001f escape.
    out=$(OPEN="$open" B="$BEGIN" E="$END" ENTRY="$entry" awk '
      { print }
      !done && $0 ~ ENVIRON["OPEN"] { print ENVIRON["B"]; print ENVIRON["ENTRY"]; print ENVIRON["E"]; done = 1 }
    ' "$f") && printf '%s\n' "$out" >"$f"
  elif ! grep -qE '^[[:space:]]*\[keyboard\]|^[[:space:]]*keyboard\.' "$f"; then
    append_block "$f" "[keyboard]"$'\n'"bindings = [ ${entry%,} ]"
  else
    echo "alacritty: couldn't find a multi-line keyboard bindings array in $f to add to, leaving it alone" >&2
  fi
}

guard_foot
guard_alacritty
guard_kitty
guard_ghostty
exit 0
