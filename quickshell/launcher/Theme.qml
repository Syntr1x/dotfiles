// Accent read live from quickshell/accent.conf.
// Duplicates the bar Theme.qml: imports outside the running config's folder are rejected.
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

    readonly property color textSub: "#a0a0a0"
    // Keep in sync with ../Theme.qml (see comment there).
    function scaleFor(screenName) {
        const v = parseFloat(Quickshell.env("QUICKSHELL_UI_SCALE") || "");
        if (!isNaN(v) && v > 0.4 && v < 2.0) return v;
        // Scale down only external screens, and only when the machine itself
        // is a laptop (has an internal eDP/LVDS/DSI panel). Desktops: 1.0.
        if (/^(eDP|LVDS|DSI)/i.test(String(screenName || ""))) return 1.0;
        for (let i = 0; i < Quickshell.screens.length; ++i) {
            if (/^(eDP|LVDS|DSI)/i.test(String(Quickshell.screens[i].name || ""))) return 0.75;
        }
        return 1.0;
    }
    readonly property real uiScale: scaleFor("")
    function px(v) { return Math.round(v * uiScale); }
    function pxFor(screenName, v) { return Math.round(v * scaleFor(screenName)); }
    readonly property string fontFam: "Inter"
}
