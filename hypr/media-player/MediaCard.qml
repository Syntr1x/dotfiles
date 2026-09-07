import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets

Item {
    id: root
    width: 410
    height: 116

    property string manualDbus: ""

    // Theme accent, fed from shell.qml (live waybar bordercolor).
    // Falls back to Beige to fit most themes
    property string accent: "#fed79d"
    property string accentFg: "#171717"

    readonly property var allPlayers: Mpris.players.values

    function playerIndex(): int {
        const vals = Mpris.players.values;
        for (let i = 0; i < vals.length; ++i)
            if (player && vals[i].dbusName === player.dbusName)
                return i;
        return 0;
    }

    function pickAuto(): var {
        const vals = Mpris.players.values;
        if (!vals || vals.length === 0)
            return null;
        for (let i = 0; i < vals.length; ++i) {
            if (vals[i].isPlaying)
                return vals[i];
        }
        for (let i = 0; i < vals.length; ++i) {
            if (vals[i].playbackState === MprisPlaybackState.Paused)
                return vals[i];
        }
        return vals[0];
    }

    readonly property var autoPlayer: pickAuto()

    // If the manually picked player vanished, fall back to auto.
    readonly property var player: {
        const vals = Mpris.players.values;
        if (root.manualDbus !== "") {
            for (let i = 0; i < vals.length; ++i) {
                if (vals[i].dbusName === root.manualDbus)
                    return vals[i];
            }
        }
        return root.autoPlayer;
    }

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isPlaying: hasPlayer ? player.isPlaying : false

    readonly property string title: hasPlayer && player.trackTitle !== "" ? player.trackTitle : (hasPlayer ? "Unknown Title" : "Nothing playing")
    readonly property string artist: hasPlayer && player.trackArtist !== "" ? player.trackArtist : (hasPlayer ? "Unknown Artist" : "Start some music")
    readonly property string album: hasPlayer ? player.trackAlbum : ""
    readonly property string artUrl: hasPlayer ? (player.trackArtUrl || "") : ""
    readonly property string source: hasPlayer ? (player.identity || player.dbusName || "") : ""
    readonly property int playerCount: Mpris.players.values.length

    function cyclePlayer(dir: int): void {
        const vals = Mpris.players.values;
        if (vals.length < 2)
            return;
        let idx = -1;
        for (let i = 0; i < vals.length; ++i) {
            if (player && vals[i].dbusName === player.dbusName) {
                idx = i;
                break;
            }
        }
        const next = vals[(idx + dir + vals.length) % vals.length];
        root.manualDbus = next.dbusName;
    }

    function fmt(sec: real): string {
        if (!isFinite(sec) || sec < 0)
            sec = 0;
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" + s : "" + s);
    }

    Timer {
        interval: 800
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.player)
                root.player.positionChanged();
        }
    }

    readonly property real pos: hasPlayer ? player.position : 0
    readonly property real len: (hasPlayer && player.lengthSupported) ? player.length : 0
    readonly property real progress: len > 0 ? Math.min(1, Math.max(0, pos / len)) : 0
    readonly property bool seekable: hasPlayer && player.canSeek

    // card background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0.09, 0.09, 0.09, 0.88)
        border.color: root.accent
        border.width: 2
    }

    Rectangle {
        id: closeBtn
        width: 22
        height: 22
        radius: 11
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 6
        color: closeArea.containsMouse ? Qt.rgba(224, 108, 117, 0.25) : "transparent"
        Text {
            anchors.centerIn: parent
            text: "✕"
            font.pixelSize: 11
            font.family: "Fira Sans Semibold, sans-serif"
            color: closeArea.containsMouse ? "#e06c75" : "#a0a0a0"
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.quit()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.rightMargin: 16
        spacing: 12

        // album art
        ClippingRectangle {
            id: artClip
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.06)

            Image {
                anchors.fill: parent
                source: root.artUrl
                visible: root.artUrl !== ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
            }
            Text {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: "♪"
                font.pixelSize: 26
                color: root.accent
            }
        }

        // text + progress
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.title
                font.family: "Fira Sans Semibold, sans-serif"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: "#ffffff"
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                Layout.fillWidth: true
                text: root.album !== "" ? root.artist + "  •  " + root.album : root.artist
                font.family: "Fira Sans Semibold, sans-serif"
                font.pixelSize: 12
                color: "#a0a0a0"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // progress bar
            Rectangle {
                id: progBg
                Layout.fillWidth: true
                Layout.preferredHeight: 5
                Layout.topMargin: 5
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.12)
                opacity: root.hasPlayer ? 1 : 0.35

                Rectangle {
                    width: parent.width * root.progress
                    height: parent.height
                    radius: 3
                    color: root.accent
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.seekable && root.len > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const ratio = Math.min(1, Math.max(0, mouse.x / progBg.width));
                        root.player.position = root.len * ratio;
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: root.fmt(root.pos) + " / " + (root.len > 0 ? root.fmt(root.len) : "--:--")
                    font.family: "Fira Sans Semibold, monospace"
                    font.pixelSize: 10
                    color: "#a0a0a0"
                }
                Item {
                    Layout.fillWidth: true
                }
                // player switcher, only when multiple players
                RowLayout {
                    visible: root.playerCount > 1
                    spacing: 4
                    Text {
                        text: "‹"
                        font.pixelSize: 13
                        font.bold: true
                        color: prevPlayerArea.containsMouse ? root.accent : "#a0a0a0"
                        MouseArea {
                            id: prevPlayerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cyclePlayer(-1)
                        }
                    }
                    Text {
                        text: root.source + " " + (root.playerCount > 0 ? "(" + (root.playerIndex() + 1) + "/" + root.playerCount + ")" : "")
                        font.family: "Fira Sans Semibold, sans-serif"
                        font.pixelSize: 10
                        color: "#a0a0a0"
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "›"
                        font.pixelSize: 13
                        font.bold: true
                        color: nextPlayerArea.containsMouse ? root.accent : "#a0a0a0"
                        MouseArea {
                            id: nextPlayerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cyclePlayer(1)
                        }
                    }
                }
                Text {
                    visible: root.playerCount <= 1
                    text: root.source
                    font.family: "Fira Sans Semibold, sans-serif"
                    font.pixelSize: 10
                    color: "#a0a0a0"
                    elide: Text.ElideRight
                }
            }
        }

        // controls
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            // prev
            Rectangle {
                id: prevBtn
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                opacity: (root.hasPlayer && root.player.canGoPrevious) ? 1 : 0.3
                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: "Firacode Nerd Font, Fira Sans Semibold, sans-serif"
                    font.pixelSize: 17
                    color: "#ffffff"
                }
                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.hasPlayer
                    onClicked: {
                        if (root.player.canGoPrevious)
                            root.player.previous();
                    }
                }
            }

            // play / pause (accent)
            Rectangle {
                id: playBtn
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 22
                color: playArea.containsMouse ? Qt.lighter(root.accent, 1.18) : root.accent
                opacity: root.hasPlayer ? 1 : 0.4
                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: (root.isPlaying ? 0 : 1)
                    text: root.isPlaying ? "\uf04c" : "\uf04b"
                    font.family: "Firacode Nerd Font, Fira Sans Semibold, sans-serif"
                    font.pixelSize: 21
                    color: root.accentFg
                }
                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.hasPlayer
                    onClicked: {
                        if (root.player.canTogglePlaying)
                            root.player.togglePlaying();
                        else if (root.isPlaying)
                            root.player.pause();
                        else
                            root.player.play();
                    }
                }
            }

            // next
            Rectangle {
                id: nextBtn
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                opacity: (root.hasPlayer && root.player.canGoNext) ? 1 : 0.3
                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: "Firacode Nerd Font, Fira Sans Semibold, sans-serif"
                    font.pixelSize: 17
                    color: "#ffffff"
                }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.hasPlayer
                    onClicked: {
                        if (root.player.canGoNext)
                            root.player.next();
                    }
                }
            }
        }
    }
}
