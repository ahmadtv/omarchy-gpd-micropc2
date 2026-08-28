# GPD MicroPC 2 — Omarchy Setup and Handoff

This guide records the configuration applied to a GPD MicroPC 2 (`G1688-08`)
running Omarchy/Hyprland. The machine has a portrait-native `DSI-1` panel that
reports `1080x1920@60` but is physically used as a 1920×1080 landscape display.

## Current hardware and software notes

- Display: 7-inch, 1920×1080, 314 PPI, portrait-native panel
- Internal output: `DSI-1`
- Touchscreen: `iltp7807:00-222a:fff1`
- Touchpad: `alps0001:00-36b6:c001-touchpad`
- Accelerometer: MXC6655, exposed through the `mxc4005` kernel driver
- BIOS at time of setup: `2.16`
- ArchWiki recommends BIOS `2.17` or newer for touchscreen reliability
- Preferred display server: Wayland

## 1. Correct the Omarchy desktop orientation

Edit `~/.config/hypr/monitors.lua` so the specific display rule keeps the
portrait-native mode but rotates it into landscape:

```lua
local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

hl.monitor({
  output = "DSI-1",
  mode = "1080x1920@60",
  position = "0x0",
  scale = omarchy_monitor_scale,
  transform = 3,
})
```

Scale `1.6` gives a logical landscape workspace of approximately `1200×675`.
Scale `2` produces only `960×540` and makes Chrome/web apps feel oversized.

Validate after editing:

```bash
hyprctl reload
hyprctl configerrors
```

## 2. Correct the kernel, Plymouth, and console orientation

Create `/etc/limine-entry-tool.d/display-rotation.conf`:

```bash
KERNEL_CMDLINE[default]+=" fbcon=rotate:1 video=DSI-1:panel_orientation=right_side_up"
```

Rebuild the Limine configuration and unified kernel image:

```bash
sudo limine-update
```

Verify that the active entry contains both parameters:

```bash
sudo bootctl status --no-pager
```

The original setup also added the same parameters to `/etc/kernel/cmdline`.
The Limine drop-in above is the authoritative part on this installation because
`/etc/default/limine` already defines `KERNEL_CMDLINE[default]`.

## 3. Rotate the Limine boot menu

Limine 12 supports independent boot-menu rotation. Add this global setting near
the top of `/boot/limine.conf`:

```text
interface_rotation: 90
```

Then run:

```bash
sudo limine-update
```

Confirm that `interface_rotation: 90` remains in `/boot/limine.conf` after the
update. A backup was created as
`/boot/limine.conf.bak-20260827-interface-rotation` on the original machine.

## 4. Add Windows Boot Manager to Limine

Run Limine's EFI scanner after installing another operating system:

```bash
sudo limine-scan
```

Select `Windows Boot Manager`, keep the suggested entry name, and verify the
result:

```bash
sudo limine-entry-tool --tree 2
```

The scanner creates a persistent top-level EFI entry pointing to Microsoft's
boot manager on the Windows EFI partition. On this machine it produced:

```text
Omarchy
├─ linux
└─ Snapshots
Windows Boot Manager
```

## 5. Startup transition and Bluetooth keyboard

The active kernel arguments correctly force the `DSI-1` panel orientation.
However, a brief sideways frame can still appear immediately after entering
the encrypted-disk password. This is the modeset handoff from Plymouth/kernel
framebuffer rendering to Hyprland, which then applies `transform = 3`. The
final desktop orientation is correct.

The encrypted-disk password prompt runs before the root filesystem, BlueZ,
and the user's Bluetooth pairing database are available. A Bluetooth keyboard
therefore cannot be relied on for that prompt. Use one of these instead:

- The MicroPC 2's built-in keyboard
- A wired USB keyboard
- A keyboard using a USB receiver that works as a firmware-level HID device

After unlock, a paired, bonded, and trusted Bluetooth keyboard should reconnect
automatically when `bluetooth.service` starts. Adding Bluetooth and personal
pairing keys to the initramfs is possible but is intentionally not recommended
for this setup because it complicates early boot and exposes additional pairing
material outside the encrypted root filesystem.

## 6. Correct the SDDM logout/login screen orientation

