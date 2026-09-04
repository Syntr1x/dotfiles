import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    property var themes: ["syn-beige","syn-Broadcast","syn-mellow","syn-Ocean","IC_Orange_PPL","Gruvbox","syn-rose-pine","syn-Tango","Tomorrow","syn-green","traffic","syn-mellow-darkmode"]
    property var themeNames: ["Beige","Dark","Purple","Blue","Orange","Gruvbox","Kirby","Moondrop","Winter","Green","Destiny 2","Purple(darkmode)"]
    property var wallpapers: ["Flowers.png","darkPlants.jpg","pinkRose.jpg","bluesky.jpg","TrainPath.png","Arch_retro.png","kirby.jpg","Moondrop_white.jpg","winter.jpg","leaves.jpg","thats_it.jpg","black_oled.jpg"]
    property var rofiThemes: [
        "rounded-beige.rasi",
        "rounded-dark.rasi",
        "rounded-pink.rasi",
        "rounded-blue.rasi",
        "rounded-orange.rasi",
        "rounded-retro.rasi",
        "rounded-kirby.rasi",
        "rounded-white.rasi",
        "rounded-winter.rasi",
        "rounded-green.rasi",
        "rounded-destiny.rasi",
        "rounded-pink-darkmode.rasi"
    ]
    property var waybarColors: ["#d8c8b3","#888888","#f0a0c0","#a1cdf3","#fed79d","#d8c8b3","#fdcbe6","#FB443C","#FDE094","#8c9180","#C0884B","#f0a0c1"]

    property int selectedIdx: -1
    property int currentIdx: -1
    property bool waybarBorder: true
    property string statusMsg: "Select a theme"
    property bool isApplying: false
    // accent follows selected theme (preview) otherwise current theme falls back
    property string accentColor: {
        let idx = root.selectedIdx >= 0 ? root.selectedIdx : root.currentIdx;
        if (idx >= 0 && idx < root.waybarColors.length) return root.waybarColors[idx];
        return "#7aa2f7";
    }
    // readable text on accent (white for dark accents, dark for light accents like Beige #d8c8b3)
    property string accentFg: {
        let c = root.accentColor;
        if (!c || c.length < 7) return "white";
        let r = parseInt(c.slice(1,3),16)/255, g = parseInt(c.slice(3,5),16)/255, b = parseInt(c.slice(5,7),16)/255;
        let l = 0.2126*r + 0.7152*g + 0.0722*b; // relative luminance
        return l > 0.58 ? "#121214" : "white";
    }

    property color windowBg: Qt.tint("#1a1a1e", Qt.alpha(root.accentColor, 0.30))
    property color cardBg: Qt.tint("#23232a", Qt.alpha(root.accentColor, 0.18))
    property color cardSelectedBg: Qt.tint("#2e2a36", Qt.alpha(root.accentColor, 0.32))
    property color footerBg: Qt.tint("#24242a", Qt.alpha(root.accentColor, 0.20))
    property color closeBtnBg: Qt.tint("#23232a", Qt.alpha(root.accentColor, 0.14))
    property color closeBtnBgHover: Qt.tint("#2e2e36", Qt.alpha(root.accentColor, 0.26))
    property color subtleBorder: Qt.tint("#2e2e36", Qt.alpha(root.accentColor, 0.28))
    property color toggleOffBg: Qt.tint("#3a3a42", Qt.alpha(root.accentColor, 0.12))
    property color toggleOffBorder: Qt.tint("#4a4a52", Qt.alpha(root.accentColor, 0.18))
    property color mediaPlaceholderBg: Qt.tint("#121214", Qt.alpha(root.accentColor, 0.14))
    property string wallpaperDir: Quickshell.shellPath("../../Wallpapers")
    property string wallpaperFallbackDir: {
        let xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (!xdg || xdg === "null" || xdg === "") xdg = (Quickshell.env("HOME") || "") + "/.config";
        return xdg + "/hypr/Wallpapers";
    }
    property string applyScript: Quickshell.shellPath("apply.sh")

    // detect current theme on startup
    Process {
        id: detectProc
        command: ["bash","-c","grep -E '^[[:space:]]*theme[[:space:]]*=' ~/.config/ghostty/config | tail -n1 | cut -d= -f2 | xargs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let cur = text.trim()
                for (let i=0;i<root.themes.length;i++) if (root.themes[i]===cur){ root.currentIdx=i; root.selectedIdx=i; root.statusMsg = "Current: " + root.themeNames[i] + " ("+cur+")"; break }
                if (root.currentIdx==-1 && cur!=="") root.statusMsg = "Current: " + cur + " (custom)"
            }
        }
    }

    // apply process
    Process {
        id: applyProc
        stdout: StdioCollector { onStreamFinished: { root.statusMsg = text.trim(); } }
        stderr: StdioCollector { onStreamFinished: { if(text.trim()!=="") root.statusMsg = text.trim() } }
        onExited: (code,status) => {
            root.isApplying = false
            if (code===0) {
                root.currentIdx = root.selectedIdx
                root.statusMsg = "✓ Applied " + root.themeNames[root.selectedIdx]
            } else {
                root.statusMsg = "✗ Failed (code " + code + ")"
            }
        }
    }

    function applyTheme(idx) {
        if (idx<0 || idx>=root.themes.length) return
        root.isApplying = true
        root.statusMsg = "Applying " + root.themeNames[idx] + "…"
        let border = root.waybarBorder ? "y" : "n"
        applyProc.command = ["bash", root.applyScript, String(idx), border]
        applyProc.running = true
    }

    function quitApp() {
        Qt.quit()
    }

    FloatingWindow {
        id: win
        title: "Theme Selector"
        implicitWidth: 1080
        implicitHeight: 760
        color: "transparent"
        minimumSize: Qt.size(900, 600)

        // focus grab so Esc / click outside dismisses
        HyprlandFocusGrab {
            id: grab
            windows: [win]
            active: true
            onCleared: quitApp()
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (e.key===Qt.Key_Escape) { quitApp(); e.accepted=true }
                else if (e.key===Qt.Key_Return || e.key===Qt.Key_Enter) { if(root.selectedIdx>=0) applyTheme(root.selectedIdx); e.accepted=true }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.windowBg
            radius: 16
            border.color: Qt.alpha(root.accentColor, 0.55)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 300 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        spacing: 4
                        Text { text: "THEME SELECTOR"; color: root.accentColor; font.pixelSize: 18; font.bold: true; font.family: "Fira Sans"
                            Behavior on color { ColorAnimation { duration: 250 } } }
                        Text { text: root.statusMsg; color: root.statusMsg.startsWith("✓") ? "#98c379" : root.statusMsg.startsWith("✗") ? "#e06c75" : "#a0a0a8"; font.pixelSize: 12; font.family: "Fira Sans"; elide: Text.ElideRight; Layout.maximumWidth: 760 }
                    }
                    Item { Layout.fillWidth: true }
                    RowLayout {
                        spacing: 8
                        Text { text: "Waybar border"; color: "#a0a0a8"; font.pixelSize: 12; font.family: "Fira Sans" }
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: root.waybarBorder ? root.accentColor : root.toggleOffBg
                            border.color: root.waybarBorder ? root.accentColor : root.toggleOffBorder; border.width: 1
                            Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 250 } }
                            Rectangle { width: 18; height: 18; radius: 9; color: "white"; anchors.verticalCenter: parent.verticalCenter; x: root.waybarBorder ? 22 : 4
                                Behavior on x { NumberAnimation{ duration:150; easing.type:Easing.OutCubic } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.waybarBorder = !root.waybarBorder; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    Rectangle {
                        width: 36; height: 36; radius: 10; color: closeMa.containsMouse ? root.closeBtnBgHover : root.closeBtnBg; border.color: root.subtleBorder; border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                        Text { anchors.centerIn: parent; text: "✕"; color: "#a0a0a8"; font.pixelSize: 14 }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled:true; cursorShape: Qt.PointingHandCursor; onClicked: quitApp() }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.currentIdx>=0 ? "Current: " + root.themeNames[root.currentIdx] : "Current: —"; color: root.accentColor; font.pixelSize: 11; font.family: "Fira Sans"
                        Behavior on color { ColorAnimation { duration: 250 } } }
                    Item { Layout.fillWidth: true }
                    Text { text: root.selectedIdx>=0 ? "Selected: " + root.themeNames[root.selectedIdx] : "Click a card to select"; color: root.selectedIdx>=0 ? "#c0c0c8" : "#6a6a70"; font.pixelSize: 11; font.family: "Fira Sans" }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 4
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        model: root.themes.length
                        delegate: Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 148
                            radius: 14
                            color: root.selectedIdx===index ? root.cardSelectedBg : root.cardBg
                            border.color: root.selectedIdx===index ? root.waybarColors[index] : (root.currentIdx===index ? Qt.alpha(root.accentColor, 0.52) : root.subtleBorder)
                            border.width: root.selectedIdx===index ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            Behavior on border.color { ColorAnimation { duration: 250 } }

                            Rectangle {
                                anchors.fill: parent; radius: 14; color: "transparent"
                                border.color: root.currentIdx===index && root.selectedIdx!==index ? Qt.alpha(root.accentColor, 0.24) : "transparent"
                                border.width: 1; visible: root.currentIdx===index && root.selectedIdx!==index
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: 10; color: root.mediaPlaceholderBg; clip: true
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                    Image {
                                        id: wpImg
                                        anchors.fill: parent
                                        source: "file://" + root.wallpaperDir + "/" + root.wallpapers[index]
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                let fb = "file://" + root.wallpaperFallbackDir + "/" + root.wallpapers[index];
                                                if (source.toString() !== fb) source = fb;
                                                else console.log("Wallpaper missing: " + root.wallpapers[index] + " tried " + root.wallpaperDir + " and " + root.wallpaperFallbackDir);
                                            } else if (status === Image.Ready) {
                                            }
                                        }
                                    }
                                    Text {
                                        visible: wpImg.status === Image.Error
                                        anchors.centerIn: parent
                                        text: "🖼 " + root.wallpapers[index]
                                        color: "#5a5a66"
                                        font.pixelSize: 9
                                        font.family: "Fira Sans"
                                    }
                                    RowLayout {
                                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                        anchors.margins: 6; spacing: 6
                                        Rectangle {
                                            Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11; color: root.waybarColors[index]; border.color: "#00000044"; border.width: 1
                                            Text { anchors.centerIn: parent; text: String(index+1); color: "#121214"; font.pixelSize: 11; font.bold:true }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            visible: root.currentIdx===index
                                            width: 44; height: 20; radius: 10; color: root.accentColor
                                            Text { anchors.centerIn: parent; text: "now"; color: root.accentFg; font.pixelSize: 9; font.bold:true; font.family:"Fira Sans" }
                                        }
                                        Rectangle {
                                            visible: root.selectedIdx===index
                                            width: 20; height: 20; radius: 10; color: root.waybarColors[index]
                                            Text { anchors.centerIn: parent; text: "✓"; color: "#121214"; font.pixelSize: 11; font.bold:true }
                                        }
                                    }
                                }

                                Text { text: root.themeNames[index]; color: root.selectedIdx===index ? "white" : "#e8e8eb"; font.pixelSize: 13; font.bold: true; font.family:"Fira Sans"; elide: Text.ElideRight; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                Text { text: root.themes[index] + "  •  " + root.wallpapers[index]; color: "#7a7a82"; font.pixelSize: 9; font.family:"Fira Sans"; elide: Text.ElideRight; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter; spacing: 6
                                    Rectangle { width:10; height:10; radius:5; color: root.waybarColors[index]; border.color:"#00000066"; border.width:1 }
                                    Text { text: root.rofiThemes[index].split("/").pop().replace("rounded-","").replace(".rasi",""); color:"#6a6a70"; font.pixelSize:9; font.family:"Fira Sans" }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; hoverEnabled:true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedIdx = index
                                onDoubleClicked: applyTheme(index)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10; color: root.footerBg; border.color: root.subtleBorder; border.width: 1
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                            Text { text: "↩ Esc to close  •  ⏎ to apply  •  Double-click card to apply"; color:"#6a6a70"; font.pixelSize:10; font.family:"Fira Sans"; elide: Text.ElideRight; Layout.fillWidth:true }
                        }
                    }
                    Rectangle {
                        width: 140; height: 42; radius: 10; color: close2Ma.containsMouse ? root.closeBtnBgHover : root.closeBtnBg; border.color: root.subtleBorder; border.width:1; opacity: root.selectedIdx<0 || root.isApplying ? 0.5 : 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text { anchors.centerIn: parent; text: root.isApplying ? "Applying…" : "Close"; color:"#a0a0a8"; font.pixelSize:13; font.family:"Fira Sans"; font.bold:true }
                        MouseArea { id: close2Ma; anchors.fill: parent; hoverEnabled:true; cursorShape: Qt.PointingHandCursor; onClicked: quitApp() }
                    }
                    Rectangle {
                        width: 180; height: 42; radius: 10; color: root.selectedIdx<0 || root.isApplying ? root.toggleOffBg : root.accentColor
                        border.color: root.selectedIdx<0 ? root.toggleOffBorder : root.accentColor; border.width:1
                        opacity: root.selectedIdx<0 || root.isApplying ? 0.6 : 1
                        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 250 } }
                        RowLayout { anchors.centerIn: parent; spacing:6
                            Text { text: root.isApplying ? "◌" : "✓"; color: root.selectedIdx<0 ? "#6a6a70" : root.accentFg; font.pixelSize:13; font.bold:true }
                            Text { text: root.isApplying ? "Working…" : "Apply Full Theme"; color: root.selectedIdx<0 ? "#6a6a70" : root.accentFg; font.pixelSize:13; font.family:"Fira Sans"; font.bold:true }
                        }
                        MouseArea {
                            id: applyMa; anchors.fill: parent; hoverEnabled:true; cursorShape: root.selectedIdx<0 ? Qt.ArrowCursor : Qt.PointingHandCursor; enabled: root.selectedIdx>=0 && !root.isApplying
                            onClicked: applyTheme(root.selectedIdx)
                        }
                    }
                }
            }
        }
    }
}
