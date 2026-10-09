#!/bin/bash
# apply.sh — backend for the Quickshell theme selector.
# Usage: apply.sh <index 0-11>
set -euo pipefail

# Keep in sync with the tables in themeselector/shell.qml.
themes=("syn-beige" "syn-Broadcast" "syn-mellow" "syn-Ocean" "IC_Orange_PPL" "Gruvbox" "syn-rose-pine" "syn-Tango" "Tomorrow" "syn-green" "traffic" "syn-mellow-darkmode")
theme_names=("Beige" "Dark" "Purple" "Blue" "Orange" "Gruvbox" "Kirby" "Moondrop" "Winter" "Green" "Destiny 2" "Purple(darkmode)")
wallpapers=("Flowers.png" "darkPlants.jpg" "pinkRose.jpg" "bluesky.jpg" "TrainPath.png" "Arch_retro.png" "kirby.jpg" "Moondrop_white.jpg" "winter.jpg" "leaves.jpg" "thats_it.jpg" "black_oled.jpg")
accent_colors=("#d8c8b3" "#888888" "#f0a0c0" "#a1cdf3" "#fed79d" "#d8c8b3" "#fdcbe6" "#FB443C" "#FDE094" "#8c9180" "#C0884B" "#f0a0c1")

die() { echo "$1" >&2; echo "usage: $(basename "$0") <index 0-$(( ${#themes[@]} - 1 ))>" >&2; exit 1; }

idx="${1-}"
[[ $idx =~ ^[0-9]+$ ]] || die "invalid index: '$idx'"
idx=$((10#$idx))   # 10# avoids octal errors on inputs like "08"
(( idx < ${#themes[@]} )) || die "index $idx out of range"

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
theme_cfg="$config_dir/ghostty/config"
wallpaper_cfg="$config_dir/hypr/hyprpaper.conf"
accent_cfg="$config_dir/quickshell/accent.conf"
wallpaper_dir="$config_dir/hypr/Wallpapers"
reload_script="$config_dir/hypr/scripts/reload-hyprpaper.sh"
sddm_cfg="/usr/share/sddm/themes/silent/configs/defaultsyn.conf"

theme="${themes[$idx]}"
name="${theme_names[$idx]}"
wp="${wallpapers[$idx]}"
color="${accent_colors[$idx]}"

# Escape every ERE metacharacter so names and paths round-trip
# through grep -E and sed -E unharmed.
sed_escape() { printf '%s' "$1" | sed -e 's#[][\\/.^$+?(){}|*-]#\\&#g'; }

# Accent first so the bar follows live even if a later step fails.
# Write via temp + mv: an in-place truncate would let the bar's FileView
# watcher read a half-written (empty) file and flash the accent back to
# the default until the next change event.
mkdir -p "${accent_cfg%/*}"
accent_tmp=$(mktemp "${accent_cfg%/*}/.accent.XXXXXX")
printf '# quickshell accent — written by themeselector apply.sh, watched live. Do not edit by hand.\naccent=%s\n' "$color" > "$accent_tmp"
mv -f "$accent_tmp" "$accent_cfg"

# Comment the active line, normalise the list, then uncomment the theme (or append it).
if [[ -f $theme_cfg ]]; then
    esc=$(sed_escape "$theme")
    sed -i -E 's|^[[:space:]]*theme[[:space:]]*=| #theme = |' "$theme_cfg"
    sed -i -E 's|^[[:space:]]*#[[:space:]]*theme[[:space:]]*=[[:space:]]*|#theme = |' "$theme_cfg"
    if grep -qE "^#theme = ${esc}[[:space:]]*\$" "$theme_cfg"; then
        sed -i -E "s|^#theme = ${esc}[[:space:]]*\$|theme = ${esc}|" "$theme_cfg"
    else
        printf 'theme = %s\n' "$theme" >> "$theme_cfg"
    fi
else
    echo "ghostty config not found, skipping: $theme_cfg" >&2
fi

# Swap the path in every per-monitor block (a theme applies to all
# monitors); a fresh stub is only written when no path line exists at all.
mkdir -p "${wallpaper_cfg%/*}"
if [[ -f $wallpaper_cfg ]] && grep -qE '^[[:space:]]*path[[:space:]]*=' "$wallpaper_cfg"; then
    esc_path=$(sed_escape "$wallpaper_dir/$wp")
    sed -i -E "s|^[[:space:]]*path[[:space:]]*=.*\$|    path = $esc_path|" "$wallpaper_cfg"
else
    tmp=$(mktemp)
    {
        echo "splash = false"
        echo "wallpaper {"
        echo "    monitor = "
        echo "    path = $wallpaper_dir/$wp"
        echo "    fit_mode = cover"
        echo "}"
    } > "$tmp"
    mv -f "$tmp" "$wallpaper_cfg"
fi

if [[ -x $reload_script ]]; then
    nohup "$reload_script" >/dev/null 2>&1 & disown || true
elif command -v hyprpaper >/dev/null 2>&1; then
    pkill -x hyprpaper 2>/dev/null || true
    sleep 0.5
    nohup hyprpaper >/dev/null 2>&1 & disown || true
else
    echo "no $reload_script and no hyprpaper in PATH, wallpaper not reloaded" >&2
fi

# Best effort: usually root-owned.
if [[ -f $sddm_cfg && -w $sddm_cfg ]]; then
    esc_wp=$(sed_escape "$wp")
    sed -i -E "s|^background[[:space:]]*=[[:space:]]*\".*\"|background = \"$esc_wp\"|" "$sddm_cfg"
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Theme" "Applied $name" || true
fi
echo "Applied $name ($idx)"
