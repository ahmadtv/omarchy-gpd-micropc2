<div align="center">

# 🖥️ Omarchy on GPD MicroPC 2

**Omarchy on the GPD MicroPC 2 (`G1688-08`) — the portrait panel, the greeter, and the mic, all fixed.**

![hardware](https://img.shields.io/badge/hardware-GPD_MicroPC_2-111?logo=linux&logoColor=white)
![display](https://img.shields.io/badge/display-1920×1080_portrait--native-e91e63)
![kernel](https://img.shields.io/badge/kernel-7.1.x-1f6feb?logo=linux&logoColor=white)
[![built for Omarchy](https://img.shields.io/badge/built_for-Omarchy-7c3aed?logo=archlinux&logoColor=white)](https://omarchy.org)
![reversible](https://img.shields.io/badge/every_change-reversible-2ea043)
![license](https://img.shields.io/badge/license-MIT-555)

</div>

The MicroPC 2's 7-inch panel is **portrait-native** and reports `1080x1920` — Omarchy, the SDDM greeter, Plymouth, the console, and even the Limine boot menu all need telling, separately, that it's actually run sideways as a 1920×1080 landscape display. Its internal mic ships with enough analog gain stacked on top of itself to clip. **One command. Every change reversible. Nothing touched without asking.**

[Omarchy](https://omarchy.org)'s whole promise is *"we can fix everything."* This points that at a 7-inch handheld.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ahmadtv/gpd-micropc2-omarchy/main/install)
```

> For the **GPD MicroPC 2** (`G1688-08`). Built and tested on Omarchy (Arch + Hyprland); the audio pieces are plain PipeWire/ALSA and should carry over to any distro, the display/boot pieces are Omarchy, Hyprland, and Limine specific.

---

## ✨ What this patch makes work

| | |
|---|---|
| 🔄 **Landscape desktop** | The `DSI-1` panel is portrait-native (`1080x1920@60`); Hyprland rotates and scales it into a usable `1200×675` landscape workspace instead of the oversized `960×540` that `scale 2` gives you. |
| 🥾 **Landscape at boot** | Kernel framebuffer, Plymouth splash, and the console all get `fbcon=rotate:1` and `panel_orientation=right_side_up` via a Limine drop-in — so the boot sequence isn't sideways before Hyprland even starts. |
| 🧭 **Landscape boot menu** | The Limine boot **menu itself** is rotated 90° so it's readable before any OS has loaded. |
| 🔐 **Landscape greeter** | SDDM runs its own mini Hyprland compositor that doesn't inherit your user config — this patch gives the login/lock screen its own matching rotation. |
| 🖱️ **Natural scrolling + touch alignment** | Reversed scroll on the touchpad and external mouse; the touchscreen's transform is explicitly matched to the rotated display so taps land where you touch. |
| 🔍 **Readable screensaver** | The stock 81-column, 18pt screensaver clips on this display at scale 2; an 8pt user override + launcher fit it properly. |
| 🎙️ **Clean internal mic** | The internal mic was clipping — full ALSA hardware boost stacked on full capture gain. This patch finds the highest **clean** gain (boost off, capture near max) and adds a real-time RNNoise filter on top for the residual hiss no gain setting fixes. |

## ✅ Already fine out of the box

No patch needed — these just work on Omarchy / Linux on this machine:

⌨️ Keyboard & touchpad · 🖱️ Middle-button touchpad scrolling (via the upstream `50-system-gpd.quirks` libinput quirk) · 🔷 Bluetooth keyboard reconnect after unlock · 🎧 Wired headphone/mic jack (once the gain patch is applied)

## 🚫 Not working (yet)

Straight about the gaps:

- 🎧 **Wired EarPods inline buttons** — audio and mic through the jack work; play/pause and volume buttons don't. Root cause: this board's `ALC269VC` codec ships a placeholder PCI subsystem ID (`10ec:0000`), so the kernel's per-vendor headset-button quirk table never matches, and the jack pins only ever report plug/unplug (`EV_SW`), never key codes (`EV_KEY`). Fixing it needs a DMI-matched fixup DKMS-built against `patch_realtek.c` for this exact board — **actively being built**, tracked in [`TODO.md`](TODO.md).
- 🔵 **Bluetooth earbuds (e.g. AirPods) media buttons** — a harder, different problem: AirPods use Apple's proprietary tap-gesture protocol, not standard AVRCP, and there's no general Linux decoder for it. Audio in/out over Bluetooth works fine; taps don't. Not something this patch can fix.
- 🔃 **Auto-rotation via the accelerometer** — `iio-sensor-proxy` is installed and the `mxc4005` accelerometer is detected, but it isn't reliably emitting orientation-change events yet. See [`TODO.md`](TODO.md) for the diagnostic checklist (BIOS 2.17+ is the leading suspect).
- 👆 **Touchscreen sometimes drops after sleep** — an I2C resume failure (`-121`) that a driver rebind recovers without rebooting (`gpd-patcher --fix touchscreen`), but isn't a real fix. GPD's BIOS 2.17+ is reported to address this.
- 👆🏻 **Fingerprint reader** — listed on the ArchWiki, but not detected on this unit (`omarchy hw fingerprint` returns false). Recheck after a BIOS update.

---

## 🧩 Install

The one-liner above clones the patcher and shows its status. Or do it by hand:

```bash
git clone https://github.com/ahmadtv/gpd-micropc2-omarchy
cd gpd-micropc2-omarchy && ./scripts/gpd-patcher
```

Each patch is separate and reversible:

```bash
./scripts/gpd-patcher --apply display bootmenu greeter scroll screensaver audio
./scripts/gpd-patcher --apply all       # everything above, in order
./scripts/gpd-patcher --remove audio    # undo just one
./scripts/gpd-patcher                   # show what's applied
```

Boot-related patches (`display`, `bootmenu`) run `limine-update` for you and print how to verify (`sudo bootctl status --no-pager`). The greeter patch (`greeter`) takes effect on your next logout — restarting SDDM directly ends your current session.

## 🎙️ Under the hood: the mic fix

Nothing in the kernel log pointed at buffer underruns — no `xrun`s, no ALSA errors. The actual cause was gain stacking: `ALSA Capture` at 100% (+30 dB) on top of `Mic Boost` at 67% (+20 dB), fed through a PipeWire route already sitting at ~70%. That's the two hardware amp stages both maxed, which clips on this codec.

PipeWire drives both amp stages together through one non-linear (cubic) route volume — there's no separate slider for "boost" vs "capture" once WirePlumber owns the device, and writing to the raw ALSA controls directly gets silently reverted within about a second as WirePlumber re-asserts its own saved route state. The fix has to go through PipeWire's own volume control:

```bash
wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.30   # ~97% Capture, 0% Boost — clean
```

That alone kills the clipping/crackling. What's left after that is ordinary small-electret-mic hiss, which this patch also cleans up with a real-time RNNoise filter (`noise-suppression-for-voice`, the same LADSPA plugin family behind most Linux "denoised mic" setups) wired in as a PipeWire filter-chain source, set as the new default input.

## 🛟 Safety

Every patch backs up the exact file it's about to replace, once, the first time it touches it (`<file>.bak-gpd-patcher-original`) — re-running `--apply` never clobbers your original. `--remove <patch>` restores it. Files that hold other, unrelated personal settings (`input.lua`, `hyprland.lua`) get a clearly marked block appended instead of being overwritten outright.

## 🔬 Further reading

- Open diagnostics, root causes, and what's been ruled out → [`TODO.md`](TODO.md)

## 🤝 Contributing

On a **GPD MicroPC 2** and hit a bug, or made part of this better? [Open an issue or PR](../../issues) — especially the EarPods button quirk, if you get there first.

## 🙏 Credits

Noise suppression via [RNNoise](https://github.com/xiph/rnnoise) (Jean-Marc Valin) through the `noise-suppression-for-voice` LADSPA build. Landscape-panel handling follows the pattern used across [Omarchy](https://omarchy.org)'s own hardware quirk fixes.

## References

- GPD MicroPC 2 ArchWiki: https://wiki.archlinux.org/title/GPD_MicroPC_2
- GPD technical specifications: https://www.gpd.hk/gpdmicropc2techspecs
- Limine configuration reference: https://github.com/limine-bootloader/limine/blob/v12.x/CONFIG.md
- Hyprland monitor configuration: https://wiki.hypr.land/Configuring/Monitors/
- PipeWire filter-chain: `man pipewire-filter-chain.conf`

---

_Omarchy's promise is "we can fix everything." This is one more thing, fixed._
