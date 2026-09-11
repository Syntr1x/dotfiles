// (SUPER+R)
// Enter = launch, Esc/click-outside = close.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ShellRoot {
    id: root
    property var theme: Theme {}

    property string query: ""
    property int selected: 0
    property var filtered: []

    property var terminalEmulator: ["ghostty", "-e"]

    // Rofi-style frecency history: { "<desktop-id>": { c: launchCount, l: lastUseUnixSec } }
    property var history: ({})
    property string historyDir: {
        var s = Quickshell.env("XDG_STATE_HOME");
        if (!s || s === "") s = (Quickshell.env("HOME") || "") + "/.local/state";
        return s + "/quickshell";
    }
    property string historyPath: root.historyDir + "/launcher-history.json"
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
        var k = root.historyKey(e);
        if (k === "") return 0;
        var h = root.history[k];
        if (!h) return 0;
        var countScore = Math.min((h.c || 0) * 2, 20);
        var age = Math.floor(Date.now() / 1000) - (h.l || 0);
        var recency = 0;
        if (age < 3600) recency = 15;
        else if (age < 86400) recency = 10;
        else if (age < 7 * 86400) recency = 5;
        else if (age < 30 * 86400) recency = 2;
        return countScore + recency;
    }

    function loadHistory() {
        var parsed = {};
        try {
            var txt = root.historyFile.text();
            if (txt && txt.trim() !== "") {
                var obj = JSON.parse(txt);
                if (obj && typeof obj === "object") parsed = obj;
            }
        } catch (err) { parsed = {}; }
        // Sanitize: drop entries for uninstalled apps — but only when we
        // actually have an app list. DesktopEntries loads async and can
        // still be empty at startup; pruning then would wipe all history.
        var known = {};
        var apps = root.allApps();
        var hasApps = apps.length > 0;
        for (var i = 0; i < apps.length; i++) known[root.historyKey(apps[i])] = true;
        var clean = {}, keys = Object.keys(parsed);
        for (var j = 0; j < keys.length; j++) {
            var v = parsed[keys[j]];
            if (hasApps && !known[keys[j]]) continue;
            if (!v || typeof v.c !== "number") continue;
            clean[keys[j]] = { c: Math.max(0, Math.min(v.c, 10000)), l: (typeof v.l === "number") ? v.l : 0 };
        }
        root.history = clean;
    }

    function saveHistory() {
        try {
            var keys = Object.keys(root.history);
            if (keys.length > 150) {
                var scored = [];
                for (var i = 0; i < keys.length; i++) {
                    var h = root.history[keys[i]];
                    scored.push([(h.c || 0) * 10000000000 + (h.l || 0), keys[i]]);
                }
                scored.sort(function(a, b) { return b[0] - a[0]; });
                var trimmed = {};
                for (var j = 0; j < 150; j++) trimmed[scored[j][1]] = root.history[scored[j][1]];
                root.history = trimmed;
            }
            root.historyFile.setText(JSON.stringify(root.history));
        } catch (err) {}
    }

    function recordLaunch(e) {
        try {
            var k = root.historyKey(e);
            if (k === "") return;
            var h = root.history[k] || { c: 0, l: 0 };
            h.c = (h.c || 0) + 1;
            h.l = Math.floor(Date.now() / 1000);
            var nh = {};
            for (var key in root.history) nh[key] = root.history[key];
            nh[k] = h;
            root.history = nh;
            root.saveHistory();
        } catch (err) {}
    }

    function stepSelection(d) {
        if (root.filtered.length === 0) return;
        root.selected = Math.max(0, Math.min(root.selected + d, root.filtered.length - 1));
    }

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
        var apps = allApps();
        if (q === "") {
            // Recents first (frecency desc), then the rest alphabetically.
            var recent = [];
            for (var i = 0; i < apps.length; i++) {
                recent.push([root.frecency(apps[i]), (apps[i].name || "").toLowerCase(), apps[i]]);
            }
            recent.sort(function(a, b) {
                if (b[0] !== a[0]) return b[0] - a[0];
                if (a[1] < b[1]) return -1;
                if (a[1] > b[1]) return 1;
                return 0;
            });
            var out = [];
            for (var j = 0; j < recent.length && j < 60; j++) out.push(recent[j][2]);
            root.filtered = out;
            root.selected = 0;
            return;
        }
        var scored = [];
        for (var k = 0; k < apps.length; k++) {
            var s = root.score(apps[k], q);
            if (s < 0) continue;
            // Small frecency tie-break so often-used matches float up
            // without beating clearly better text matches (max +12).
            s += Math.min(root.frecency(apps[k]), 24) * 0.5;
            scored.push([s, apps[k]]);
        }
        scored.sort(function(a, b) { return b[0] - a[0]; });
        var out2 = [];
        for (var m = 0; m < scored.length && m < 60; m++) out2.push(scored[m][1]);
        root.filtered = out2;
        root.selected = 0;
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function launchEntry(e) {
        if (!e) return;
        if (e.runInTerminal) {
            var cmd = (e.command && e.command.length > 0) ? e.command : ["sh", "-c", e.execString];
            var workdir = (e.workingDirectory && e.workingDirectory !== "") ? e.workingDirectory : null;
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

    function launchCurrent() {
        if (root.filtered.length === 0) {
            Qt.quit();
            return;
        }
        var entry = root.filtered[Math.min(root.selected, root.filtered.length - 1)];
        root.recordLaunch(entry);
        root.launchEntry(entry);
        Qt.quit();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.historyDir]);
        root.loadHistory();
        root.refilter();
    }

    Connections {
        target: DesktopEntries
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
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { Qt.quit(); e.accepted = true; }
                else if (e.key === Qt.Key_Down) { root.stepSelection(1); e.accepted = true; }
                else if (e.key === Qt.Key_Up) { root.stepSelection(-1); e.accepted = true; }
                else if (e.key === Qt.Key_PageDown) { root.stepSelection(8); e.accepted = true; }
                else if (e.key === Qt.Key_PageUp) { root.stepSelection(-8); e.accepted = true; }
                else if (e.key === Qt.Key_Home) { root.selected = 0; e.accepted = true; }
                else if (e.key === Qt.Key_End) { root.selected = Math.max(0, root.filtered.length - 1); e.accepted = true; }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launchCurrent(); e.accepted = true; }
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
                                if (e.key === Qt.Key_Down) { root.stepSelection(1); e.accepted = true; }
                                else if (e.key === Qt.Key_Up) { root.stepSelection(-1); e.accepted = true; }
                                else if (e.key === Qt.Key_PageDown) { root.stepSelection(8); e.accepted = true; }
                                else if (e.key === Qt.Key_PageUp) { root.stepSelection(-8); e.accepted = true; }
                                else if (e.key === Qt.Key_Home) { root.selected = 0; e.accepted = true; }
                                else if (e.key === Qt.Key_End) { root.selected = Math.max(0, root.filtered.length - 1); e.accepted = true; }
                                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.launchCurrent(); e.accepted = true; }
                                else if (e.key === Qt.Key_Escape) { Qt.quit(); e.accepted = true; }
                            }
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
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    onCurrentIndexChanged: { if (count > 0 && currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain); }
                    onCountChanged: { if (count > 0) positionViewAtBeginning(); }
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
                            onClicked: { root.selected = index; root.launchCurrent(); }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.filtered.length + " apps  •  Enter launch  •  Esc close"
                    color: root.theme.textSub; font.family: root.theme.fontFam; font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
