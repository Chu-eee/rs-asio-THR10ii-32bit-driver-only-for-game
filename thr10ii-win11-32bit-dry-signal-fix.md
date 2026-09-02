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

---

## Appendix C — Novice troubleshooting quick reference (two routes, crackles & latency)

> For people setting up an audio chain for the first time. Core mindset:
> **the level meter is your thermometer — learn to read it and 80% of audio
> problems become self-diagnosable.**
>
> Audio problems never show an error message; they only create *absence* (silence).
> Troubleshooting is about turning "silence" into *visible clues*: every stage of
> the signal path should have visual proof of life.

### C.1 Which route are you on?

| | Route 1: Voicemeeter bridge | Route 2: THR10II direct (ASIO THRII) |
|---|---|---|
| Status | **Failed in our testing** — kept as a record | **Recommended** — tested working |
| Applies to | Interfaces with 64-bit-only ASIO (e.g. newer Focusrite drivers) | This doc's subject (THR10II / THR-II series) |
| See | C.2 | C.3 |

### C.2 Route 1: Voicemeeter bridge (failure record + checklist)

**Failure record (THR10II setup, tested)**: with the THR's WDM capture path, this
route never produced working audio / a stable tuner; after switching to the direct
route (C.3) everything worked. Not recommended for THR10II anymore. It is kept here
because many tutorials push this route, and it is still the sanctioned workaround for
interfaces that ship 64-bit-only ASIO.

**Checklist** (if you still need to debug a Voicemeeter chain):

Audio only works when **all** of the following are true — any single failure shows
as "no sound", with zero error messages:

```
① Hardware / amp switches
   ├─ amp powered on, volume up
   ├─ amp SOURCE set to USB (easiest to miss!)
   └─ nothing hogging the output (e.g. headphones jack)

② Drivers / programs
   ├─ Voicemeeter is actually running (tray icon)
   └─ Voicemeeter started BEFORE the game/audio app

③ Voicemeeter routing
   ├─ HARDWARE OUT: the A1 button is set to THR10II
   ├─ the input strip carrying the signal has route buttons lit (A1 and/or B1)
   ├─ strip not muted (M), fader not at zero
   └─ level meter moving (signal is arriving)

④ System level
   ├─ Windows default playback device: VoiceMeeter Input (bridge) or Yamaha THR10II (direct)
   └─ volume mixer: device not muted / not lowered

⑤ In-game
   ├─ music / effects volume not lowered
   └─ correct input mode (RTC or microphone)
```

**Observation tip**: whichever stage's meter is *dead*, the problem lives between
that stage and the previous one.

### C.3 Route 2: THR10II direct (recommended, tested working)

**Signal chain**:

```
guitar → THR10II (USB) → 32-bit ASIO DLL (right channel = DRY) → RS ASIO → game
game   → RS ASIO → 32-bit ASIO DLL → THR10II → amp speakers
```

**Quick checklist for novices** (full steps in section 3):
1. Keep the 64-bit driver as-is; **do not install the v1 package**
2. Restore the two DLLs into `SysWOW64` (admin) — see section 3
3. Configure `RS_ASIO.ini` / `Rocksmith.ini` per Appendices A / B
4. **Do not run Voicemeeter**
5. Launch the game

**Real problems encountered** (plain language):

| Symptom | What it is | What to do |
|---|---|---|
| Crackles / everything sounds "gain blown" (distorted) | Almost always one of the **amp's own knobs** is too high — somewhere among master / guitar volume / gain. *Which knob varies; don't overthink it* | **Turn things down**: lower the volume knobs, keep gain low, until it sounds clean. Only if it still crackles after that, look at buffers (table below) |
| Perceived lag when playing | Buffer too large / chain too long | Buffer table below, go smaller |
| Notes don't line up with the note highway | In-game "visual latency calibration" not done | Enter the calibration screen, tap along with what you **hear** (not what you see), repeat a few times |

**Crackle / latency tuning table:**

| Symptom | Action | Direction |
|---|---|---|
| Crackles | `RS_ASIO.ini` → `[Asio]` → `CustomBufferSize`: 128→192→256 (must be a multiple of 32) | ↑ |
| Still crackles | `Rocksmith.ini` → `[Audio]` → `LatencyBuffer`: 1→2 | ↑ |
| Feels dull / sluggish | Try `CustomBufferSize` 96 (on the THR, 96 started crackling — proceed with care) | ↓ |

**Mantra: lower it to the smallest value that does not crackle, then stop.**
Config changes only take effect after **restarting the game** (RS ASIO reads the
config at startup).

### C.4 Hidden culprits (shared by both routes)

| Culprit | Symptom |
|---|---|
| The game/app rewrites its own config file | Settings were fine yesterday, wrong today → check the file's modification time |
| Dangling "shell" registration / dead device | A device is listed but cannot be opened → verify the file the registration points to actually exists |
| Two apps holding the device exclusively at once | One works, the other is silent or reports "device in use" (0xC00D4E85) → close the holder |
| Sample-rate mismatch | Everything locked to 48 kHz (RS ASIO always requests 48k) |
| Windows default device points at a "dead" device | System sounds are gone for no visible reason → check the speaker icon |
