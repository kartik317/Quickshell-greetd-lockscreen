pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ── change this to your actual username ──
    readonly property string username: "NoName:("
    // The session to launch on success. This should be your REAL
    // Hyprland session, not the greeter's throwaway one.
    // Use start-hyprland, not the Hyprland binary directly - since
    // Hyprland 0.53 that wrapper sets up XDG/portal/screen-share env
    // vars the bare binary won't, and Hyprland warns loudly if skipped.
    readonly property var sessionCmd: ["start-hyprland"]
    // ───────────────────────────────────────────

    property bool authenticating: false
    property bool authFailed: false
    property string failReason: ""
    // Once greetd accepts start_session, it's tearing this greeter
    // down to switch to the real session. Never call authenticate()
    // again after this is true - a second attempt races the
    // already-successful one and greetd will reject it.
    property bool sessionStarting: false

    property Process helper: Process {
        id: helperProc
        command: [Quickshell.shellDir + "/greet-helper.py", root.username, ...root.sessionCmd]
        stdinEnabled: true

        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                if (out === "OK") {
                    // Leave `authenticating` true and set sessionStarting -
                    // the UI should stay locked out from here on. Do NOT
                    // reset authenticating to false; that would let the
                    // field re-enable and race a second authenticate()
                    // call against the session switch already in flight.
                    root.sessionStarting = true
                    root.authFailed = false
                    return
                }
                root.authenticating = false
                if (out.startsWith("FAIL:")) {
                    root.authFailed = true
                    root.failReason = out.slice(5)
                } else {
                    root.authFailed = true
                    root.failReason = "unexpected helper output: " + out
                }
            }
        }
    }

    function authenticate(password) {
        if (authenticating || sessionStarting) return
        authFailed = false
        failReason = ""
        authenticating = true

        helper.running = true
        helper.write(password + "\n")
        helper.closeStdin()
    }
}

