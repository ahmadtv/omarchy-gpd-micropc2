-- GPD MicroPC 2's built-in panel is portrait-native; rotate it into landscape.
-- Scale is left to you: this follows omarchy_monitor_scale above, whatever you set it to.
hl.monitor({ output = "DSI-1", mode = "1080x1920@60", position = "0x0", scale = omarchy_monitor_scale, transform = 3 })
