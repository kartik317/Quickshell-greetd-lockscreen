import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

// Minimal test greeter: no session-lock protocol needed here (there's
// no session to lock yet), just a fullscreen layer-shell surface on
// the throwaway greeter Hyprland instance.
PanelWindow {
    id: win

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "#000000"
    focusable: true
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Column {
        anchors.centerIn: parent
        spacing: 16

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "greetd test greeter"
            color: "#F8F8F2"
            font.pixelSize: 20
            font.family: "monospace"
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Text {
                text: "Password:"
                color: "#F8F8F2"
                font.pixelSize: 16
                font.family: "monospace"
            }

            TextField {
                id: pwField
                width: 220
                echoMode: TextInput.Password
                enabled: !GreeterState.authenticating && !GreeterState.sessionStarting
                focus: true

                onAccepted: {
                    if (text.length > 0)
                        GreeterState.authenticate(text)
                }
            }

            BusyIndicator {
                visible: GreeterState.authenticating
                running: GreeterState.authenticating
                implicitWidth: 16
                implicitHeight: 16
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "auth failed: " + GreeterState.failReason
            color: "#FF5555"
            font.pixelSize: 13
            font.family: "monospace"
            visible: GreeterState.authFailed
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "starting session..."
            color: "#8BE9FD"
            font.pixelSize: 13
            font.family: "monospace"
            visible: GreeterState.sessionStarting
        }
    }

    Connections {
        target: GreeterState
        function onAuthFailedChanged() {
            if (GreeterState.authFailed) {
                pwField.text = ""
                pwField.forceActiveFocus()
            }
        }
    }

    Component.onCompleted: pwField.forceActiveFocus()
}

