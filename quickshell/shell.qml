//@ pragma UseQApplication
pragma ComponentBehavior: Bound
// Bar config: SUPER+W toggles (toggle-bar.sh), SUPER+R opens launcher/shell.qml.
import Quickshell
import Quickshell.Io
import QtQuick
import "bar/" as BarModule

ShellRoot {
    id: root

    Theme { id: theme }

    property bool _hidden: false
    readonly property bool barVisible: !root._hidden

    IpcHandler {
        target: "bar"

        function toggle(): void { root._hidden = !root._hidden; }
        function show(): void { root._hidden = false; }
        function hide(): void { root._hidden = true; }
    }

    BarModule.Bar {
        theme: theme
        visible: root.barVisible
    }
}
