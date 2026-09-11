//@ pragma UseQApplication
// One-shot drun launcher: `qs -p ~/.config/quickshell/launcher/shell.qml`
// (SUPER+R). Centered card, live accent from quickshell/accent.conf.
// Enter = launch, Ctrl+Enter = run raw command, Esc/click-outside = close.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root
    property var theme: Theme {}

    property string query: ""
    property int selected: 0
    property var filtered: []

    property var terminalEmulator: ["ghostty", "-e"]

    function allApps() {
        if (typeof DesktopEntries === "undefined" || !DesktopEntries.applications) return [];
        var out = [], vals = DesktopEntries.applications.values;
        for (var i = 0; i < vals.length; i++) {
            var e = vals[i];
            if (e.noDisplay) continue;
            out.push(e);
        }
        out.sort(function(a, b) { return a.name.localeCompare(b.name); });
        return out;
    }

    // fuzzy-ish score: prefix > word-boundary > substring > comment/keyword.
    // negative = no match.
    function score(e, q) {
        if (q === "") return 0;
        var name = (e.name || "").toLowerCase();
        var i = name.indexOf(q);
        if (i === 0) return 100 - name.length;
        if (i > 0) {
            var wb = name[i - 1] === " " || name[i - 1] === "-" || name[i - 1] === "_";
            return (wb ? 60 : 40) - i - name.length * 0.1;
        }
        var id = (e.id || "").toLowerCase();
        if (id.indexOf(q) >= 0) return 20 - id.indexOf(q);
        var gn = (e.genericName || "").toLowerCase();
        if (gn && gn.indexOf(q) >= 0) return 15 - gn.indexOf(q);
        var cm = (e.comment || "").toLowerCase();
        if (cm && cm.indexOf(q) >= 0) return 10 - cm.indexOf(q);
        if (e.keywords) for (var k = 0; k < e.keywords.length; k++)
            if ((e.keywords[k] || "").toLowerCase().indexOf(q) >= 0) return 5;
        // subsequence fallback (e.g. "ff" -> "Firefox")
        var ni = 0;
        for (var qi = 0; qi < q.length; qi++) {
            ni = name.indexOf(q[qi], ni);
            if (ni < 0) return -1;
            ni++;
        }
        return 1 - name.length * 0.05;
    }

    function refilter() {
        var q = root.query.trim().toLowerCase();
        var apps = allApps(), scored = [];
        for (var i = 0; i < apps.length; i++) {
            var s = root.score(apps[i], q);
            if (s >= 0) scored.push([s, apps[i]]);
        }
        scored.sort(function(a, b) { return b[0] - a[0]; });
        var out = [];
        for (var j = 0; j < scored.length && j < 60; j++) out.push(scored[j][1]);
        root.filtered = out;
        root.selected = 0;
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function launchEntry(e) {
        if (!e) return;
        if (e.runInTerminal) {
            var cmd = (e.command && e.command.length > 0) ? e.command : ["sh", "-c", e.execString];
            // Honour Path= from the .desktop file. Quickshell exposes it as
            // workingDirectory; execDetached does NOT pick it up automatically,
            // so it must be passed explicitly (both as ghostty's CWD and via cd,
            // since -e children inherit the terminal's CWD).
            var workdir = (e.workingDirectory && e.workingDirectory !== "") ? e.workingDirectory : null;
            // Build an argv-accurate shell invocation, wrapped so a crash no
            // longer flashes ghostty shut: non-zero exits wait for Enter.
            var inner = "";
            for (var i = 0; i < cmd.length; i++) {
                if (i > 0) inner += " ";
                inner += shellQuote(cmd[i]);
            }
            var script = (workdir ? "cd " + shellQuote(workdir) + " && " : "") + inner;
            script += "; code=$?; if [ $code -ne 0 ]; then echo \"[exit $code - press Enter to close]\"; read _; fi";
            var ctx = { command: root.terminalEmulator.concat(["sh", "-c", script]) };
            if (workdir) ctx.workingDirectory = workdir;
            Quickshell.execDetached(ctx);
        } else {
            e.execute();
        }
    }

    function launchCurrent(asRun) {
        if (asRun || root.filtered.length === 0) {
            var cmd = root.query.trim();
            if (cmd !== "") Quickshell.execDetached(["sh", "-c", cmd]);
        } else {
            root.launchEntry(root.filtered[Math.min(root.selected, root.filtered.length - 1)]);
        }
        Qt.quit();
    }

    Component.onCompleted: refilter()

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.refilter(); }
    }

    Timer {
        id: focusTimer
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            if (entry.activeFocus) running = false;
            else entry.forceActiveFocus();
        }
    }

    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        aboveWindows: true
        focusable: true

        mask: Region { item: card }

        HyprlandFocusGrab {
            windows: [win]
            active: true
            onCleared: Qt.quit()
        }

        Item {
            anchors.fill: parent
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { Qt.quit(); e.accepted = true; }
                else if (e.key === Qt.Key_Down) { root.selected = Math.min(root.selected + 1, root.filtered.length - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Up) { root.selected = Math.max(root.selected - 1, 0); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launchCurrent(e.modifiers & Qt.ControlModifier); e.accepted = true; }
            }
        }

        Rectangle {
            id: card
            width: 620
            height: Math.min(470, 150 + Math.min(root.filtered.length, 8) * 52)
            anchors.centerIn: parent
            radius: 16
            color: Qt.rgba(20 / 255, 20 / 255, 22 / 255, 0.96)
            border.color: Qt.alpha(root.theme.accent, 0.6)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "  LAUNCH"
                    color: root.theme.accent
                    font.family: root.theme.fontFam; font.pixelSize: 13; font.bold: true
                    leftPadding: 4
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 10
                    color: Qt.rgba(255, 255, 255, 0.06)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                        Text { text: ""; color: root.theme.textSub; font.pixelSize: 15 }
                        TextInput {
                            id: entry
                            Layout.fillWidth: true
                            text: root.query
                            color: "white"
                            selectionColor: root.theme.accent
                            selectedTextColor: "#121214"
                            font.family: root.theme.fontFam; font.pixelSize: 14
                            focus: true
                            onTextChanged: { root.query = text; root.refilter(); }
                            onActiveFocusChanged: { if (!activeFocus) focusTimer.running = true; }
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_Down) { root.selected = Math.min(root.selected + 1, root.filtered.length - 1); e.accepted = true; }
                                else if (e.key === Qt.Key_Up) { root.selected = Math.max(root.selected - 1, 0); e.accepted = true; }
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launchCurrent(e.modifiers & Qt.ControlModifier); e.accepted = true; }
                                else if (e.key === Qt.Key_Escape) { Qt.quit(); e.accepted = true; }
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    model: root.filtered.slice(0, 8)
                    clip: true
                    spacing: 6
                    highlightFollowsCurrentItem: false
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width; height: 46; radius: 10
                        color: index === root.selected ? root.theme.accent : (rowHover.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            anchors.topMargin: 5; anchors.bottomMargin: 5; spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || modelData.id
                                color: index === root.selected ? "#121214" : "white"
                                font.family: root.theme.fontFam; font.pixelSize: 13; font.bold: index === root.selected
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: (modelData.genericName || modelData.comment) !== ""
                                text: modelData.genericName || modelData.comment || ""
                                color: index === root.selected ? "#121214" : root.theme.textSub
                                font.family: root.theme.fontFam; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = index
                            onClicked: { root.selected = index; root.launchCurrent(false); }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.filtered.length + " apps  •  Enter launch  •  Ctrl+Enter run  •  Esc close"
                    color: root.theme.textSub; font.family: root.theme.fontFam; font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
