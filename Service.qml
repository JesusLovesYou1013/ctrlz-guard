import QtQuick
import Quickshell
import Quickshell.Io

// Background service with no UI. While this plugin is enabled, Ctrl+Z is
// remapped in each installed terminal's config to send Ctrl+_ (undo) instead
// of ^Z, so nothing running in the terminal can be suspended by it.
//
// Every change lives between "# >>> ctrlz-guard" / "# <<< ctrlz-guard" marker
// lines. ctrlz-guard.sh adds the blocks (idempotently) each time the service
// starts; the inline command below deletes them when the plugin is disabled
// or removed.
Item {
  id: root

  readonly property string pluginId: "io.github.JesusLovesYou1013.ctrlz-guard"

  // Local path of this plugin's folder, wherever omarchy-plugin-add put it.
  readonly property string scriptPath:
    decodeURIComponent(Qt.resolvedUrl("ctrlz-guard.sh").toString().replace(/^file:\/\//, ""))

  // Kept inline (not in ctrlz-guard.sh) because `omarchy plugin remove`
  // deletes the plugin folder right after disabling it. The service is also
  // destroyed on a normal shell exit or hot-reload; the shell.json check makes
  // those a no-op, so the guard is only removed when the plugin is really off.
  readonly property string removeCommand:
    "sleep 1; c=\"${XDG_CONFIG_HOME:-$HOME/.config}\"; " +
    "grep -qF '\"" + pluginId + "\"' \"$c/omarchy/shell.json\" 2>/dev/null && exit 0; " +
    "for f in \"$c/foot/foot.ini\" \"$c/alacritty/alacritty.toml\" " +
    "\"$c/kitty/kitty.conf\" \"$c/ghostty/config\"; do " +
    "[ -f \"$f\" ] && grep -q '^# >>> ctrlz-guard' \"$f\" && " +
    "sed -i --follow-symlinks '/^# >>> ctrlz-guard/,/^# <<< ctrlz-guard/d' \"$f\"; " +
    "done"

  Process {
    id: applyProcess
    command: ["bash", root.scriptPath]
    stderr: StdioCollector {
      onStreamFinished: if (text.trim() !== "") console.warn("ctrlz-guard: " + text.trim())
    }
  }

  Component.onCompleted: applyProcess.running = true
  Component.onDestruction: Quickshell.execDetached(["bash", "-c", root.removeCommand])
}
