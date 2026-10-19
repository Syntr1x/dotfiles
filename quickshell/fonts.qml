// Font preview panel — standalone entry, run with `quickshell -p fonts`
// (see reload.sh). Shows installed font families in the config's dark style.
// Accent is read live from quickshell/accent.conf, same as Theme.qml.
//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

ShellRoot {
    id: root

    // --- accent (same file & logic as Theme.qml) ---
    readonly property string defaultAccent: "#f0a0c0"

    readonly property FileView accentFile: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") || "") + "/.config") + "/quickshell/accent.conf"
        watchChanges: true
        printErrors: false
    }

    readonly property string accent: {
        const m = /accent\s*=\s*(#[0-9a-fA-F]{6})|(#[0-9a-fA-F]{6})/.exec(root.accentFile.text() || "");
        return m && (m[1] || m[2]) ? (m[1] || m[2]) : root.defaultAccent;
    }

    PanelWindow {
        id: win
        anchors { top: true; left: true }
        margins { top: 40; left: 40 }
        implicitWidth: 780
        implicitHeight: Math.min(content.implicitHeight + 48, maxH)
        color: "transparent"

        // keep the window on-screen; the Flickable handles the overflow
        readonly property int maxH: {
            const p = Quickshell.primaryScreen;
            const h = p && p.height ? p.height : 900;
            return Math.max(h - margins.top - 80, 300);
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(16 / 255, 16 / 255, 18 / 255, 0.92)
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
            border.width: 1

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 6
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        radius: 3
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                    }
                    background: Rectangle { color: "transparent" }
                }

                Column {
                    id: content
                    x: 24
                    y: 24
                    width: parent.width - 48
                    spacing: 4

                    Text {
                        text: "font preview"
                        color: root.accent
                        font.family: "Red Hat Display"
                        font.weight: Font.Black
                        font.pixelSize: 26
                    }
                    Text {
                        text: "installed families — samples at 18px"
                        color: "#8a8a90"
                        font.family: "Red Hat Text"
                        font.pixelSize: 12
                        bottomPadding: 10
                    }

                    Repeater {
                        model: [
                            { fam: "Inter",                   weight: Font.DemiBold, note: "gold-standard UI font — crisp at any size" },
                            { fam: "Inter Display",           weight: Font.Bold,     note: "large clock / headers — made for display sizes" },
                            { fam: "Space Grotesk",           weight: Font.Bold,     note: "distinctive clock / headers with character" },
                            { fam: "FiraCode Nerd Font",      weight: Font.DemiBold,
                              sample: "\ue266 \uf007a \uf007b \uf007c \uf007d \uf007e \uf007f \uf0080 \uf0081 \uf0082 \uf0084 \uf011 \uf017 \uf0200 \uf0240 \uf026 \uf028 \uf03d8 \uf04b \uf04c \uf05aa \uf073 \uf07c \uf0ac \uf120 \uf1eb \uf4bc",
                              famOverride: "FiraCode Nerd Font",
                              note: "all 27 bar glyphs as the bar renders them (single run, FiraCode Nerd Font)" },
                            { fam: "Red Hat Display",         weight: Font.DemiBold, note: "UI headers, clock — geometric, modern" },
                            { fam: "Red Hat Text",            weight: Font.Medium,   note: "body text — very legible at small sizes" },
                            { fam: "Roboto",                  weight: Font.Medium,   note: "neutral all-rounder" },
                            { fam: "Roboto Condensed",        weight: Font.Medium,   note: "for tight spaces and long module strings" },
                            { fam: "Adwaita Sans",            weight: Font.Normal,   note: "clean system look" },
                            { fam: "JetBrains Mono",          weight: Font.Medium,   note: "mono · ligatures -> => != " },
                            { fam: "JetBrainsMono Nerd Font", weight: Font.Medium,   note: "mono + glyphs: 󰣇 󰍛 󰅐  " },
                            { fam: "FiraCode Nerd Font",      weight: Font.Medium,   note: "mono + glyphs: 󰣇 󰍛 󰅐  " },
                            { fam: "Adwaita Mono",            weight: Font.Normal,   note: "system mono" },
                            { fam: "Symbols Nerd Font",       weight: Font.Normal,   note: "icon-only:   󰛵  󰂚   " },
                            { fam: "Font Awesome 7 Free",     weight: Font.Black,    note: "icon-only: \uf0f3 \uf015 \uf101" }
                        ]
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            width: parent.width
                            height: row.implicitHeight + 16
                            radius: 8
                            color: hover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                            HoverHandler { id: hover }

                            Column {
                                id: row
                                x: 14
                                y: 8
                                width: parent.width - 28
                                spacing: 2

                                Text {
                                    text: card.modelData.fam
                                    color: "#c8c8cc"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                }
                                Text {
                                    id: sample
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: card.modelData.sample || "AaBbGg  quickshell 0123456789 — (:{[<>]}) @&%!? łß§µ→"
                                    color: "#f2f2f5"
                                    font.family: card.modelData.famOverride || card.modelData.fam
                                    font.weight: card.modelData.weight
                                    font.pixelSize: 18
                                }
                                Text {
                                    text: card.modelData.note + "  ·  " + (sample.status === Text.Error ? "✗ not available" : "✓ available")
                                    color: sample.status === Text.Error ? "#e06c75" : "#8a8a90"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    Text {
                        topPadding: 14
                        text: "usage:  font.family: \"Red Hat Display\";  font.weight: Font.DemiBold"
                        color: "#8a8a90"
                        font.family: "JetBrains Mono"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
