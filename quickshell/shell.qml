//@ pragma UseQApplication
// Default config — run with plain `qs`. Bar daemon with IPC toggle.
// SUPER+W (toggle) -> `qs ipc call bar toggle`
// Launcher is one-shot: `qs -p ~/.config/quickshell/launcher/shell.qml` on SUPER+R.
import Quickshell
import Quickshell.Io
import QtQuick
import "bar/" as BarModule

ShellRoot {
    id: root
    Theme { id: theme }

    property bool barVisible: true

    IpcHandler {
        target: "bar"

        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
    }

    BarModule.Bar {
        theme: theme
        visible: root.barVisible
    }
}
