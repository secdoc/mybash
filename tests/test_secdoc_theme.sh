#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [[ -f $ROOT/$1 ]] || fail "missing $1"; }
assert_contains() { grep -Fq -- "$2" "$ROOT/$1" || fail "$1 does not contain: $2"; }

assert_file config.jsonc
assert_file starship.toml
assert_file starship-theme
assert_file alacritty.toml

# Starship exposes the approved conditional modules in a compact prompt.
for module in '$git_branch' '$git_status' '$status' '$jobs' '$cmd_duration' '$time'; do
  assert_contains starship.toml "$module"
done
for table in '[status]' '[jobs]' '[cmd_duration]' '[time]'; do
  assert_contains starship.toml "$table"
done

# SECDOC is selectable, non-interactive, and idempotent.
assert_contains starship-theme '[secdoc]="161616 3B3B3B 555555 DB5192 FFCC57 EF802F"'
assert_contains starship-theme 'ORDER=(secdoc '
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
STARSHIP_CONFIG="$TMPDIR/starship.toml" STARSHIP_THEME_BASE="$ROOT/starship.toml" "$ROOT/starship-theme" secdoc >/dev/null
first=$(sha256sum "$TMPDIR/starship.toml" | cut -d' ' -f1)
STARSHIP_CONFIG="$TMPDIR/starship.toml" STARSHIP_THEME_BASE="$ROOT/starship.toml" "$ROOT/starship-theme" secdoc >/dev/null
second=$(sha256sum "$TMPDIR/starship.toml" | cut -d' ' -f1)
[[ $first == "$second" ]] || fail 'SECDOC theme is not idempotent'
for color in 161616 3B3B3B 555555 FFCC57 EF802F DB5192; do
  grep -Fq "#$color" "$TMPDIR/starship.toml" || fail "generated Starship config lacks #$color"
done

# Fastfetch keeps the dense Pop!_OS two-column system inventory.
assert_contains config.jsonc '"source": "popos"'
for module in title host cpu gpu disk memory swap sound display localip netio wifi de wm shell terminal os kernel packages uptime; do
  grep -Eq "\"type\"[[:space:]]*:[[:space:]]*\"$module\"" "$ROOT/config.jsonc" || fail "Fastfetch lacks $module"
done
assert_contains config.jsonc '"key": "AUDIO"'
assert_contains config.jsonc '"keyColor": "38;2;239;128;47"'
assert_contains config.jsonc '\u001b[38;2;239;128;47m{name} ({volume-percentage})'

# Disk labels must expose every configured mount point without clipping.
assert_contains config.jsonc '"key": "Disk ({mountpoint})"'
assert_contains config.jsonc '"keyWidth": 19'
for mountpoint in '"/"' '"/mnt/data"' '"/mnt/storage"' '"/recovery"'; do
  assert_contains config.jsonc "$mountpoint"
done
for label in 'DISK (/)' 'DISK (/mnt/data)' 'DISK (/mnt/storage)' 'DISK (/recovery)'; do
  assert_contains assets/secdoc-terminal.svg "$label"
done

# Alacritty maps semantic ANSI names to the approved exact brand palette.
for color in '#161616' '#F7F7F7' '#FFCC57' '#EF802F' '#EDF577' '#DB5192' '#C4C4C4' '#555555'; do
  grep -Fqi "$color" "$ROOT/alacritty.toml" || fail "Alacritty lacks $color"
done

# Installer, editor preference, ownership, and docs preserve downstream behavior.
assert_contains setup.sh 'alacritty.toml'
assert_contains setup.sh 'starship-theme" secdoc'
assert_contains uninstall.sh '.config/alacritty/alacritty.toml'
assert_contains .bashrc 'export EDITOR=nano'
assert_contains .bashrc 'export VISUAL=nano'
assert_contains setup.sh 'apt-get install -y bash-completion bat'
assert_contains .bashrc "alias cat='batcat --paging=never --style=plain'"
assert_contains .bashrc "alias cat='bat --paging=never --style=plain'"
assert_contains .github/FUNDING.yml 'github: secdoc'
assert_contains README.md 'https://github.com/secdoc/mybash.git'
assert_contains README.md 'ChrisTitusTech/mybash'
assert_contains README.md 'starship-theme secdoc'
assert_contains README.md 'full disk mount-point labels'
assert_contains README.md 'batcat'

# The interactive cat alias prefers Debian's batcat command and preserves stdin.
BAT_TEST_DIR="$TMPDIR/bat-test"
mkdir -p "$BAT_TEST_DIR"
cat >"$BAT_TEST_DIR/batcat" <<'EOF'
#!/bin/sh
printf 'args:%s\n' "$*"
cat
EOF
chmod +x "$BAT_TEST_DIR/batcat"
bat_output=$(PATH="$BAT_TEST_DIR:/usr/bin:/bin" HOME="$TMPDIR" bash --noprofile --rcfile "$ROOT/.bashrc" -ic 'eval "printf payload | cat"' 2>/dev/null)
[[ $bat_output == $'args:--paging=never --style=plain\npayload' ]] || fail "cat alias did not invoke batcat correctly: $bat_output"

# The fallback uses bat when batcat is unavailable.
BAT_FALLBACK_DIR="$TMPDIR/bat-fallback-test"
mkdir -p "$BAT_FALLBACK_DIR"
cat >"$BAT_FALLBACK_DIR/bat" <<'EOF'
#!/bin/sh
printf 'args:%s\n' "$*"
cat
EOF
chmod +x "$BAT_FALLBACK_DIR/bat"
bat_fallback_output=$(PATH="$BAT_FALLBACK_DIR:/usr/bin:/bin" HOME="$TMPDIR" bash --noprofile --rcfile "$ROOT/.bashrc" -ic 'eval "printf payload | cat"' 2>/dev/null)
[[ $bat_fallback_output == $'args:--paging=never --style=plain\npayload' ]] || fail "cat alias did not invoke bat fallback correctly: $bat_fallback_output"

# Aliases do not expand in non-interactive Bash, and command cat bypasses them interactively.
noninteractive_output=$(PATH="$BAT_TEST_DIR:/usr/bin:/bin" HOME="$TMPDIR" bash --noprofile -c '. "$1"; eval "printf payload | cat"' bash "$ROOT/.bashrc" 2>/dev/null)
[[ $noninteractive_output == payload ]] || fail "non-interactive cat behavior changed: $noninteractive_output"
bypass_output=$(PATH="$BAT_TEST_DIR:/usr/bin:/bin" HOME="$TMPDIR" bash --noprofile --rcfile "$ROOT/.bashrc" -ic 'eval "printf payload | command cat"' 2>/dev/null)
[[ $bypass_output == payload ]] || fail "command cat did not bypass the alias: $bypass_output"

printf 'SECDOC theme contract passed.\n'