SDDM runs its own minimal Hyprland compositor and does not inherit the user's
`~/.config/hypr/monitors.lua`. Create `/etc/sddm/hyprland.lua`:

```lua
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
```

Point SDDM at the local configuration in
`/etc/sddm.conf.d/10-wayland.conf`:

```ini
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=start-hyprland -- --config /etc/sddm/hyprland.lua
```

Validate it without ending the current graphical session:

```bash
Hyprland --verify-config --config /etc/sddm/hyprland.lua
```

The result should be `config ok`. The change takes effect on the next logout;
restarting SDDM directly will terminate the active graphical session. Keeping
this override under `/etc` prevents an Omarchy package update from overwriting
it.

## 7. Natural scrolling for mouse and touchpad

The following user override is present in `~/.config/hypr/input.lua`:

```lua
hl.config({
  input = {
    natural_scroll = true,
    touchpad = {
      natural_scroll = true,
    },
    -- Match the portrait-native touchscreen to the rotated internal display.
    touchdevice = {
      output = "DSI-1",
      transform = 3,
    },
  },
})
```

This reverses both the external mouse wheel and the internal touchpad.
Touchscreen scrolling remains direct/natural and is handled by each
application. The explicit touchscreen output and transform make taps and
swipes line up with the rotated internal display.

If the `ILTP7807` touchscreen remains listed by `hyprctl devices` but stops
responding after sleep, check the kernel log:

```bash
journalctl -b -k | rg -i ILTP7807
```

An I2C resume failure such as error `-121` can be recovered without rebooting
by rebinding only the touchscreen driver:

```bash
sudo sh -c 'printf %s i2c-ILTP7807:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/unbind'
sudo sh -c 'printf %s i2c-ILTP7807:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/bind'
```

This is a recovery, not the firmware-level solution. BIOS 2.17 or newer is
still recommended for touchscreen reliability after resume.

## 8. Fit the Omarchy screensaver on the 7-inch display

The stock screensaver uses an 81-column logo and an 18-point Foot font, which
clips at the display edges. At display scale `2`, the landscape workspace is
only about 540 logical pixels wide, so the dedicated user override uses an
8-point font.

User config: `~/.config/foot/screensaver.ini`

```ini
[main]
font=JetBrainsMono Nerd Font:size=8
pad=0x0

[colors-dark]
background=000000
foreground=ffffff
```

The user launcher is `~/.local/bin/omarchy-launch-screensaver`. It follows the
stock Omarchy launcher but starts Foot with the user config above. Do not edit
the launcher under `/usr/share/omarchy`; package updates replace that copy.

Omarchy deliberately places `/usr/share/omarchy/bin` first in Hyprland's
application `PATH`, so `environment.d` alone does not make this user launcher
win. Add this final override near the bottom of
`~/.config/hypr/hyprland.lua`, after the Omarchy defaults are loaded:

```lua
local user_bin = (os.getenv("HOME") or "") .. "/.local/bin"
hl.env("PATH", user_bin .. ":" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))
```

Apply and validate it, then restart the shell so its child processes inherit
the corrected path:

```bash
hyprctl reload
hyprctl configerrors
omarchy restart shell
```

Verify the live Omarchy Shell environment resolves the user launcher before
the packaged one. The normal Foot font is independent and remains controlled
by Omarchy's Display panel.

## 9. Omarchy display text size

Do not manually edit the normal Foot font while using Omarchy's Display panel.
The panel intentionally controls shell, GTK, and terminal text together.

Useful commands:

```bash
omarchy display text size
omarchy display text size 14
omarchy display text size reset
```

Recommended starting point for this 7-inch display:

- Display scale: `1.6`
- Omarchy text size: `14px`
- Resulting Foot font: `11pt`
- Browser zoom: `100%` normally
- YouTube/WhatsApp web-app zoom: `80–90%` if their responsive sidebars hide

At the time this guide was written, the user had selected `20px`, which maps to
a 15-point terminal font. Existing Foot windows cannot reload their font; close
and reopen Foot after moving the text-size control.

## 10. Logitech MX Keys Mini modifier layout

Hold `Fn + O` for three seconds to switch the keyboard to Mac mode:

