// Media popup (quickshell bar media button)
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property string accentPath: {
        let xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (!xdg || xdg === "")
            xdg = (Quickshell.env("HOME") || "") + "/.config";
        return xdg + "/quickshell/accent.conf";
    }
    FileView {
        id: accentFile
        path: root.accentPath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property string accentColor: {
        const txt = accentFile.text();
        const m = /accent\s*=\s*(#[0-9a-fA-F]{6})/.exec(txt) || /(#[0-9a-fA-F]{6})/.exec(txt);
        if (m && m[1])
            return m[1];
        return "#f0a0c0";
    }
    // readable glyph color on the accent
    readonly property string accentFg: {
        const c = root.accentColor;
        const r = parseInt(c.slice(1, 3), 16) / 255, g = parseInt(c.slice(3, 5), 16) / 255, b = parseInt(c.slice(5, 7), 16) / 255;
        const l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        return l > 0.58 ? "#121214" : "white";
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: 64
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            aboveWindows: true
            focusable: false
            color: "transparent"
            implicitHeight: 130

            mask: Region {
                item: card
            }

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
                    accent: root.accentColor
                    accentFg: root.accentFg
                }
            }
        }
    }
}
