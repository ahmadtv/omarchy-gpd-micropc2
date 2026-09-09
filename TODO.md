# Open items

## Wired EarPods inline buttons (in progress)

Audio and mic through the 3.5mm jack already work via the `audio` patch. The
three inline buttons (play/pause, volume up, volume down) don't, and the
reason is specific to this board:

- Codec: Realtek `ALC269VC` behind Intel's Alder Lake-N HDA controller.
- Mic pin `0x18` ("Mic at Ext Right") has `Unsolicited: tag=02, enabled=1` and
  `VREF_80` active — the hardware is correctly biased to sense a headset
  button's resistance change.
- But the jack's kernel input devices (`HDA Intel PCH Mic`, `HDA Intel PCH
  Headphone`) only advertise `EV_SW` (plug/unplug), never `EV_KEY` — so the
  button-resistance decode logic in `patch_realtek.c`
  (`alc_headset_btn_callback` / the `ALC269_FIXUP_HEADSET_MIC_BUTTON` chain)
  is never being applied.
- That logic is gated by a `SND_PCI_QUIRK` table keyed on the machine's PCI
  subsystem vendor/device ID. This board reports `10ec:0000` — Realtek's own
  placeholder, meaning GPD never set a real OEM subsystem ID in firmware. No
  per-vendor quirk can ever match that ID, on this board or any other that
  shares it, so upstream can't fix this with a normal quirk-table entry.

This is the same *class* of problem the iMac18,3 CS8409 patch solves (a
codec that needs out-of-tree help to do something the silicon already
supports), but the mechanism differs: CS8409's mainline driver already
handles Apple's exact headset wiring, so nothing extra was needed there
beyond the capture-routing patch. Here the fix has to be a DMI-matched
fixup (gated on `DMI_SYS_VENDOR=GPD`, `DMI_PRODUCT_NAME=G1688-08` rather
than the unusable subsystem ID), DKMS-built against this board's exact
`patch_realtek.c`.

Needs, in order:

1. `linux-headers` + `dkms` installed (neither is present yet).
2. The matching kernel source for `sound/pci/hda/patch_realtek.c` at this
   machine's kernel version, to base the patch on real, current fixup
   identifiers instead of guessed ones.
3. A small patch adding a DMI-matched `hda_quirk` entry chaining into the
   existing headset-button decode path.
4. DKMS build + install, then live verification: press each EarPods button
   while watching `evtest` / `journalctl -f -k` for `KEY_PLAYPAUSE`,
   `KEY_VOLUMEUP`, `KEY_VOLUMEDOWN`.

## Auto-rotation via the accelerometer

`iio-sensor-proxy` is installed; the `mxc4005` accelerometer is detected and
reports an initial `right-up` orientation, but did not emit
orientation-change events during a live rotation test.

Diagnostic order:

1. Update the BIOS from 2.16 to 2.17+ (GPD's official procedure) — leading
   suspect, also affects touchscreen resume reliability below.
2. Rotate the whole chassis (not just the swivel display) while running
   `monitor-sensor --accel`.
3. No event → compare raw values under
   `/sys/bus/iio/devices/iio:device0/in_accel_*_raw` across orientations.
4. Raw values change but `monitor-sensor` doesn't → repair the
   `iio-sensor-proxy` polling/permission path.
5. Raw values never change → BIOS or `mxc4005` driver issue.

An experimental watcher already exists at `~/.config/hypr/scripts/auto-rotate.sh`,
launched from `autostart.lua`, mapping sensor orientation to both `DSI-1` and
the touchscreen. Don't treat it as done until step 2 above actually fires
events.

## Touchscreen drops after sleep

Intermittent I2C resume failure (`-121`) on `ILTP7807:00`. `gpd-patcher --fix
touchscreen` rebinds the driver without a reboot. GPD's ArchWiki page
recommends BIOS 2.17+ for touchscreen reliability generally — likely the
same root cause as the accelerometer gap above.

## Fingerprint reader

Listed on the ArchWiki as supported hardware, but `omarchy hw fingerprint`
returns false and `fprintd` isn't installed. Recheck after the BIOS update;
don't touch PAM before the hardware is actually detected.
