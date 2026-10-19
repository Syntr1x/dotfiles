// Accent read live from quickshell/accent.conf; local copy because imports
// outside the running config's directory are rejected.
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
}
