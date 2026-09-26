// Media popup (media-player/toggle.sh). Quits itself on close, Esc or click outside.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    // Accent logic duplicated from Theme.qml: imports outside the running config's folder are rejected.
    readonly property string defaultAccent: "#f0a0c0"

    readonly property string accentPath: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return (xdg || (Quickshell.env("HOME") || "") + "/.config") + "/quickshell/accent.conf";
    }
    readonly property FileView accentFile: FileView {
        path: root.accentPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property string accent: {
        const txt = root.accentFile.text();
        const m = /accent\s*=\s*(#[0-9a-fA-F]{6})/.exec(txt) || /(#[0-9a-fA-F]{6})/.exec(txt);
        return m && m[1] ? m[1] : root.defaultAccent;
    }
    readonly property string accentFg: {
        const c = root.accent;
        const l = 0.2126 * parseInt(c.slice(1, 3), 16) / 255
            + 0.7152 * parseInt(c.slice(3, 5), 16) / 255
            + 0.0722 * parseInt(c.slice(5, 7), 16) / 255;
        return l > 0.58 ? "#121214" : "white";
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            margins { top: 64 }   // clears the 38px bar

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            aboveWindows: true
            focusable: false
            color: "transparent"
            implicitHeight: 130

            mask: Region { item: card }

            HyprlandFocusGrab {
                windows: [win]
                active: modelData === Quickshell.screens[0]
                onCleared: Qt.quit()
            }

            Item {
                anchors.fill: parent
                MediaCard {
                    id: card
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    accent: root.accent
                    accentFg: root.accentFg
                }
            }
        }
    }
}
