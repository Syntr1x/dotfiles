//@ pragma UseQApplication
pragma ComponentBehavior: Bound
// One-shot app launcher (SUPER+R).
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root
    readonly property Theme theme: Theme {}

    property string query: ""
    property int selected: 0
    property var filtered: []

    property var terminalEmulator: ["ghostty", "-e"]

    // Rofi-style frecency history: { "<desktop-id>": { c: launchCount, l: lastUseUnixSec } }
    property var history: ({})

    readonly property string historyDir: {
        const xdg = Quickshell.env("XDG_STATE_HOME");
        return (xdg || (Quickshell.env("HOME") || "") + "/.local/state") + "/quickshell";
    }
    readonly property string historyPath: root.historyDir + "/launcher-history.json"
    property FileView historyFile: FileView {
        path: root.historyPath
        watchChanges: false
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    function historyKey(e) {
        if (!e) return "";
        return e.id || e.execString || e.name || "";
    }

    function frecency(e) {
        const entry = root.history[root.historyKey(e)];
        if (!entry) return 0;
        const countScore = Math.min((entry.c || 0) * 2, 20);
        const age = Math.floor(Date.now() / 1000) - (entry.l || 0);
        let recency = 0;
        if (age < 3600) recency = 15;
        else if (age < 86400) recency = 10;
        else if (age < 7 * 86400) recency = 5;
        else if (age < 30 * 86400) recency = 2;
        return countScore + recency;
    }

    function loadHistory() {
        let parsed = {};
        try {
            const txt = root.historyFile.text();
            if (txt && txt.trim() !== "") {
                const obj = JSON.parse(txt);
                if (obj && typeof obj === "object") parsed = obj;
            }
        } catch (err) { parsed = {}; }

        // Drop entries for uninstalled apps — but only with a non-empty app list,
        // or a slow DesktopEntries scan would wipe all history at startup.
        const apps = root.allApps();
        const known = {};
        for (let i = 0; i < apps.length; i++) known[root.historyKey(apps[i])] = true;

        const clean = {};
        for (const key of Object.keys(parsed)) {
            const v = parsed[key];
            if (apps.length > 0 && !known[key]) continue;
            if (!v || typeof v.c !== "number") continue;
            clean[key] = { c: Math.max(0, Math.min(v.c, 10000)), l: typeof v.l === "number" ? v.l : 0 };
        }
        root.history = clean;
    }

    function saveHistory() {
        const keys = Object.keys(root.history);
        if (keys.length > 150) {
            const scored = keys.map(key => [(root.history[key].c || 0) * 1e10 + (root.history[key].l || 0), key]);
            scored.sort((a, b) => b[0] - a[0]);
            const trimmed = {};
            for (let i = 0; i < 150; i++) trimmed[scored[i][1]] = root.history[scored[i][1]];
            root.history = trimmed;
        }
        try {
            root.historyFile.setText(JSON.stringify(root.history));
        } catch (err) {}
    }

    function recordLaunch(e) {
        try {
        const key = root.historyKey(e);
        if (key === "") return;
        // Reassign instead of mutating: QML does not track plain JS object
        // changes, so a property write is what makes frecency() see it.
        const history = Object.assign({}, root.history);
        const entry = history[key] || { c: 0, l: 0 };
        entry.c = (entry.c || 0) + 1;
        entry.l = Math.floor(Date.now() / 1000);
        history[key] = entry;
        root.history = history;
        root.saveHistory();
        } catch (err) {}
    }

    function stepSelection(delta) {
        if (root.filtered.length === 0) return;
        root.selected = Math.max(0, Math.min(root.selected + delta, root.filtered.length - 1));
    }

    function allApps() {
        if (typeof DesktopEntries === "undefined" || !DesktopEntries.applications) return [];
        const values = DesktopEntries.applications.values;
        const out = [];
        for (let i = 0; i < values.length; i++) {
            if (!values[i].noDisplay) out.push(values[i]);
        }
        out.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        return out;
    }

    function score(e, q) {
        if (q === "") return 0;
        const name = (e.name || "").toLowerCase();
        const i = name.indexOf(q);
        if (i === 0) return 100 - name.length;
        if (i > 0) {
            const wordStart = name[i - 1] === " " || name[i - 1] === "-" || name[i - 1] === "_";
            return (wordStart ? 60 : 40) - i - name.length * 0.1;
        }
        const id = (e.id || "").toLowerCase();
        if (id.indexOf(q) >= 0) return 20 - id.indexOf(q);
        const generic = (e.genericName || "").toLowerCase();
        if (generic.indexOf(q) >= 0) return 15 - generic.indexOf(q);
        const comment = (e.comment || "").toLowerCase();
        if (comment.indexOf(q) >= 0) return 10 - comment.indexOf(q);
        if (e.keywords) {
            for (const keyword of e.keywords) {
                if ((keyword || "").toLowerCase().indexOf(q) >= 0) return 5;
            }
        }
        let ni = 0;
        for (const c of q) {
            ni = name.indexOf(c, ni);
            if (ni < 0) return -1;
            ni++;
        }
        return 1 - name.length * 0.05;
    }

    function refilter() {
        const q = root.query.trim().toLowerCase();
        const apps = root.allApps();

        if (q === "") {
            const ranked = apps.map(app => [root.frecency(app), (app.name || "").toLowerCase(), app]);
            ranked.sort((a, b) => b[0] - a[0] || (a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0));
            root.filtered = ranked.slice(0, 60).map(r => r[2]);
            root.selected = 0;
            return;
        }

        const scored = [];
        for (const app of apps) {
            const s = root.score(app, q);
            if (s < 0) continue;
            // Capped frecency tie-break so frequent matches float up without beating better text matches.
            scored.push([s + Math.min(root.frecency(app), 24) * 0.5, app]);
        }
        scored.sort((a, b) => b[0] - a[0]);
        root.filtered = scored.slice(0, 60).map(s => s[1]);
        root.selected = 0;
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function launchEntry(e) {
        if (!e) return;
        if (!e.runInTerminal) {
            e.execute();
            return;
        }
        // Keep the terminal open on failure so the exit code can be read.
        const cmd = e.command && e.command.length > 0 ? e.command : ["sh", "-c", e.execString];
        const workdir = e.workingDirectory || null;
        const inner = cmd.map(root.shellQuote).join(" ");
        let script = (workdir ? "cd " + root.shellQuote(workdir) + " && " : "") + inner;
        script += "; code=$?; if [ $code -ne 0 ]; then echo \"[exit $code - press Enter to close]\"; read _; fi";
        Quickshell.execDetached({
            command: root.terminalEmulator.concat(["sh", "-c", script]),
            workingDirectory: workdir || undefined
        });
    }

    function launchCurrent() {
        if (root.filtered.length > 0) {
            const entry = root.filtered[Math.min(root.selected, root.filtered.length - 1)];
            root.recordLaunch(entry);
            root.launchEntry(entry);
        }
        Qt.quit();
    }

    function handleKey(e) {
        if (e.key === Qt.Key_Escape) Qt.quit();
        else if (e.key === Qt.Key_Down) root.stepSelection(1);
        else if (e.key === Qt.Key_Up) root.stepSelection(-1);
        else if (e.key === Qt.Key_PageDown) root.stepSelection(8);
        else if (e.key === Qt.Key_PageUp) root.stepSelection(-8);
        else if (e.key === Qt.Key_Home) root.selected = 0;
        else if (e.key === Qt.Key_End) root.selected = Math.max(0, root.filtered.length - 1);
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.launchCurrent();
        else return;
        e.accepted = true;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.historyDir]);
        root.loadHistory();
        root.refilter();
    }

    // DesktopEntries scans async: empty at onCompleted, applicationsChanged fires once it lands.
    Connections {
        target: typeof DesktopEntries === "undefined" ? null : DesktopEntries
        function onApplicationsChanged() { root.loadHistory(); root.refilter(); }
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
            Keys.onPressed: event => root.handleKey(event)
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

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 10
                    color: Qt.rgba(255, 255, 255, 0.06)
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                        Text { text: "\u{f002}"; color: root.theme.textSub; font.family: root.theme.fontFam; font.pixelSize: 15 }
                        TextInput {
                            id: entry
                            Layout.fillWidth: true
                            text: root.query
                            color: "white"
                            selectionColor: root.theme.accent
                            selectedTextColor: root.theme.accentFg
                            font.family: root.theme.fontFam; font.pixelSize: 14
                            focus: true
                            onTextEdited: { root.query = text; root.refilter(); }
                            onActiveFocusChanged: { if (!activeFocus) focusTimer.running = true; }
                            Keys.onPressed: event => root.handleKey(event)
                        }
                    }
                }

                ListView {
                    id: resultList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    model: root.filtered
                    clip: true
                    spacing: 6
                    currentIndex: root.selected
                    boundsBehavior: Flickable.StopAtBounds
                    // Keep the keyboard selection in view.
                    onCurrentIndexChanged: { if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain); }
                    onCountChanged: positionViewAtBeginning()
                    delegate: Rectangle {
                        id: resultRow
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: resultRow.index === root.selected
                        width: ListView.view.width
                        height: 46
                        radius: 10
                        color: resultRow.isSelected ? root.theme.accent
                            : (rowHover.containsMouse ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03))
                        ColumnLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            anchors.topMargin: 5; anchors.bottomMargin: 5; spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: resultRow.modelData.name || resultRow.modelData.id
                                color: resultRow.isSelected ? root.theme.accentFg : "white"
                                font.family: root.theme.fontFam; font.pixelSize: 13; font.bold: resultRow.isSelected
                                elide: Text.ElideRight
                            }
                            Text {
                                readonly property string subtitle: resultRow.modelData.genericName || resultRow.modelData.comment || ""
                                Layout.fillWidth: true
                                visible: subtitle !== ""
                                text: subtitle
                                color: resultRow.isSelected ? root.theme.accentFg : root.theme.textSub
                                font.family: root.theme.fontFam; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = resultRow.index
                            onClicked: { root.selected = resultRow.index; root.launchCurrent(); }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.filtered.length + " apps  \u{2022}  Enter launch  \u{2022}  Esc close"
                    color: root.theme.textSub; font.family: root.theme.fontFam; font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
