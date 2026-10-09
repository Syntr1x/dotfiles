// Media popup (media-player/toggle.sh). Quits itself on close, Esc or click outside.
import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: root

    // Accent logic lives in Theme.qml: imports from outside the running
    // config's folder are rejected, so each module keeps its own copy.
    Theme { id: theme }

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
                    accent: theme.accent
                    accentFg: theme.accentFg
                }
            }
        }
    }
}