- Command sends Super
- Option sends Alt
- Control sends Ctrl

Hold `Fn + P` for three seconds to return to PC mode.

Omarchy already binds Super+C, Super+V, and Super+X as universal copy, paste,
and cut shortcuts. Super+Backspace is not macOS-style line deletion: Omarchy
uses it to toggle window transparency. Option+Backspace deletes the previous
word in applications that support the standard Alt+Backspace behavior.

## 11. Dictation and microphone diagnosis

Voxtype is configured in `~/.config/voxtype/config.toml` with:

- Caps Lock push-to-talk
- `base.en` Whisper model
- English language
- default audio source

Hold Caps Lock for the entire sentence and release shortly after finishing.

Static was reproduced across dictation and WhatsApp, so it is system-wide and
not a Voxtype-only problem. The measured gain chain was:

- ALSA Capture: 100%, +30 dB
- Internal Mic Boost: +20 dB
- PipeWire source volume: 84%

No microphone gain change was applied. A reasonable diagnostic starting point
is 0 dB internal boost, 70–80% hardware capture, and about 70% PipeWire input.
For better English recognition, consider `small.en` after correcting the audio.

## 12. Automatic rotation — installed but not working

`iio-sensor-proxy` was installed, and the accelerometer appears as `mxc4005`.
The service reports an initial `right-up` orientation, but it did not emit
orientation-change events during the live test. Therefore auto-rotation is not
yet a confirmed fix.

An experimental watcher exists at:

```text
~/.config/hypr/scripts/auto-rotate.sh
```

It is launched from `~/.config/hypr/autostart.lua` and maps sensor orientation
to both `DSI-1` and `iltp7807:00-222a:fff1`. Do not treat this part as complete
until `monitor-sensor --accel` reports changes while the entire device is
rotated.

Recommended next diagnostics:

1. Update the BIOS from 2.16 to at least 2.17 using GPD's official procedure.
2. Rotate the entire chassis, not only the swivelling display, while running:
   `monitor-sensor --accel`.
3. If no event appears, compare the raw values under
   `/sys/bus/iio/devices/iio:device0/in_accel_*_raw` in multiple orientations.
4. If raw values change but `monitor-sensor` does not, repair the
   `iio-sensor-proxy` polling/permission path.
5. If raw values remain fixed, investigate BIOS or the `mxc4005` kernel driver.

## 13. Tablet features audit

### Middle-button scrolling

The machine has libinput `1.31.3`, and the upstream GPD MicroPC 2 quirk is
present in `/usr/share/libinput/50-system-gpd.quirks`. This is newer than the
ArchWiki's `1.29.2` requirement. Test holding the physical middle button while
moving on the touchpad before installing any third-party helper.

### On-screen keyboard

No touchscreen keyboard such as `wvkbd`, `squeekboard`, or `maliit-keyboard` is
installed. Omarchy's `KeyboardPanel.qml` is a keyboard-navigable settings panel,
not an on-screen typing keyboard. Install an OSK only if tablet-only use is
important; a manual toggle is simpler and more reliable than automatic popup.

### Fingerprint reader

The ArchWiki lists fingerprint support, but this installation currently has no
detected reader: `omarchy hw fingerprint` returns false and `fprintd` is not
installed. Recheck after the BIOS update. If Omarchy detects the hardware, use:

```bash
omarchy setup security fingerprint
```

Do not manually modify PAM before the hardware is detected.

## 14. Important backups

The setup created these system backups:

```text
/etc/kernel/cmdline.bak-20260827-display-rotation
/boot/limine.conf.bak-20260827-interface-rotation
```

The original Hyprland monitor configuration was also backed up under:

```text
~/.config/hypr/monitors.lua.bak-20260827-gpd-rotation
```

## References

- GPD MicroPC 2 ArchWiki: https://wiki.archlinux.org/title/GPD_MicroPC_2
- GPD technical specifications: https://www.gpd.hk/gpdmicropc2techspecs
- Limine configuration reference: https://github.com/limine-bootloader/limine/blob/v12.x/CONFIG.md
- Hyprland monitor configuration: https://wiki.hypr.land/Configuring/Monitors/
