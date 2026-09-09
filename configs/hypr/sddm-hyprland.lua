-- Local Hyprland configuration for the SDDM Wayland greeter.
-- The GPD MicroPC 2 panel is portrait-native, so rotate it into landscape.
hl.monitor({
  output = "DSI-1",
  mode = "1080x1920@60",
  position = "0x0",
  scale = 1.6,
  transform = 3,
})

hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
  },

  animations = {
    enabled = false,
  },
})
