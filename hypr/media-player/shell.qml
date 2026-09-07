// Media popup for waybar
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property string waybarCssPath: {
        let xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (!xdg || xdg === "")
            xdg = (Quickshell.env("HOME") || "") + "/.config";
        return xdg + "/waybar/style.css";
    }
    FileView {
        id: waybarCss
        path: root.waybarCssPath
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property string accentColor: {
        const m = /@define-color\s+bordercolor\s+([^;]+);/.exec(waybarCss.text());
        if (m && m[1]) {
            const c = m[1].trim();
            if (/^#[0-9a-fA-F]{6}$/.test(c))
                return c;
        }
        return "#fed79d"; // fallback = IC_Orange_PPL theme
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
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    accent: root.accentColor
                    accentFg: root.accentFg
                }
            }
        }
    }
}
