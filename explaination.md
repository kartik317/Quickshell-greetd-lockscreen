# greetd + Quickshell Explained

This project is a minimal login/greeter setup for Wayland. It uses `greetd` as the display manager/login daemon and `Quickshell` as the graphical greeter UI that asks for a password and starts the user session.

---

## 1. What is greetd?

`greetd` is a lightweight login manager for Wayland compositors. Instead of a full desktop display manager, it gives you a tiny login service that can:

- start a greeter session for the login screen
- authenticate the user through PAM or another auth backend
- launch the user's real session after successful login

In this project, greetd is configured to launch a temporary Hyprland session whose job is only to show the greeter UI.

The main config is in [greetd/config.toml](greetd/config.toml):

```toml
vt = 1
[default_session]
command = "Hyprland -c /etc/greetd/hyprland-greet.lua"
user = "greeter"
```

This means:

- greetd uses VT 1
- it starts a user called `greeter`
- that user runs a command: `Hyprland -c /etc/greetd/hyprland-greet.lua`

So greetd does not show the login UI directly. Instead, it starts a special minimal Hyprland instance that is only used as a temporary environment for the greeter.

---

## 2. What is Quickshell?

Quickshell is a toolkit for building Wayland desktop UI in a declarative QML-style environment. In this setup, it is used to create the actual login screen.

The greeter UI is built in [greetd/quickshell-greeter/shell.qml](greetd/quickshell-greeter/shell.qml). That file creates:

- a fullscreen layer-shell window
- a dark background
- a password field
- a login prompt label
- visual feedback while authenticating
- an error message if authentication fails

The important idea is that the greeter is not a normal desktop app running on your main session. It runs inside the temporary Hyprland greeter session started by greetd.

---

## 3. How the startup flow works

### Step 1: greetd boots and launches the greeter session

When greetd starts, it runs this command configured in [greetd/config.toml](greetd/config.toml):

```bash
Hyprland -c /etc/greetd/hyprland-greet.lua
```

The `-c` option tells Hyprland to use a custom config file instead of the user’s normal desktop configuration.

### Step 2: the temporary Hyprland config launches Quickshell

The file [greetd/hyprland-greet.lua](greetd/hyprland-greet.lua) is a minimal Hyprland config that only does one real job:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c /etc/greetd/quickshell-greeter")
end)
```

This means:

- when Hyprland starts, it executes `qs -c /etc/greetd/quickshell-greeter`
- `qs` starts Quickshell using the greeter config folder
- the login screen becomes visible on the screen

This is a throwaway “greeter session” that is different from the real desktop session.

---

## 4. How the Quickshell login UI works

The actual UI is in [greetd/quickshell-greeter/shell.qml](greetd/quickshell-greeter/shell.qml).

Key points:

- `PanelWindow` creates a full-screen overlay window
- `exclusiveZone: -1` makes it use the whole surface area
- `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive` gives keyboard focus to the login UI
- a `TextField` is used for the password
- `onAccepted` triggers authentication when Enter is pressed
- the UI shows:
  - “greetd test greeter”
  - “Password:”
  - error text on failed auth
  - “starting session...” while the session is being launched

This is intentionally minimal and meant as a practical example, not a production-grade login screen.

---

## 5. How authentication is handled

The login logic is not all in QML. The state is split into a singleton file and a helper script:

- [greetd/quickshell-greeter/GreeterState.qml](greetd/quickshell-greeter/GreeterState.qml) = state and auth flow
- [greetd/quickshell-greeter/greet-helper.py](greetd/quickshell-greeter/greet-helper.py) = communicates with greetd over its socket protocol

### GreeterState.qml

This file defines state such as:

- `authenticating`
- `authFailed`
- `failReason`
- `sessionStarting`

It also creates a `Process` that runs:

```qml
command: [Quickshell.shellDir + "/greet-helper.py", root.username, ...root.sessionCmd]
```

That means when the user types a password and submits it, the app launches the Python helper script with:

- the username
- the session command to start after login

The helper then writes the password to stdin.

### greet-helper.py

This script is the real bridge to greetd. It does the following:

1. Reads the username and intended session command from argv
2. Reads the password from stdin
3. Reads the `GREETD_SOCK` environment variable
4. Opens a Unix socket to greetd
5. Sends a `create_session` message
6. Handles `auth_message` responses
7. Sends `post_auth_message_response` with the password
8. Checks whether greetd reports success or error
9. Calls `start_session` with the actual desktop command
10. Prints `OK` if everything succeeds, or `FAIL:<reason>` if not

This script is doing the actual login communication protocol with greetd.

---

## 6. The actual greetd protocol interaction

The Python helper speaks a small JSON message protocol over a Unix socket.

Important steps:

- `create_session` creates a login session for a username
- `post_auth_message_response` sends the password in response to auth prompts
- `start_session` tells greetd to launch the user’s desktop session

The helper then handles these responses:

- `success` means auth succeeded
- `error` means auth or session startup failed
- `OK` is printed back to Quickshell to signal the UI should transition to “starting session...”

This is the key integration point: greetd stays in charge of authentication, while Quickshell just provides the front-end.

---

## 7. What happens after a successful login

On success, this line in [greetd/quickshell-greeter/GreeterState.qml](greetd/quickshell-greeter/GreeterState.qml) matters:

```qml
readonly property var sessionCmd: ["start-hyprland"]
```

This launches the user’s real desktop session, not the temporary greeter one. The comment explains why:

- `start-hyprland` sets up the correct environment variables
- a bare Hyprland binary is not enough for XDG/portal/screen-share setup

So the real flow is:

1. greetd starts greeter Hyprland
2. Quickshell UI asks for password
3. helper authenticates against greetd
4. greetd accepts login
5. greetd launches the real session command
6. the system transitions from greeter to the user’s desktop

---

## 8. Why this design is useful

This pattern is common in Wayland-based lock/login systems because it keeps responsibilities clean:

- `greetd` handles authentication and session starting
- Hyprland provides a clean Wayland compositor environment
- Quickshell provides the custom graphical login UI

This makes the login screen easy to customize without touching the core auth system.

---

## 9. Limitations of this example

This project is intentionally minimal. It is a demonstration and not a full production login solution. A few things to note:

- the username is hardcoded in [greetd/quickshell-greeter/GreeterState.qml](greetd/quickshell-greeter/GreeterState.qml)
- it assumes a simple password-based PAM flow
- it does not do multi-factor auth handling
- it is built for a greeter session, not a fully locked desktop environment

---

## 10. Summary

This setup is basically:

- greetd = the authentication/login backend
- temporary Hyprland = a minimal compositor for the login screen
- Quickshell = the UI that shows a password prompt
- Python helper = the glue that speaks greetd’s protocol
- real session = launched only after success

In short, greetd manages login, Quickshell renders the login experience, and the helper makes the two talk to each other.

If you want to adapt this into a real log-in or lock screen, the main things to change are:

- the username in [greetd/quickshell-greeter/GreeterState.qml](greetd/quickshell-greeter/GreeterState.qml)
- the login UI in [greetd/quickshell-greeter/shell.qml](greetd/quickshell-greeter/shell.qml)
- the session command in [greetd/quickshell-greeter/GreeterState.qml](greetd/quickshell-greeter/GreeterState.qml)
- the Hyprland greeter config in [greetd/hyprland-greet.lua](greetd/hyprland-greet.lua)
