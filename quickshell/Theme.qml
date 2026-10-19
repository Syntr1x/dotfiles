// Accent is read live from quickshell/accent.conf (written by themeselector/apply.sh).
// NOTE: launcher/ and media-player/ duplicate this logic: quickshell rejects
// imports from outside the running config's folder.
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: theme

    readonly property string defaultAccent: "#f0a0c0"

    readonly property string accentPath: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return (xdg || (Quickshell.env("HOME") || "") + "/.config") + "/quickshell/accent.conf";
    }

    readonly property FileView accentFile: FileView {
        path: theme.accentPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
    }

    // accent.conf holds `accent=#rrggbb`; the second pattern also accepts a bare hex value.
    readonly property string accent: {
        const txt = theme.accentFile.text();
        const m = /accent\s*=\s*(#[0-9a-fA-F]{6})/.exec(txt) || /(#[0-9a-fA-F]{6})/.exec(txt);
        return m && m[1] ? m[1] : theme.defaultAccent;
    }

    readonly property string accentFg: {
        const c = theme.accent;
        const l = 0.2126 * parseInt(c.slice(1, 3), 16) / 255
            + 0.7152 * parseInt(c.slice(3, 5), 16) / 255
            + 0.0722 * parseInt(c.slice(5, 7), 16) / 255;
        return l > 0.58 ? "#121214" : "white";
    }

    readonly property color moduleBg: Qt.rgba(20 / 255, 20 / 255, 20 / 255, 0.6)
    readonly property color moduleBgHover: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.8)
    readonly property color textCol: "white"
    readonly property color textSub: "#a0a0a0"
    readonly property color red: "#e06c75"
    readonly property int radius: 10
    // Per-output scales: eDP-1 laptop keeps the old 1.0 look,
    // 32" DP-1 1080p (~70 DPI) gets 0.75. Env QUICKSHELL_UI_SCALE
    // forces a global value on all outputs (clamped 0.4-2.0).
    // Quickshell rebuilds per-screen windows on plug/unplug, so this
    // follows the active display automatically, no restart needed.
    function scaleFor(screenName) {
        const v = parseFloat(Quickshell.env("QUICKSHELL_UI_SCALE") || "");
        if (!isNaN(v) && v > 0.4 && v < 2.0) return v;
        if (screenName === "DP-1") return 0.75;
        return 1.0;
    }
    readonly property real uiScale: scaleFor("")
    function px(v) { return Math.round(v * uiScale); }
    function pxFor(screenName, v) { return Math.round(v * scaleFor(screenName)); }
    // NOTE: quickshell/Qt ignores comma-separated font lists in font.family —
    // the whole string elastic-matches to one fallback font ("FiraCode NF"
    // resolves to Red Hat Display; use the exact family name).
    // One font for everything: FiraCode Nerd Font is matched by Qt AND
    // contains every bar icon codepoint natively, so text and icons render
    // from a single run — baselines always match, no fallback quirks.
    // U+E266 is the mem icon in FiraCode Nerd Font; do NOT switch to
    // U+F0351 — in this font that codepoint renders an unrelated glyph.
    // (Inter is fine as a text family, but it ships a bogus "ü" glyph at
    // U+E266, so bar icon codepoints must never ride on it.)
    readonly property string fontFam: "FiraCode Nerd Font"
}
