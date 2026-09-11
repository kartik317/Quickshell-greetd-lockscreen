-- Minimal Hyprland config for the greetd greeter session only.
-- This is NOT your real desktop config - it just needs to launch
-- the Quickshell greeter UI and have one working monitor.

hl.monitor({
    output = "preferred",
    mode = "auto",
    position = "auto",
    scale = 1,
})

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c /etc/greetd/quickshell-greeter")
end)
