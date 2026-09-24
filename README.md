# CtrlZ Guard

An Omarchy shell plugin that stops Ctrl+Z from suspending whatever is running in
your terminal. While it's enabled, Ctrl+Z sends **Ctrl+_** instead, which is
*undo* in Claude Code, bash/readline, zsh and most other terminal apps. Pressing it
by accident undoes some typing instead of freezing your program and dropping you
back to a shell prompt.

**Why a terminal remap?** Some programs handle ^Z themselves in raw mode
(Claude Code, for example). For those, `stty susp undef` does nothing and there's
no setting that turns it off. The only reliable fix is for the terminal to never
send ^Z for that key.

## What it changes

When you enable it, and again each time the Omarchy shell starts, it adds one
clearly marked block to the config of each terminal you have a config for:

| Terminal  | File                                | Line added                                        |
|-----------|-------------------------------------|---------------------------------------------------|
| foot      | `~/.config/foot/foot.ini`           | `[text-bindings]` / `\x1f=Control+z`              |
| alacritty | `~/.config/alacritty/alacritty.toml`| `{ key = "Z", mods = "Control", chars = "\u001f" },` (inside `keyboard.bindings`) |
| kitty     | `~/.config/kitty/kitty.conf`        | `map ctrl+z send_text all \x1f`                   |
| ghostty   | `~/.config/ghostty/config`          | `keybind = ctrl+z=text:\x1f`                      |

Every addition sits between these two lines, and nothing outside them is touched:

    # >>> ctrlz-guard (Omarchy plugin; disable it to remove this block) >>>
    # <<< ctrlz-guard <<<

- A terminal with no config file is skipped, and no files are created.
- If you already bind Ctrl+Z yourself in a config, that terminal is left alone.
- Symlinked configs (stow, chezmoi, etc.) stay symlinks.
- New terminal windows pick up the change; windows that are already open keep
  their old behaviour until you open a new one.

## Install

    omarchy plugin add https://github.com/JesusLovesYou1013/ctrlz-guard.git --enable

Or install it without `--enable` and turn it on later from **Setup › Plugins ›
Enable Plugin**. Nothing is changed until the plugin is enabled.

## Remove

Disable it (**Setup › Plugins › Disable Plugin**, or
`omarchy plugin disable io.github.JesusLovesYou1013.ctrlz-guard`), or remove it
(**Setup › Plugins › Remove Plugin**). Either way the marked blocks are deleted
and your configs go back to exactly what they were.

Restarting or logging out of the shell does **not** remove the guard. It's only
removed when the plugin is actually disabled or removed.

## Dependencies

None beyond what Omarchy ships: `bash`, `grep`, `sed`, `awk`. The tests also
use `python3`.

## Development

    tests/run.sh                         # headless; runs in a throwaway temp home
    omarchy plugin validate .            # manifest check

## License

GPL-3.0. See `LICENSE`.
