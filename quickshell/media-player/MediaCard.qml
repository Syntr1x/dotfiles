import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets

Item {
    id: root
    property real uiScale: 1.0
    function px(v) { return Math.round(v * uiScale); }
    width: px(410)
    height: px(116)

    property string accent: "#fed79d"
    property string accentFg: "#171717"

    readonly property string fontFam: "Inter"
    readonly property string iconFam: "Symbols Nerd Font"

    property string manualDbus: ""

    // Collapse players that expose the same app under multiple names.
    readonly property var players: {
        const all = Mpris.players.values;
        if (!all) return [];
        const norm = s => String(s || "").toLowerCase().replace(/[^a-z0-9]/g, "");
        const seen = {};
        const out = [];
        for (let i = 0; i < all.length; ++i) {
            const p = all[i];
            const keys = [norm(p.identity)];
            const dbn = String(p.dbusName || "");
            keys.push(norm(dbn.indexOf(".") >= 0 ? dbn.slice(dbn.lastIndexOf(".") + 1) : dbn));
            const good = keys.filter(k => k !== "" && k !== "mediaplayer2" && k !== "mpris");
            let at = -1;
            for (let k = 0; k < good.length && at < 0; ++k) {
                if (seen[good[k]] !== undefined) at = seen[good[k]];
            }
            if (at < 0) {
                out.push(p);
                for (let k = 0; k < good.length; ++k)
                    if (seen[good[k]] === undefined) seen[good[k]] = out.length - 1;
            } else if ((p.isPlaying ? 1 : 0) > (out[at].isPlaying ? 1 : 0)) {
                out[at] = p;
            }
        }
        return out;
    }

    function pickAuto() {
        const all = root.players;
        if (!all || all.length === 0) return null;
        for (let i = 0; i < all.length; ++i) {
            if (all[i].isPlaying) return all[i];
        }
        for (let i = 0; i < all.length; ++i) {
            if (all[i].playbackState === MprisPlaybackState.Paused) return all[i];
        }
        return all[0];
    }

    readonly property var autoPlayer: root.pickAuto()

    readonly property var player: {
        if (root.manualDbus === "") return root.autoPlayer;
        for (let i = 0; i < root.players.length; ++i) {
            if (root.players[i].dbusName === root.manualDbus) return root.players[i];
        }
        return root.autoPlayer;
    }

    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property bool isPlaying: root.hasPlayer && root.player.isPlaying
    readonly property bool positionSupported: root.hasPlayer && root.player.positionSupported

    readonly property string title: !root.hasPlayer ? "Nothing playing"
        : (root.player.trackTitle !== "" ? root.player.trackTitle : "Unknown Title")
    readonly property string artist: !root.hasPlayer ? "Start some music"
        : (root.player.trackArtist !== "" ? root.player.trackArtist : "Unknown Artist")
    readonly property string album: root.hasPlayer ? root.player.trackAlbum : ""
    readonly property string artUrl: root.hasPlayer ? (root.player.trackArtUrl || "") : ""
    readonly property string source: root.hasPlayer ? (root.player.identity || root.player.dbusName || "") : ""

    readonly property int playerIndex: {
        if (!root.hasPlayer) return -1;
        for (let i = 0; i < root.players.length; ++i) {
            if (root.players[i].dbusName === root.player.dbusName) return i;
        }
        return -1;
    }

    function cyclePlayer(dir) {
        if (root.players.length < 2) return;
        const from = root.playerIndex < 0 ? 0 : root.playerIndex;
        root.manualDbus = root.players[(from + dir + root.players.length) % root.players.length].dbusName;
    }

    function fmt(sec) {
        const total = isFinite(sec) && sec > 0 ? Math.floor(sec) : 0;
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" + s : "" + s);
    }

    function seekTo(ratio) {
        if (!root.seekable) return;
        root.player.position = root.length * Math.min(1, Math.max(0, ratio));
    }

    // position is pull-based; emit positionChanged to refresh it.
    Timer {
        interval: 800
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.hasPlayer) root.player.positionChanged();
        }
    }

    readonly property real position: root.positionSupported ? root.player.position : 0
    readonly property real length: root.hasPlayer && root.player.lengthSupported ? root.player.length : 0
    readonly property real progress: root.length > 0
        ? Math.min(1, Math.max(0, root.position / root.length)) : 0
    readonly property bool seekable: root.hasPlayer && root.player.canSeek
        && root.positionSupported && root.length > 0

    Rectangle {
        anchors.fill: parent
        radius: px(14)
        color: Qt.rgba(0.09, 0.09, 0.09, 0.88)
        border.color: root.accent
        border.width: Math.max(1, px(2))
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: px(6)
        anchors.rightMargin: px(6)
        width: px(22)
        height: px(22)
        radius: px(11)
        color: closeArea.containsMouse ? Qt.rgba(224, 108, 117, 0.25) : "transparent"
        Text {
            anchors.centerIn: parent
            text: "\u{2715}"
            font.family: root.fontFam
            font.pixelSize: px(11)
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

    ClippingRectangle {
        id: artBlock
        anchors.left: parent.left
        anchors.leftMargin: px(12)
        anchors.verticalCenter: parent.verticalCenter
        width: px(64)
        height: px(64)
        radius: px(10)
        color: Qt.rgba(1, 1, 1, 0.06)

        Image {
            id: art
            anchors.fill: parent
            source: root.artUrl
            visible: root.artUrl !== "" && art.status !== Image.Error
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
        }
        Text {
            anchors.centerIn: parent
            visible: !art.visible
            text: "\u{266a}"
            font.family: root.fontFam
            font.pixelSize: px(26)
            color: root.accent
        }
    }

    ColumnLayout {
        id: midColumn
        anchors.left: artBlock.right
        anchors.leftMargin: px(12)
        anchors.right: controlsRow.left
        anchors.rightMargin: px(18)
        anchors.verticalCenter: parent.verticalCenter
        spacing: px(3)

        Text {
            Layout.fillWidth: true
            text: root.title
            font.family: root.fontFam
            font.pixelSize: px(14)
            font.weight: Font.DemiBold
            color: "#ffffff"
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        Text {
            Layout.fillWidth: true
            text: root.album !== "" ? root.artist + "  \u{2022}  " + root.album : root.artist
            font.family: root.fontFam
            font.pixelSize: px(12)
            color: "#a0a0a0"
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Rectangle {
            id: progBg
            Layout.fillWidth: true
            Layout.preferredHeight: px(5)
            Layout.topMargin: px(5)
            radius: px(3)
            color: Qt.rgba(1, 1, 1, 0.12)
            opacity: root.hasPlayer ? 1 : 0.35

            Rectangle {
                width: parent.width * root.progress
                height: parent.height
                radius: px(3)
                color: root.accent
            }
            MouseArea {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: px(12)
                enabled: root.seekable
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => root.seekTo(mouse.x / progBg.width)
                onPositionChanged: mouse => {
                    if (pressed) root.seekTo(mouse.x / progBg.width);
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: px(6)

            Text {
                text: (root.hasPlayer && !root.positionSupported ? "--:--" : root.fmt(root.position))
                    + " / " + (root.length > 0 ? root.fmt(root.length) : "--:--")
                font.family: "Red Hat Mono"
                font.pixelSize: px(10)
                color: "#a0a0a0"
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.players.length > 1
                spacing: px(4)
                Text {
                    text: "\u{2039}"
                    font.family: root.fontFam
                    font.pixelSize: px(13)
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
                    Layout.fillWidth: true
                    text: root.playerIndex < 0 ? root.source
                        : root.source + " (" + (root.playerIndex + 1) + "/" + root.players.length + ")"
                    font.family: root.fontFam
                    font.pixelSize: px(10)
                    color: "#a0a0a0"
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                }
                Text {
                    text: "\u{203a}"
                    font.family: root.fontFam
                    font.pixelSize: px(13)
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
                Layout.fillWidth: true
                visible: root.players.length <= 1
                text: root.source
                font.family: root.fontFam
                font.pixelSize: px(10)
                color: "#a0a0a0"
                elide: Text.ElideLeft
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // Rectangle.enabled does not propagate to MouseArea.
    RowLayout {
        id: controlsRow
        anchors.right: parent.right
        anchors.rightMargin: px(26)
        anchors.verticalCenter: parent.verticalCenter
        spacing: px(6)

        Rectangle {
            Layout.preferredWidth: px(34)
            Layout.preferredHeight: px(34)
            radius: px(17)
            color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            opacity: root.hasPlayer && root.player.canGoPrevious ? 1 : 0.3
            Text {
                anchors.centerIn: parent
                text: "\u{f04ae}"
                font.family: root.iconFam
                font.pixelSize: px(17)
                color: "#ffffff"
            }
            MouseArea {
                id: prevArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.hasPlayer && root.player.canGoPrevious
                onClicked: root.player.previous()
            }
        }

        Rectangle {
            Layout.preferredWidth: px(44)
            Layout.preferredHeight: px(44)
            radius: px(22)
            color: playArea.containsMouse ? Qt.lighter(root.accent, 1.18) : root.accent
            opacity: root.hasPlayer ? 1 : 0.4
            Text {
                anchors.centerIn: parent
                text: root.isPlaying ? "\u{f04c}" : "\u{f04b}"
                font.family: root.iconFam
                font.pixelSize: px(21)
                color: root.accentFg
            }
            MouseArea {
                id: playArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.hasPlayer
                onClicked: {
                    if (root.player.canTogglePlaying) root.player.togglePlaying();
                    else if (root.isPlaying) root.player.pause();
                    else root.player.play();
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: px(34)
            Layout.preferredHeight: px(34)
            radius: px(17)
            color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            opacity: root.hasPlayer && root.player.canGoNext ? 1 : 0.3
            Text {
                anchors.centerIn: parent
                text: "\u{f04ad}"
                font.family: root.iconFam
                font.pixelSize: px(17)
                color: "#ffffff"
            }
            MouseArea {
                id: nextArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.hasPlayer && root.player.canGoNext
                onClicked: root.player.next()
            }
        }
    }
}
