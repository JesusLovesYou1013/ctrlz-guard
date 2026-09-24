#!/bin/bash
# Headless tests for ctrlz-guard.sh and Service.qml's remove command. Runs
# entirely inside a throwaway fake home: HOME and XDG_CONFIG_HOME both point at
# a temp dir, and the script refuses to start if either would reach a real one.

set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
id="io.github.JesusLovesYou1013.ctrlz-guard"
fails=0

fake=$(mktemp -d) || exit 1
trap 'rm -rf "$fake"' EXIT
export HOME="$fake" XDG_CONFIG_HOME="$fake/.config"
[[ $HOME == /tmp/* && $XDG_CONFIG_HOME == /tmp/* ]] || { echo "refusing: not a temp home" >&2; exit 1; }
cfg="$XDG_CONFIG_HOME"

ok()   { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }

# Pull the remove command out of Service.qml exactly as the shell would build it.
remove_cmd=$(python3 - "$here/Service.qml" "$id" <<'PY'
import re, sys, json
src = open(sys.argv[1]).read()
body = re.search(r'removeCommand:\n(.*?)\n\n', src, re.S).group(1)
body = body.replace('pluginId', json.dumps(sys.argv[2]))
print(eval(body.replace('\n', ' ').strip()))  # QML string concatenation == Python here
PY
)
[[ -n $remove_cmd ]] || { echo "could not extract removeCommand" >&2; exit 1; }
apply()  { bash "$here/ctrlz-guard.sh"; }
remove() { bash -c "$remove_cmd"; }
enabled()  { mkdir -p "$cfg/omarchy"; echo "{\"plugins\":[\"$id\"]}" >"$cfg/omarchy/shell.json"; }
disabled() { mkdir -p "$cfg/omarchy"; echo '{"plugins":[]}' >"$cfg/omarchy/shell.json"; }

# Omarchy's stock terminal configs (trimmed to what matters).
mkdir -p "$cfg"/{foot,alacritty,kitty,ghostty}
cat >"$cfg/foot/foot.ini" <<'CFG'
[main]
term=xterm-256color

[text-bindings]
\x1b[13;2u=Shift+Return
CFG
cat >"$cfg/alacritty/alacritty.toml" <<'CFG'
[keyboard]
bindings = [
{ key = "Insert", mods = "Shift", action = "Paste" },
{ key = "Return", mods = "Shift", chars = "\u001B[13;2u" }
]
CFG
printf 'font_size 9.0\n' >"$cfg/kitty/kitty.conf"
printf 'keybind = shift+insert=paste_from_clipboard\n' >"$cfg/ghostty/config"
cp -r "$cfg" "$fake/orig"

enabled; apply; apply
for f in foot/foot.ini alacritty/alacritty.toml kitty/kitty.conf ghostty/config; do
  check "$f gets exactly one guard block (idempotent)" "[[ \$(grep -c '^# >>> ctrlz-guard' '$cfg/$f') == 1 ]]"
done
command -v foot >/dev/null && check "foot accepts the config" "foot --check-config -c '$cfg/foot/foot.ini'"
check "alacritty TOML parses, binding sends 0x1f" \
  "python3 -c \"import tomllib;b=tomllib.load(open('$cfg/alacritty/alacritty.toml','rb'))['keyboard']['bindings'];assert {'key':'Z','mods':'Control','chars':'\x1f'} in b and len(b)==3\""

remove
check "still enabled (shell exit / hot-reload): remove is a no-op" "! diff -rq -x omarchy '$fake/orig' '$cfg' >/dev/null"
disabled; remove
check "disabled: every config restored byte-identical" "diff -r -x omarchy '$fake/orig' '$cfg'"

# A symlinked config (dotfile managers) must stay a symlink.
mv "$cfg/kitty/kitty.conf" "$fake/kitty-real.conf"; ln -s "$fake/kitty-real.conf" "$cfg/kitty/kitty.conf"
enabled; apply; disabled; remove
check "symlinked config stays a symlink" "[[ -L '$cfg/kitty/kitty.conf' ]] && cmp -s '$fake/kitty-real.conf' '$fake/orig/kitty/kitty.conf'"

# The user's own Ctrl+Z binding is respected, never duplicated.
printf '\\x1f=Control+z\n' >>"$cfg/foot/foot.ini"; cp "$cfg/foot/foot.ini" "$fake/own.ini"
enabled; apply 2>/dev/null
check "existing Ctrl+Z binding left alone" "cmp -s '$cfg/foot/foot.ini' '$fake/own.ini'"

# Alacritty with no [keyboard] table gets a fresh one.
printf '[window]\npadding.x = 14\n' >"$cfg/alacritty/alacritty.toml"; apply  2>/dev/null
check "alacritty without [keyboard] gets a valid table" \
  "python3 -c \"import tomllib;assert tomllib.load(open('$cfg/alacritty/alacritty.toml','rb'))['keyboard']['bindings'][0]['chars']=='\x1f'\""

# Terminals that aren't installed get nothing created.
rm -rf "$cfg"/{foot,alacritty,kitty,ghostty}; apply
check "no config files created for missing terminals" "[[ -z \$(ls '$cfg' | grep -v omarchy) ]]"

echo; (( fails == 0 )) && echo "all passed" || echo "$fails failed"
exit $(( fails > 0 ))
