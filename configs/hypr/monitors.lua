-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- GPD MicroPC 2's built-in panel is portrait-native; rotate it into landscape.
hl.monitor({ output = "DSI-1", mode = "1080x1920@60", position = "0x0", scale = omarchy_monitor_scale, transform = 3 })
