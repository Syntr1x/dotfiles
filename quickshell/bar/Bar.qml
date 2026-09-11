// Bar — quickshell top bar. Left: theme btn, quicklinks, window title.
// Center: workspaces (1-5 persistent, sorted) + media toggle.
// Right: volume (Pipewire + slider popup), network, cpu, mem, battery,
// clock, tray, power. Accent + pills follow quickshell/accent.conf.
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
    property var theme
    property bool visible: true

    readonly property string icoTheme: "󰏘"
    readonly property string icoTerm: ""
    readonly property string icoBrowser: ""
    readonly property string icoFiles: ""
    readonly property string icoPlay: ""
    readonly property string icoPause: ""
    readonly property string icoVol: ""
    readonly property string icoMute: ""
    readonly property string icoWifi: ""
    readonly property string icoEth: ""
    readonly property string icoOffline: ""
    readonly property string icoCpu: ""
    readonly property string icoMem: ""
    readonly property string icoPower: ""
    readonly property var icoBat: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    readonly property string icoBatCharge: "󰂄"
    readonly property string mediaToggleScript: (Quickshell.env("HOME") || "") + "/.config/quickshell/media-player/toggle.sh"

    // Pipewire live audio (preferred); polling fallback when null
    property var audioSink: Pipewire.defaultAudioSink
    property var sinkAudio: audioSink ? audioSink.audio : null
    property bool pwReady: sinkAudio !== null && sinkAudio !== undefined
    property bool volPopupOpen: false

    // Bind the default sink so volume/mute are tracked.
    // Without this the node stays unbound and audio stays null.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    // Sorted workspace ids, 1-5 always present.
    // Live IPC first (currently empty on Hyprland 0.56 here), poll fallback.
    function workspaceIds(pollIds) {
        var ids = {};
        var i;
        try {
            var ws = Hyprland.workspaces;
            var n = (ws && ws.count !== undefined) ? ws.count : (ws && ws.values ? ws.values.length : 0);
            for (i = 0; i < n; i++) {
                var w = ws.get ? ws.get(i) : (ws.values ? ws.values[i] : ws[i]);
                if (w && w.id !== undefined) ids[w.id] = true;
            }
        } catch (e) {}
        for (i = 0; pollIds && i < pollIds.length; i++) ids[pollIds[i]] = true;
        for (i = 1; i <= 5; i++) ids[i] = true;
        var out = Object.keys(ids).map(function(k) { return parseInt(k, 10); });
        out.sort(function(a, b) { return a - b; });
        return out;
    }
    function isFocusedWs(id, pollActive) {
        try {
            // live IPC wins when the compositor provides it
            if (Hyprland.focusedWorkspace) return Hyprland.focusedWorkspace.id === id;
        } catch (e) {}
        return pollActive === id;
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: barScope.visible

            anchors { top: true; left: true; right: true }
            implicitHeight: 38
            exclusiveZone: barScope.visible ? 38 : 0
            color: "transparent"

            property string cpuTxt: " --%"
            property string memTxt: " --%"
            property string netTxt: " --%"
            property bool netDown: false
            property string batTxt: ""
            property string batIcon: ""
            property bool batLow: false
            // polling fallback only (Pipewire preferred)
            property string volPollTxt: "--%"
            property bool volPollMuted: false
            // live title: event-driven via Hyprland IPC (instant on focus
            // change AND in-window title change, e.g. browser tabs).
            // Falls back to hyprctl polling: this compositor currently
            // reports no toplevels over IPC (activeToplevel stays null),
            // so the poll keeps the title working until that is fixed.
            property string liveTitle: {
                var t = (Hyprland.activeToplevel && Hyprland.activeToplevel.title) || "";
                return t.slice(0, 60);
            }
            property string pollTitle: ""
            property var pollWsIds: []
            property int pollActiveWs: -1
            property string winTitle: liveTitle !== "" ? liveTitle : pollTitle
            // live player: re-evaluates when Mpris players change
            property var mediaPlayer: barScope._autoPlayer()

            // live volume display: Pipewire wins, else poll result
            property string volTxt: {
                if (barScope.pwReady) return Math.round(barScope.sinkAudio.volume * 100) + "%";
                return win.volPollTxt;
            }
            property bool volMuted: {
                if (barScope.pwReady) return barScope.sinkAudio.muted;
                return win.volPollMuted;
            }

            SystemClock { id: clock; precision: SystemClock.Seconds }

            Process {
                id: cpuProc
                command: ["bash", "-c", "grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$3+$4+$5+$6+$7+$8; print u\" \"t}'"]
                stdout: StdioCollector { onStreamFinished: barScope._cpuSample(text.trim(), win) }
            }
            Process {
                id: memProc
                command: ["bash", "-c", "LC_ALL=C free | awk '/Mem:/ {printf \"%d\", $3/$2*100}'"]
                stdout: StdioCollector { onStreamFinished: win.memTxt = barScope.icoMem + " " + text.trim() + "%" }
            }
            Process {
                id: netProc
                command: ["bash", "-c", "nmcli -t -f TYPE,STATE,NAME c show --active 2>/dev/null | grep -m1 ':activated' || echo 'none:disconnected:'"]
                stdout: StdioCollector { onStreamFinished: barScope._netSample(text.trim(), win) }
            }
            Process {
                id: batProc
                command: ["bash", "-c", "c=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); s=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); echo \"${c:-}:${s:-}\""]
                stdout: StdioCollector { onStreamFinished: barScope._batSample(text.trim(), win) }
            }
            Process {
                id: volProc
                command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -n1"]
                stdout: StdioCollector { onStreamFinished: barScope._volSample(text.trim(), win) }
            }
            // one poll covers title + workspaces + highlight (1s)
            Process {
                id: stateProc
                command: ["bash", "-c", "python3 -c '\nimport json, subprocess\ntry:\n    ws = json.loads(subprocess.check_output([\"hyprctl\", \"workspaces\", \"-j\"], text=True))\n    ids = sorted(w[\"id\"] for w in ws)\nexcept Exception:\n    ids = []\ntry:\n    aws = json.loads(subprocess.check_output([\"hyprctl\", \"activeworkspace\", \"-j\"], text=True))\n    active = aws.get(\"id\", -1)\nexcept Exception:\n    active = -1\ntry:\n    win = json.loads(subprocess.check_output([\"hyprctl\", \"activewindow\", \"-j\"], text=True))\n    title = (win.get(\"title\") or \"\")[:60]\nexcept Exception:\n    title = \"\"\nprint(str(active) + \"|\" + \" \".join(map(str, ids)) + \"|\" + title)\n' 2>/dev/null || echo '-1||'"]
                stdout: StdioCollector { onStreamFinished: barScope._stateSample(text.trim(), win) }
            }
            Timer { interval: 2000; running: true; repeat: true; onTriggered: { cpuProc.running = true; memProc.running = true; if (!barScope.pwReady) volProc.running = true; } }
            Timer { interval: 5000; running: true; repeat: true; onTriggered: { netProc.running = true; batProc.running = true; } }
            Timer { interval: 1000; running: true; repeat: true; onTriggered: stateProc.running = true }
            Component.onCompleted: { cpuProc.running = true; memProc.running = true; netProc.running = true; batProc.running = true; volProc.running = true; stateProc.running = true; }

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                // ---------- LEFT ----------
                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 96; radius: barScope.theme.radius
                        color: appHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.icoTheme + "  Theme"; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 13; font.bold: true }
                        MouseArea { id: appHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["qs", "-p", (Quickshell.env("HOME") || "") + "/.config/quickshell/themeselector/shell.qml"]) }
                    }
                    Repeater {
                        model: [
                            { icon: barScope.icoTerm, cmd: ["ghostty"] },
                            { icon: barScope.icoBrowser, cmd: ["sh", "-c", "$HOME/zen-browser/zen/zen || $HOME/zen/zen || zen-browser"] },
                            { icon: barScope.icoFiles, cmd: ["dolphin"] }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.preferredHeight: 30; Layout.preferredWidth: 42; radius: barScope.theme.radius
                            color: qlHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                            Text { anchors.centerIn: parent; text: parent.modelData.icon; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 15 }
                            MouseArea { id: qlHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(parent.modelData.cmd) }
                        }
                    }
                    Rectangle {
                        visible: win.winTitle !== ""
                        Layout.preferredHeight: 30; Layout.maximumWidth: 360; Layout.preferredWidth: titleTxt.implicitWidth + 28; radius: barScope.theme.radius
                        color: barScope.theme.moduleBg
                        Text { id: titleTxt; anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; verticalAlignment: Text.AlignVCenter
                            text: win.winTitle; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12; elide: Text.ElideRight }
                    }
                }

                // ---------- CENTER ----------
                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        Layout.preferredHeight: 30; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Layout.preferredWidth: wsRow.implicitWidth + 8
                        RowLayout { id: wsRow; anchors.centerIn: parent; spacing: 4
                            Repeater {
                                model: barScope.workspaceIds(win.pollWsIds)
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    property int wsId: modelData
                                    property bool isActive: barScope.isFocusedWs(wsId, win.pollActiveWs)
                                    Layout.preferredHeight: 26; Layout.preferredWidth: isActive ? 34 : 28; radius: 9
                                    color: isActive ? barScope.theme.accent : "transparent"
                                    Text { anchors.centerIn: parent; text: wsId; color: isActive ? barScope.theme.accentFg : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 13; font.bold: isActive }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: Hyprland.dispatch("workspace " + wsId) }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 42; radius: barScope.theme.radius
                        color: mediaHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: (win.mediaPlayer && win.mediaPlayer.isPlaying) ? barScope.icoPause : barScope.icoPlay; color: barScope.theme.textCol; font.pixelSize: 13 }
                        MouseArea { id: mediaHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    var p = win.mediaPlayer;
                                    if (p) { if (p.canTogglePlaying) p.togglePlaying(); else if (p.isPlaying) p.pause(); else p.play(); }
                                } else {
                                    Quickshell.execDetached(["bash", barScope.mediaToggleScript]);
                                }
                            } }
                    }
                }

                // ---------- RIGHT ----------
                RowLayout {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // volume: left = mute toggle, right = mixer, wheel = level, popup slider
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 78; radius: barScope.theme.radius
                        color: volHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: (win.volMuted ? barScope.icoMute : barScope.icoVol) + " " + win.volTxt; color: win.volMuted ? barScope.theme.textSub : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                        MouseArea { id: volHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                                    Quickshell.execDetached(["pwvucontrol"]);
                                } else {
                                    barScope.toggleMute();
                                    barScope.volPopupOpen = true;
                                    volPopupTimer.restart();
                                }
                            }
                            onWheel: wheel => {
                                barScope.bumpVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                                barScope.volPopupOpen = true;
                                volPopupTimer.restart();
                            } }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 78; radius: barScope.theme.radius
                        color: netHover.containsMouse ? barScope.theme.moduleBgHover : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: win.netTxt; color: win.netDown ? barScope.theme.red : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                        MouseArea { id: netHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["ghostty", "-e", "nmtui"]) }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 78; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: win.cpuTxt; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"]) }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 68; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: win.memTxt; color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"]) }
                    }
                    Rectangle {
                        visible: win.batTxt !== ""
                        Layout.preferredHeight: 30; Layout.preferredWidth: 72; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: win.batIcon + " " + win.batTxt; color: win.batLow ? barScope.theme.red : barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12 }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 196; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: "  " + Qt.formatDateTime(clock.date, "ddd MMM dd     hh:mm"); color: barScope.theme.textCol; font.family: barScope.theme.fontFam; font.pixelSize: 12; font.bold: true }
                    }
                    Rectangle {
                        visible: trayRow.count > 0
                        Layout.preferredHeight: 30; Layout.preferredWidth: trayRow.implicitWidth + 16; radius: barScope.theme.radius; color: barScope.theme.moduleBg
                        RowLayout { id: trayRow; anchors.centerIn: parent; spacing: 4
                            property int count: (typeof SystemTray !== "undefined" && SystemTray.items) ? SystemTray.items.values.length : 0
                            Repeater {
                                model: (typeof SystemTray !== "undefined" && SystemTray.items) ? SystemTray.items.values : []
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7
                                    color: trayMouse.containsMouse ? barScope.theme.moduleBgHover : "transparent"
                                    IconImage {
                                        id: trayIcon
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        source: parent.modelData.icon
                                        smooth: true
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: trayIcon.status !== Image.Ready && trayIcon.status !== Image.Loading
                                        text: (parent.modelData.title || parent.modelData.id || "?").charAt(0).toUpperCase()
                                        color: barScope.theme.textSub; font.family: barScope.theme.fontFam; font.pixelSize: 11; font.bold: true
                                    }
                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            var item = parent.modelData;
                                            if (!item) return;
                                            if (mouse.button === Qt.LeftButton) {
                                                if (item.onlyMenu && item.hasMenu) barScope._openTrayMenu(item, trayMouse, win);
                                                else item.activate();
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                item.secondaryActivate();
                                            } else {
                                                if (item.hasMenu) barScope._openTrayMenu(item, trayMouse, win);
                                                else item.secondaryActivate();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredHeight: 30; Layout.preferredWidth: 42; radius: barScope.theme.radius
                        color: exitHover.containsMouse ? Qt.rgba(224 / 255, 108 / 255, 117 / 255, 0.15) : barScope.theme.moduleBg
                        Text { anchors.centerIn: parent; text: barScope.icoPower; color: exitHover.containsMouse ? barScope.theme.red : barScope.theme.textSub; font.pixelSize: 14 }
                        MouseArea { id: exitHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["wlogout", "-b", "3"]) }
                    }
                }
            }

            // auto-hide timer for the volume popup
            Timer { id: volPopupTimer; interval: 2500; onTriggered: barScope.volPopupOpen = false }
        }
    }

    // Volume slider popup in its own Variants: a hidden PanelWindow must not
    // share a Variants with the bar — quickshell then maps neither, silently.
    Variants {
        model: Quickshell.screens
        // volume slider popup (primary screen only, below the bar)
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: barScope.visible && barScope.volPopupOpen && modelData === Quickshell.screens[0]
            anchors { top: true; right: true }
            margins { top: 46; right: 10 }
            implicitWidth: 220
            implicitHeight: 52
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: barScope.theme.radius
                color: Qt.rgba(20 / 255, 20 / 255, 22 / 255, 0.95)
                border.color: Qt.alpha(barScope.theme.accent, 0.5)
                border.width: 1
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10
                    Text {
                        text: barScope.pwReady && barScope.sinkAudio.muted ? barScope.icoMute : barScope.icoVol
                        color: barScope.theme.textCol; font.pixelSize: 14
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: barScope.toggleMute() }
                    }
                    Rectangle {
                        id: sliderBg
                        Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                        color: Qt.rgba(255, 255, 255, 0.12)
                        Rectangle {
                            width: parent.width * (barScope.pwReady ? barScope.sinkAudio.volume : 0)
                            height: parent.height; radius: 3
                            color: barScope.theme.accent
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => barScope.setVolume(mouse.x / sliderBg.width)
                            onPositionChanged: mouse => { if (pressed) barScope.setVolume(mouse.x / sliderBg.width); }
                        }
                    }
                    Text {
                        text: (barScope.pwReady ? Math.round(barScope.sinkAudio.volume * 100) : -1) >= 0 ? Math.round(barScope.sinkAudio.volume * 100) + "%" : "--"
                        color: barScope.theme.textSub; font.family: barScope.theme.fontFam; font.pixelSize: 11
                        Layout.preferredWidth: 36
                    }
                }
            }
        }
    }

    // ---- volume backends ----
    function toggleMute() {
        if (barScope.pwReady) {
            barScope.sinkAudio.muted = !barScope.sinkAudio.muted;
        } else {
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        }
    }
    function bumpVolume(delta) {
        if (barScope.pwReady) {
            var v = Math.max(0, Math.min(1, barScope.sinkAudio.volume + delta));
            barScope.sinkAudio.volume = v;
            if (barScope.sinkAudio.muted && delta > 0) barScope.sinkAudio.muted = false;
        } else {
            var pct = delta > 0 ? "5%+" : "5%-";
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct]);
        }
    }
    function setVolume(ratio) {
        var v = Math.max(0, Math.min(1, ratio));
        if (barScope.pwReady) {
            barScope.sinkAudio.volume = v;
            if (barScope.sinkAudio.muted && v > 0) barScope.sinkAudio.muted = false;
        } else {
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(v * 100) + "%"]);
        }
    }

    // ---- poll parsers ----
    property var _prevCpu: null
    function _stateSample(line, win) {
        // format: activeWsId|id id id|window title (title may contain |)
        var i1 = line.indexOf("|");
        if (i1 < 0) return;
        var i2 = line.indexOf("|", i1 + 1);
        if (i2 < 0) return;
        win.pollActiveWs = parseInt(line.slice(0, i1), 10) || -1;
        var ids = line.slice(i1 + 1, i2).trim();
        win.pollWsIds = ids === "" ? [] : ids.split(/\s+/).map(function(x) { return parseInt(x, 10); });
        win.pollTitle = line.slice(i2 + 1).trim();
    }
    function _cpuSample(line, win) {
        var p = line.split(" ");
        if (p.length < 2) return;
        var u = parseFloat(p[0]), t = parseFloat(p[1]);
        if (_prevCpu) {
            var du = u - _prevCpu[0], dt = t - _prevCpu[1];
            if (dt > 0) win.cpuTxt = barScope.icoCpu + "  " + Math.round(du / dt * 100) + "%";
        }
        _prevCpu = [u, t];
    }
    function _netSample(line, win) {
        if (line.indexOf("wifi:activated") === 0) {
            win.netTxt = barScope.icoWifi + "  " + (line.split(":")[2] || "wifi").slice(0, 10);
            win.netDown = false;
        } else if (line.indexOf("ethernet:activated") === 0 || line.indexOf("802-3-ethernet:activated") === 0) {
            win.netTxt = barScope.icoEth + "  eth";
            win.netDown = false;
        } else if (line.indexOf("disconnected") >= 0 || line.indexOf("none:") === 0) {
            win.netTxt = barScope.icoOffline + "  off";
            win.netDown = true;
        } else {
            win.netTxt = barScope.icoEth + "  up";
            win.netDown = false;
        }
    }
    function _batSample(line, win) {
        var p = line.split(":");
        if (!p[0]) { win.batTxt = ""; return; }
        var cap = parseInt(p[0], 10), st = (p[1] || "").trim();
        win.batTxt = cap + "%";
        win.batIcon = (st === "Charging") ? barScope.icoBatCharge : barScope.icoBat[Math.max(0, Math.min(9, Math.floor(cap / 10)))];
        win.batLow = cap <= 15 && st !== "Charging";
    }
    function _volSample(line, win) {
        var muted = /muted/i.test(line);
        var m = /(\d+)%/.exec(line) || /Volume:\s*([\d.]+)/.exec(line);
        win.volPollMuted = muted;
        if (m) {
            var v = m[1].indexOf(".") >= 0 ? Math.round(parseFloat(m[1]) * 100) : parseInt(m[1], 10);
            win.volPollTxt = muted ? "muted" : v + "%";
        } else {
            win.volPollTxt = muted ? "muted" : "--%";
        }
    }
    function _autoPlayer() {
        if (typeof Mpris === "undefined" || !Mpris.players) return null;
        var vals = Mpris.players.values;
        if (!vals || vals.length === 0) return null;
        for (var i = 0; i < vals.length; i++) if (vals[i].isPlaying) return vals[i];
        return vals[0];
    }
    function _openTrayMenu(item, mouseArea, win) {
        try {
            var p = mouseArea.mapToItem(win.contentItem, mouseArea.width / 2, mouseArea.height);
            item.display(win, Math.round(p.x), Math.round(p.y));
        } catch (e) {
            console.warn("tray menu failed for", item && (item.id || item.title), e);
            try { item.secondaryActivate(); } catch (e2) {}
        }
    }
}
