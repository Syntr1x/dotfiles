// Media popup (media-player/toggle.sh). Quits itself on close, Esc or click outside.
import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
    id: root

    // Accent logic lives in Theme.qml: imports from outside the running
    // config's folder are rejected, so each module keeps its own copy.
    Theme { id: theme }

    // Per-output scale, kept in sync with Theme.qml: eDP-1 -> 1.0, DP-1 -> 0.75,
    // env QUICKSHELL_UI_SCALE forces a global value.
    function scaleFor(screenName) {
        const v = parseFloat(Quickshell.env("QUICKSHELL_UI_SCALE") || "");
        if (!isNaN(v) && v > 0.4 && v < 2.0) return v;
        if (screenName === "DP-1") return 0.75;
        return 1.0;
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property real uiScale: root.scaleFor(modelData ? modelData.name : "")
            function px(v) { return Math.round(v * uiScale); }

            anchors { top: true; left: true; right: true }
            margins { top: px(64) }   // clears the scaled bar

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            aboveWindows: true
            focusable: true
            color: "transparent"
            implicitHeight: px(130)

            mask: Region { item: card }

            HyprlandFocusGrab {
                windows: [win]
                active: modelData === Quickshell.screens[0]
                onCleared: Qt.quit()
            }

            Item {
                anchors.fill: parent
                // Window-level Esc: the grab gives this window keyboard focus,
                // and unhandled keys stop here. Clicks outside the card region
                // clear HyprlandFocusGrab and quit via onCleared below.
                focus: true
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape) { e.accepted = true; Qt.quit(); }
                }
                MediaCard {
                    id: card
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    accent: theme.accent
                    accentFg: theme.accentFg
                    uiScale: win.uiScale
                }
            }
        }
    }
}
