import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // Theme data (mirrors themeselect.sh) 
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
                // brief delay then keep msg
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

        // keyboard
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
            color: "#1a1a1e"
            radius: 16
            border.color: "#2a2a30"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        spacing: 4
                        Text { text: "THEME SELECTOR"; color: "#e8e8eb"; font.pixelSize: 18; font.bold: true; font.family: "Fira Sans" }
                        Text { text: root.statusMsg; color: root.statusMsg.startsWith("✓") ? "#98c379" : root.statusMsg.startsWith("✗") ? "#e06c75" : "#a0a0a8"; font.pixelSize: 12; font.family: "Fira Sans"; elide: Text.ElideRight; Layout.maximumWidth: 760 }
                    }
                    Item { Layout.fillWidth: true }
                    // waybar border toggle
                    RowLayout {
                        spacing: 8
                        Text { text: "Waybar border"; color: "#a0a0a8"; font.pixelSize: 12; font.family: "Fira Sans" }
                        Rectangle {
                            width: 44; height: 24; radius: 12
                            color: root.waybarBorder ? "#7aa2f7" : "#3a3a42"
                            border.color: root.waybarBorder ? "#7aa2f7" : "#4a4a52"; border.width: 1
                            Rectangle { width: 18; height: 18; radius: 9; color: "white"; anchors.verticalCenter: parent.verticalCenter; x: root.waybarBorder ? 22 : 4
                                Behavior on x { NumberAnimation{ duration:150; easing.type:Easing.OutCubic } }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.waybarBorder = !root.waybarBorder; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    // close button
                    Rectangle {
                        width: 36; height: 36; radius: 10; color: closeMa.containsMouse ? "#2e2e36" : "#24242a"; border.color: "#33333a"; border.width: 1
                        Text { anchors.centerIn: parent; text: "✕"; color: "#a0a0a8"; font.pixelSize: 14 }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled:true; cursorShape: Qt.PointingHandCursor; onClicked: quitApp() }
                    }
                }

                // current + count
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.currentIdx>=0 ? "Current: " + root.themeNames[root.currentIdx] : "Current: —"; color: "#7aa2f7"; font.pixelSize: 11; font.family: "Fira Sans" }
                    Item { Layout.fillWidth: true }
                    Text { text: root.selectedIdx>=0 ? "Selected: " + root.themeNames[root.selectedIdx] : "Click a card to select"; color: root.selectedIdx>=0 ? "#c0c0c8" : "#6a6a70"; font.pixelSize: 11; font.family: "Fira Sans" }
                }

                // ── Grid ──
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 4
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        model: 12
                        delegate: Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 148
                            radius: 14
                            color: root.selectedIdx===index ? "#24243a" : "#23232a"
                            border.color: root.selectedIdx===index ? root.waybarColors[index] : (root.currentIdx===index ? "#5a5a66" : "#2e2e36")
                            border.width: root.selectedIdx===index ? 2 : 1

                            // subtle glow for current
                            Rectangle {
                                anchors.fill: parent; radius: 14; color: "transparent"
                                border.color: root.currentIdx===index && root.selectedIdx!==index ? "#3a3a46" : "transparent"
                                border.width: 1; visible: root.currentIdx===index && root.selectedIdx!==index
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                // wallpaper image
                                Rectangle {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    radius: 10; color: "#121214"; clip: true
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
                                                // loaded ok
                                            }
                                        }
                                    }
                                    // subtle placeholder when still broken
                                    Text {
                                        visible: wpImg.status === Image.Error
                                        anchors.centerIn: parent
                                        text: "🖼 " + root.wallpapers[index]
                                        color: "#5a5a66"
                                        font.pixelSize: 9
                                        font.family: "Fira Sans"
                                    }
                                    // top badges
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
                                            width: 44; height: 20; radius: 10; color: "#7aa2f7"
                                            Text { anchors.centerIn: parent; text: "now"; color: "white"; font.pixelSize: 9; font.bold:true; font.family:"Fira Sans" }
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
                                // rofi + wallpaper color dots
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

                // ── Footer ──
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Rectangle {
                        Layout.fillWidth: true; height: 42; radius: 10; color: "#24242a"; border.color: "#2e2e36"; border.width: 1
                        RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                            Text { text: "↩ Esc to close  •  ⏎ to apply  •  Double-click card to apply"; color:"#6a6a70"; font.pixelSize:10; font.family:"Fira Sans"; elide: Text.ElideRight; Layout.fillWidth:true }
                        }
                    }
                    Rectangle {
                        width: 140; height: 42; radius: 10; color: applyMa.containsMouse ? "#2e2e36" : "#23232a"; border.color:"#33333a"; border.width:1; opacity: root.selectedIdx<0 || root.isApplying ? 0.5 : 1
                        Text { anchors.centerIn: parent; text: root.isApplying ? "Applying…" : "Close"; color:"#a0a0a8"; font.pixelSize:13; font.family:"Fira Sans"; font.bold:true }
                        MouseArea { id: close2Ma; anchors.fill: parent; hoverEnabled:true; cursorShape: Qt.PointingHandCursor; onClicked: quitApp() }
                    }
                    Rectangle {
                        width: 180; height: 42; radius: 10; color: root.selectedIdx<0 || root.isApplying ? "#3a3a42" : "#7aa2f7"
                        border.color: root.selectedIdx<0 ? "#3a3a42" : "#7aa2f7"; border.width:1
                        opacity: root.selectedIdx<0 || root.isApplying ? 0.6 : 1
                        RowLayout { anchors.centerIn: parent; spacing:6
                            Text { text: root.isApplying ? "◌" : "✓"; color: root.selectedIdx<0 ? "#6a6a70" : "white"; font.pixelSize:13; font.bold:true }
                            Text { text: root.isApplying ? "Working…" : "Apply Full Theme"; color: root.selectedIdx<0 ? "#6a6a70" : "white"; font.pixelSize:13; font.family:"Fira Sans"; font.bold:true }
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
