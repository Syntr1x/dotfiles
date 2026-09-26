// Top bar (theme button, workspaces, media, stats, tray, power).
// Polled state lives on the Scope: one poll per subsystem, not one per screen.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Scope {
    id: barScope

    // Injected by shell.qml (untyped: directory imports carry no type info).
    property var theme
    property bool visible: true

    readonly property int barHeight: 38
    readonly property string terminal: "ghostty"

    readonly property string configDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return (xdg || (Quickshell.env("HOME") || "") + "/.config") + "/quickshell";
    }
    readonly property string themeSelectorShell: barScope.configDir + "/themeselector/shell.qml"
    readonly property string mediaToggleScript: barScope.configDir + "/media-player/toggle.sh"

    // Nerd Font glyphs as escapes so tooling cannot mangle the private-use codepoints.
    readonly property string icoTheme: "\u{f03d8}"
    readonly property string icoTerm: "\u{f120}"
    readonly property string icoBrowser: "\u{f0ac}"
    readonly property string icoFiles: "\u{f07c}"
    readonly property string icoPlay: "\u{f04b}"
    readonly property string icoPause: "\u{f04c}"
    readonly property string icoVol: "\u{f028}"
    readonly property string icoMute: "\u{f026}"
    readonly property string icoWifi: "\u{f1eb}"
    readonly property string icoEth: "\u{f0200}"
    readonly property string icoOffline: "\u{f05aa}"
    readonly property string icoCpu: "\u{f4bc}"
    readonly property string icoMem: "\u{e266}"
    readonly property string icoPower: "\u{f011}"
    readonly property string icoDate: "\u{f073}"
    readonly property string icoClock: "\u{f017}"
    readonly property string icoBatCharge: "\u{f0084}"
    readonly property var icoBat: ["\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}",
        "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0240}"]

    readonly property var quicklinks: [
        { icon: barScope.icoTerm, cmd: [barScope.terminal] },
        { icon: barScope.icoBrowser, cmd: ["sh", "-c", "$HOME/zen-browser/zen/zen || $HOME/zen/zen || zen-browser"] },
        { icon: barScope.icoFiles, cmd: ["dolphin"] }
    ]

    // Bind the default sink or its audio object never arrives.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    function _sinkAudio() {
        const sink = Pipewire.defaultAudioSink;
        if (!sink || !sink.ready) return null;
        return sink.audio || null;
    }

    property int volPollPct: -1   // -1 = unknown yet
    property bool volPollMuted: false
    readonly property int volPct: {
        const audio = barScope._sinkAudio();
        return audio === null ? barScope.volPollPct : Math.round(audio.volume * 100);
    }
    readonly property bool volMuted: {
        const audio = barScope._sinkAudio();
        return audio === null ? barScope.volPollMuted : audio.muted;
    }
    readonly property string volTxt: barScope.volPct < 0 ? "--%" : barScope.volPct + "%"

    function _wpctl(args) {
        Quickshell.execDetached(["wpctl"].concat(args));
    }
    function toggleMute() {
        const audio = barScope._sinkAudio();
        if (audio === null) barScope._wpctl(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        else audio.muted = !audio.muted;
    }
    function bumpVolume(delta) {
        const audio = barScope._sinkAudio();
        if (audio === null) {
            barScope._wpctl(["set-volume", "@DEFAULT_AUDIO_SINK@", delta > 0 ? "5%+" : "5%-"]);
            return;
        }
        audio.volume = Math.max(0, Math.min(1, audio.volume + delta));
        if (audio.muted && delta > 0) audio.muted = false;
    }
    // Ids come from the hyprctl poll: Hyprland.workspaces is an empty model here,
    // so the IPC path yields nothing. 1-5 stay pinned to keep the row stable.
    function workspaceIds(pollIds) {
        const ids = { 1: true, 2: true, 3: true, 4: true, 5: true };
        for (let i = 0; i < pollIds.length; ++i) ids[pollIds[i]] = true;
        return Object.keys(ids).map(Number).sort(function (a, b) { return a - b; });
    }
    // focusedWorkspace starts null and workspace 0 is falsy: check the id explicitly.
    function isFocusedWs(id, pollActive) {
        const focused = Hyprland.focusedWorkspace;
        if (focused && focused.id !== undefined) return focused.id === id;
        return pollActive === id;
    }
    // The Lua provider (default since 0.55) rejects the legacy "workspace N" syntax.
    function dispatchWorkspace(id) {
        if (Hyprland.usingLua) Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
        else Hyprland.dispatch("workspace " + id);
    }

    // Live first, poll as fallback: activeToplevel starts null until the first focus event.
    readonly property string liveTitle: {
        const title = (Hyprland.activeToplevel && Hyprland.activeToplevel.title) || "";
        return title.slice(0, 60);
    }
    property string pollTitle: ""
    property var pollWsIds: []
    property int pollActiveWs: -1
    readonly property string winTitle: barScope.liveTitle !== "" ? barScope.liveTitle : barScope.pollTitle

    function _autoPlayer() {
        const players = Mpris.players.values;
        if (!players || players.length === 0) return null;
        for (let i = 0; i < players.length; ++i) {
            if (players[i].isPlaying) return players[i];
        }
        return players[0];
    }
    readonly property var mediaPlayer: barScope._autoPlayer()

    property int cpuPct: -1
    property int memPct: -1
    property string netTxt: ""
    property bool netDown: false
    property int batPct: -1
    property string batState: ""
    readonly property bool batLow: barScope.batPct >= 0 && barScope.batPct <= 15
        && barScope.batState !== "Charging"
    // ceil(n/10)-1 so the bucket matches the number shown; charging wins over fill level.
    readonly property string batIcon: barScope.batState === "Charging"
        ? barScope.icoBatCharge
        : barScope.icoBat[Math.max(0, Math.min(9, Math.ceil(barScope.batPct / 10) - 1))]

    // One process per subsystem so a slow tool (nmcli) never holds up the fast ones.
    Process {
        id: hyprProc
        // Single JSON line so "|" or newlines in titles round-trip.
        command: ["bash", "-c", "python3 -c '\nimport json, subprocess\ndef j(*a):\n    try:\n        return json.loads(subprocess.check_output(a, text=True, timeout=2))\n    except Exception:\n        return {}\nprint(json.dumps({\"ws\": sorted(w[\"id\"] for w in j(\"hyprctl\", \"workspaces\", \"-j\") if \"id\" in w), \"active\": j(\"hyprctl\", \"activeworkspace\", \"-j\").get(\"id\", -1), \"title\": (j(\"hyprctl\", \"activewindow\", \"-j\").get(\"title\") or \"\")[:60]}))\n' 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: barScope._hyprSample(text.trim()) }
    }
    Process {
        id: statProc
        // jiffies are diffed here, so the two reads must be a poll apart.
        command: ["bash", "-c", "awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5+$6+$7+$8} /^MemTotal:/{mt=$2} /^MemAvailable:/{ma=$2} END{printf \"%d %d %d\\n\", u, t, (mt?int((mt-ma)*100/mt):0)}' /proc/stat /proc/meminfo"]
        stdout: StdioCollector { onStreamFinished: barScope._statSample(text.trim()) }
    }
    Process {
        id: hwProc
        // Line 1: active nmcli connection. Line 2: "capacity:status".
        // System batteries only (scope=System): peripheral "Batteries" (e.g. a wireless
        // mouse) must not drive the pill, so towers show none. No scope attr: accept.
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE,NAME c show --active 2>/dev/null | grep -m1 ':activated' || echo 'none:disconnected:'; b=''; for d in /sys/class/power_supply/*/; do [ \"$(cat \"$d/type\" 2>/dev/null)\" = Battery ] || continue; s=\"$(cat \"$d/scope\" 2>/dev/null)\"; { [ -z \"$s\" ] || [ \"$s\" = System ]; } || continue; b=\"${d%/}\"; break; done; c=$(cat \"$b/capacity\" 2>/dev/null); s=$(cat \"$b/status\" 2>/dev/null); echo \"${c:-}:${s:-}\""]
        stdout: StdioCollector { onStreamFinished: barScope._hwSample(text.trim()) }
    }
    Process {
        id: volProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: barScope._volSample(text.trim()) }
    }

    function _startPolling() {
        hyprProc.running = true;
        statProc.running = true;
        hwProc.running = true;
        volProc.running = true;
    }
    Component.onCompleted: barScope._startPolling()

    Timer { interval: 1000; repeat: true; running: barScope.visible; onTriggered: hyprProc.running = true }
    Timer { interval: 2000; repeat: true; running: barScope.visible; onTriggered: statProc.running = true }
    // nmcli is by far the slowest call; 5s is plenty.
    Timer { interval: 5000; repeat: true; running: barScope.visible; onTriggered: hwProc.running = true }
    Timer {
        interval: 2000; repeat: true; running: barScope.visible
        onTriggered: { if (barScope._sinkAudio() === null) volProc.running = true; }
    }

    function _hyprSample(line) {
        let sample;
        try { sample = JSON.parse(line); } catch (err) { return; }
        if (Array.isArray(sample.ws)) barScope.pollWsIds = sample.ws;
        if (typeof sample.active === "number") barScope.pollActiveWs = sample.active;
        if (typeof sample.title === "string") barScope.pollTitle = sample.title;
    }
    property var _prevCpu: null
    function _statSample(line) {
        const p = line.split(/\s+/);
        if (p.length < 3) return;
        const busy = parseFloat(p[0]);
        const total = parseFloat(p[1]);
        if (!isNaN(busy) && !isNaN(total)) {
            if (barScope._prevCpu !== null) {
                const dBusy = busy - barScope._prevCpu[0];
                const dTotal = total - barScope._prevCpu[1];
                if (dTotal > 0) barScope.cpuPct = Math.round(dBusy / dTotal * 100);
            }
            barScope._prevCpu = [busy, total];
        }
        const mem = parseInt(p[2], 10);
        if (!isNaN(mem)) barScope.memPct = mem;
    }
    function _hwSample(text) {
        const lines = text.split("\n");
        if (lines.length > 0) barScope._netSample(lines[0].trim());
        if (lines.length > 1) barScope._batSample(lines[1].trim());
    }
    function _netSample(line) {
        // nmcli terse output is "TYPE:STATE:NAME" with ':' escaped in values.
        const m = /^(.*?):([^:]*):(.*)$/.exec(line);
        const type = m ? m[1] : "";
        const state = m ? m[2] : "";
        const name = m ? m[3].replace(/\\:/g, ":") : "";
        if (state !== "activated") {
            barScope.netTxt = barScope.icoOffline + "  off";
            barScope.netDown = true;
        } else if (/^wifi/.test(type)) {
            barScope.netTxt = barScope.icoWifi + "  " + name.slice(0, 10);
            barScope.netDown = false;
        } else {
            barScope.netTxt = barScope.icoEth + "  " + (name.slice(0, 10) || "up");
            barScope.netDown = false;
        }
    }
    function _batSample(line) {
        const p = line.split(":");
        const cap = parseInt(p[0], 10);
        if (isNaN(cap)) {
            barScope.batPct = -1;
            barScope.batState = "";
            return;
        }
        barScope.batPct = cap;
        barScope.batState = (p[1] || "").trim();
    }
    function _volSample(line) {
        const muted = /muted/i.test(line);
        const m = /(\d+)%/.exec(line) || /Volume:\s*([\d.]+)/.exec(line);
        barScope.volPollMuted = muted;
        if (m === null) {
            barScope.volPollPct = -1;
            return;
        }
        const pct = m[1].indexOf(".") >= 0 ? Math.round(parseFloat(m[1]) * 100) : parseInt(m[1], 10);
        barScope.volPollPct = muted ? 0 : pct;
    }

    // An id resolves to the first instance: pass the window in or multi-monitor menus land on the wrong bar.
    function _openTrayMenu(item, window, mouseArea) {
        const pos = mouseArea.mapToItem(window.contentItem, mouseArea.width / 2, mouseArea.height);
        item.display(window, Math.round(pos.x), Math.round(pos.y));
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: barPanel
            required property var modelData
            screen: modelData
            visible: barScope.visible

            anchors { top: true; left: true; right: true }
            implicitHeight: barScope.barHeight
            exclusiveZone: barScope.visible ? barScope.barHeight : 0
            color: "transparent"

            SystemClock { id: clock; precision: SystemClock.Seconds }

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 96; radius: barScope.theme.radius
                        color: themeHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.icoTheme + "  Theme"; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 13; font.bold: true }
                        MouseArea { id: themeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["qs", "-p", barScope.themeSelectorShell]) }
                    }
                    Repeater {
                        model: barScope.quicklinks
                        delegate: Rectangle {
                            id: quicklink
                            required property var modelData
                            Layout.preferredHeight: 30; Layout.preferredWidth: 42; radius: barScope.theme.radius
                            color: quicklinkHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                            Text { anchors.centerIn: parent; text: quicklink.modelData.icon; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 15 }
                            MouseArea { id: quicklinkHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(quicklink.modelData.cmd) }
                        }
                    }
                    Rectangle {
                        visible: barScope.winTitle !== ""
                        Layout.preferredHeight: 30; Layout.maximumWidth: 360; Layout.preferredWidth: titleTxt.implicitWidth + 28; radius: barScope.theme.radius
                        color: barScope.theme.moduleBg
                        Text { id: titleTxt; anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; verticalAlignment: Text.AlignVCenter
                            text: barScope.winTitle; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12; elide: Text.ElideRight }
                    }
                }

                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        Layout.preferredHeight: 30; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Layout.preferredWidth: wsRow.implicitWidth + 8
                        RowLayout { id: wsRow; anchors.centerIn: parent; spacing: 4
                            Repeater {
                                model: barScope.workspaceIds(barScope.pollWsIds)
                                delegate: Rectangle {
                                    required property var modelData
                                    property int wsId: modelData
                                    property bool isActive: barScope.isFocusedWs(wsId, barScope.pollActiveWs)
                                    Layout.preferredHeight: 26; Layout.preferredWidth: isActive ? 34 : 28; radius: 9
                                    color: isActive ? barScope.theme.accent : "transparent"
                                    Text { anchors.centerIn: parent; text: wsId; color: isActive ? barScope.theme.accentFg : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 13; font.bold: isActive }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: barScope.dispatchWorkspace(wsId) }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 42; radius: barScope.theme.radius
                        color: mediaHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        // left click: popup, right click: play/pause
                        Text { anchors.centerIn: parent; text: (barScope.mediaPlayer && barScope.mediaPlayer.isPlaying) ? barScope.icoPause : barScope.icoPlay; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 13 }
                        MouseArea { id: mediaHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    const player = barScope.mediaPlayer;
                                    if (!player) return;
                                    if (player.canTogglePlaying) player.togglePlaying();
                                    else if (player.isPlaying) player.pause();
                                    else player.play();
                                } else {
                                    Quickshell.execDetached(["bash", barScope.mediaToggleScript]);
                                }
                            } }
                    }
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // volume: left = mute toggle, right = mixer, wheel = level
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 78; radius: barScope.theme.radius
                        color: volHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: (barScope.volMuted ? barScope.icoMute : barScope.icoVol) + " " + barScope.volTxt; color: barScope.volMuted ? barScope.theme.textSub : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                        MouseArea { id: volHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    barScope.toggleMute();
                                } else {
                                    Quickshell.execDetached(["pwvucontrol"]);
                                }
                            }
                            onWheel: wheel => {
                                barScope.bumpVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                            } }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.maximumWidth: 150; Layout.preferredWidth: netTxt.implicitWidth + 28; radius: barScope.theme.radius
                        color: netHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { id: netTxt; anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; verticalAlignment: Text.AlignVCenter
                            text: barScope.netTxt; color: barScope.netDown ? barScope.theme.red : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12; elide: Text.ElideRight }
                        MouseArea { id: netHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([barScope.terminal, "-e", "nmtui"]) }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 78; radius: barScope.theme.radius
                        color: cpuHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.icoCpu + "  " + (barScope.cpuPct < 0 ? "--%" : barScope.cpuPct + "%"); color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                        MouseArea { id: cpuHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([barScope.terminal, "-e", "btop"]) }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 68; radius: barScope.theme.radius
                        color: memHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.icoMem + "  " + (barScope.memPct < 0 ? "--%" : barScope.memPct + "%"); color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                        MouseArea { id: memHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([barScope.terminal, "-e", "btop"]) }
                    }
                    Rectangle {
                        visible: barScope.batPct >= 0
                        Layout.preferredHeight: 30; Layout.preferredWidth: 72; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.batIcon + " " + barScope.batPct + "%"; color: barScope.batLow ? barScope.theme.red : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 214; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.icoDate + "  " + Qt.formatDateTime(clock.date, "ddd MMM dd") + "    " + barScope.icoClock + "  " + Qt.formatDateTime(clock.date, "hh:mm"); color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12; font.bold: true }
                    }
                    Rectangle {
                        visible: trayRow.count > 0
                        Layout.preferredHeight: 30; Layout.preferredWidth: trayRow.implicitWidth + 16; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        RowLayout { id: trayRow; anchors.centerIn: parent; spacing: 4
                            readonly property int count: SystemTray.items.values.length
                            Repeater {
                                model: SystemTray.items.values
                                delegate: Rectangle {
                                    id: trayItem
                                    required property var modelData
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7
                                    color: trayMouse.containsMouse ? barScope.theme.moduleBgHover : "transparent"
                                    IconImage {
                                        id: trayIcon
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        source: trayItem.modelData.icon
                                        smooth: true
                                    }
                                    // SNI apps that ship no icon fall back to initials
                                    Text {
                                        anchors.centerIn: parent
                                        visible: trayIcon.status !== Image.Ready && trayIcon.status !== Image.Loading
                                        text: (trayItem.modelData.title || trayItem.modelData.id || "?").charAt(0).toUpperCase()
                                        color: barScope.theme.textSub; font.family: barScope.theme.fontFam; font.pixelSize: 11; font.bold: true
                                    }
                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            const item = trayItem.modelData;
                                            if (mouse.button === Qt.MiddleButton) item.secondaryActivate();
                                            else if (mouse.button === Qt.RightButton) {
                                                if (item.hasMenu) barScope._openTrayMenu(item, barPanel, trayMouse);
                                                else item.secondaryActivate();
                                            } else if (item.onlyMenu && item.hasMenu) barScope._openTrayMenu(item, barPanel, trayMouse);
                                            else item.activate();
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 42; radius: barScope.theme.radius
                        color: exitHover.containsMouse ? Qt.alpha(barScope.theme.red, 0.15) : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.icoPower; color: exitHover.containsMouse ? barScope.theme.red : barScope.theme.textSub; font.family: barScope.theme.fontFam; font.pixelSize: 14 }
                        MouseArea { id: exitHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["wlogout", "-b", "3"]) }
                    }
                }
            }
        }
    }
}
