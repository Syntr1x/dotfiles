// Launcher-local theme — live accent from quickshell/accent.conf
// (watched, zero restart). Self-contained so the launcher module has
// no dependency on the parent dir (Quickshell blocks ".." imports).
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

    readonly property string accent: {
        var txt = theme.accentFile.text();
        var m = /accent\s*=\s*(#[0-9a-fA-F]{6})/.exec(txt) || /(#[0-9a-fA-F]{6})/.exec(txt);
        if (m && m[1]) return m[1];
        return "#f0a0c0";
    }

    readonly property color textSub: "#a0a0a0"
    readonly property string fontFam: "Fira Sans Semibold, JetBrainsMono Nerd Font, Font Awesome 6 Free, sans-serif"
}
