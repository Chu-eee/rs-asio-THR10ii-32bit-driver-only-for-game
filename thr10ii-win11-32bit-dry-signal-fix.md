# THR10II + RS ASIO on Windows 11: restore the 32-bit ASIO driver WITHOUT downgrading your system driver

> A minimal-intervention recipe researched in practice (Windows 11 25H2):
> keep the current 64-bit Yamaha driver stack, restore **only** the 32-bit
> user-mode ASIO component, and let Rocksmith talk to `ASIO THRII` directly.
> No Voicemeeter, no wet-signal compromise, Cubase (64-bit) unaffected,
> Memory Integrity (HVCI) untouched.

---

## 1. The problem

- RS ASIO only detects/looks for **32-bit ASIO drivers** (Rocksmith 2014 is a 32-bit process).
- The current official Yamaha driver for THR-II (`Yamaha Driver2_5 THRII v2.0.0.0`, WHQL, 2024) ships
  **only the 64-bit ASIO DLL** (`ThriiAsio_OnInterposer_x64.dll`). Repackaging the v2 installer
  confirms there is **no 32-bit ASIO DLL inside it at all**.
- Installing the old **v1.0.0.0** package "solves" this but has two serious side effects:
  1. It **replaces the whole driver stack** → breaks 64-bit host apps (e.g. Cubase loses the sound card).
  2. On Windows 11 its legacy kernel driver conflicts with **Memory Integrity (HVCI)**
     (community report: requires disabling the security feature).

## 2. The key insight

The 32-bit ASIO support is a **user-mode COM component** (`YamahaTHRIIAsio_OnInterposer.dll`).
The game only needs **that file**. The kernel/WDM driver can stay v2.0.0.0.

In other words: separate the two layers —

| Layer | What it is | What we do |
|---|---|---|
| Kernel/WDM driver (`YamahaTHRII.sys` v2.0.0.0) | used by everything (Windows, 64-bit DAWs) | **keep as-is** |
| 32-bit ASIO DLL (user mode) | used only by 32-bit ASIO clients (Rocksmith via RS ASIO) | **restore just this file** |

## 3. Steps

1. Keep your current v2.0.0.0 driver installed. **Do not install the v1 package.**
2. Extract from the **v1.0.0.0 installer** (`Yamaha Driver THRII v1.0.0.0 Installer.exe`,
   also available as a zip from Yamaha's site):
   - `YamahaTHRIIAsio_OnInterposer.dll`   (x86, ~266 KB)
   - `InterposerTHRIIBackend.dll`         (x86, ~77 KB)
   - 7-Zip can unpack the NSIS installer: `7z x "Yamaha Driver THRII v1.0.0.0 Installer.exe"`
     (files are under `Driver Archive\THRII\`)
3. Copy both DLLs to `C:\Windows\SysWOW64\` (requires elevation).
4. The 32-bit ASIO registration (`HKLM\SOFTWARE\WOW6432Node\ASIO\ASIO THRII` →
   `HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\{4A1C1DA6-7749-41d5-A13f-aed70386c0f8}`) is
   usually **already present** (left behind by a previous v1 install). If your registry is clean,
   recreate it with `regsvr32` or import the CLSID/ASIO keys pointing to the SysWOW64 DLL.
5. Configure (see appendix): `RS_ASIO.ini` → `Driver=ASIO THRII`, input `Channel=1` (right channel =
   **dry** signal), `SoftwareMasterVolumePercent=200`; `Rocksmith.ini` → `ExclusiveMode=1`,
   `Win32UltraLowLatencyMode=1`.
6. **Do not run Voicemeeter while the game uses this path** — Voicemeeter holding the THR device
   concurrently is exactly what caused the "Failed to create ASIO buffers" failures seen in issue #519.

## 4. Evidence

- Verified on Windows 11 25H2, driver v2.0.0.0 + v1 interposer DLL: RS ASIO log shows
  `Creating AsioSharedHost - dll: ...\SysWow64\YamahaTHRIIAsio_OnInterposer.dll`,
  channels enumerated (`THRII (Left)` / `THRII (Right)`), buffers created, streams running.
- So the **v1 user-mode ASIO DLL works against the v2 kernel driver**.
- The failure in issue #519 (`Yamaha THR10II ... Failed to create ASIO buffers`) was caused by
  Voicemeeter + RS ASIO both grabbing the THR drivers at the same time — **not** by a v1/v2
  incompatibility.

## 5. Channel map (important for gameplay)

THR-II devices expose a stereo capture: **Left = wet (amp-sim/processed)**, **Right = dry**.
Rocksmith is itself an amp simulator and needs the **dry** signal for pitch detection →
use `Channel=1` in `[Asio.Input.1]`, and add gain via `SoftwareMasterVolumePercent=200`
(the dry feed is quiet).

## 6. Reverting

Delete the two files from `C:\Windows\SysWOW64\` (admin). Nothing else changes.
Driver stack was never touched, so there is nothing to restore.

---

## Appendix A — RS_ASIO.ini (working baseline)

```ini
[Config]
EnableWasapiOutputs=0
EnableWasapiInputs=0
EnableAsio=1

[Asio]
BufferSizeMode=custom
CustomBufferSize=128

[Asio.Output]
Driver=ASIO THRII
BaseChannel=0
AltBaseChannel=
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=100
EnableRefCountHack=

[Asio.Input.0]
Driver=
Channel=0
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=100
EnableRefCountHack=

[Asio.Input.1]
Driver=ASIO THRII
Channel=1
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=200
EnableRefCountHack=

[Asio.Input.Mic]
Driver=ASIO THRII
Channel=1
EnableSoftwareEndpointVolumeControl=1
EnableSoftwareMasterVolumeControl=1
SoftwareMasterVolumePercent=200
EnableRefCountHack=
```

## Appendix B — Rocksmith.ini (relevant lines)

```ini
[Audio]
EnableMicrophone=1
ExclusiveMode=1
LatencyBuffer=1
Win32UltraLowLatencyMode=1
```

## References

- mdias/rs_asio issue [#210 – Yamaha THR10II Confirmed Working](https://github.com/mdias/rs_asio/issues/210) (incl. rvighne's wet/dry channel notes)
- mdias/rs_asio issue [#519 – RS sees no sound output (THR10II)](https://github.com/mdias/rs_asio/issues/519)
- Yamaha ASIO Driver V1.0.0.0 (32-bit era) / V2.0.0.0 (64-bit only) download pages