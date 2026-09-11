// Shared theme — live accent from quickshell/accent.conf
// (written by themeselector apply.sh)
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: theme

    property string accentPath: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (!xdg || xdg === "") xdg = (Quickshell.env("HOME") || "") + "/.config";
        return xdg + "/quickshell/accent.conf";
    }

    property FileView accentFile: FileView {
        path: theme.accentPath
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
    }

    // 12-theme tables mirrored from quickshell/themeselector/apply.sh
    readonly property var themeIds: ["syn-beige", "syn-Broadcast", "syn-mellow", "syn-Ocean", "IC_Orange_PPL", "Gruvbox", "syn-rose-pine", "syn-Tango", "Tomorrow", "syn-green", "traffic", "syn-mellow-darkmode"]
    readonly property var themeNames: ["Beige", "Dark", "Purple", "Blue", "Orange", "Gruvbox", "Kirby", "Moondrop", "Winter", "Green", "Destiny 2", "Purple (darkmode)"]
    readonly property var accentColors: ["#d8c8b3", "#888888", "#f0a0c0", "#a1cdf3", "#fed79d", "#d8c8b3", "#fdcbe6", "#FB443C", "#FDE094", "#8c9180", "#C0884B", "#f0a0c1"]

    readonly property string accent: {
        var txt = theme.accentFile.text();
        var m = /accent\s*=\s*(#[0-9a-fA-F]{6})/.exec(txt) || /(#[0-9a-fA-F]{6})/.exec(txt);
        if (m && m[1]) return m[1];
        return "#f0a0c0";
    }

    // readable glyph color on the accent pill
    readonly property string accentFg: {
        var c = theme.accent;
        if (!c || c.length < 7) return "white";
        var r = parseInt(c.slice(1, 3), 16) / 255, g = parseInt(c.slice(3, 5), 16) / 255, b = parseInt(c.slice(5, 7), 16) / 255;
        var l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        return l > 0.58 ? "#121214" : "white";
    }

    // Shared style constants
    readonly property color moduleBg: Qt.rgba(20 / 255, 20 / 255, 20 / 255, 0.6)
    readonly property color moduleBgHover: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.8)
    readonly property color textCol: "white"
    readonly property color textSub: "#a0a0a0"
    readonly property color red: "#e06c75"
    readonly property color green: "#98c379"
    readonly property color teal: "#56b6c2"
    readonly property int radius: 10
    readonly property string fontFam: "Fira Sans Semibold, JetBrainsMono Nerd Font, Font Awesome 6 Free, sans-serif"
    readonly property string fontMono: "Firacode Nerd Font Mono, JetBrainsMono Nerd Font, monospace"
}
