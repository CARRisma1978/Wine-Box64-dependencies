# Wine-Box64-dependencies

RetroPie-Setup modules for running Windows games on a **Raspberry Pi 5** with [Box64](https://github.com/ptitSeb/box64) and [Kron4ek's Wine builds](https://github.com/Kron4ek/Wine-Builds). They appear in RetroPie-Setup's **Experimental** section, and install, update and remove everything from there. They also add a **Windows** system to EmulationStation.

> **Use at your own risk.** These modules change system settings (e.g. the boot `config.txt`) and install software system wide. They have only been tested on the setup listed below.

## The modules

| Module | What it does |
|---|---|
| `wine-deps.sh` | Installs the packages the Windows game launch scripts use (X server, xinit, python3, ALSA utilities, GStreamer for in-game videos). Also checks for passwordless sudo and the `snd-aloop` kernel module. |
| `box64.sh` | Builds Box64 from source for the Pi 5 (`-DRPI5ARM64=1`) and installs it system wide. You can choose the latest source code or a specific release, and restore the previous build. Adds `kernel=kernel8.img` to `config.txt` if it's missing (Box64 and Wine need the 4KB page kernel). |
| `wine.sh` | Downloads Kron4ek's vanilla x86_64 WoW64 Wine build to `~/wine-wow64/wine-<version>`, with `~/wine-wow64/wine` linked to the active version. You can choose a version, and switch between or delete downloaded versions. Also sets up the Windows system in EmulationStation. |
| `pulseaudio.sh` | *Optional.* Installs PulseAudio with its services masked, so it never starts by itself. A game launch script can start its own private PulseAudio while that game runs (`SOUND_MIXER=1`). |
| `fluidsynth.sh` | *Optional.* Installs FluidSynth and the FluidR3 General MIDI soundfont for games with MIDI music. Its service is masked, so it only runs when a game launch script starts it. |

## Requirements

- **Raspberry Pi 5.** The Box64 and Wine modules are limited to the Pi 5 and won't appear on other models.
- **Raspberry Pi OS Bookworm Lite 64-bit** (Debian 12).
- **RetroPie** installed with RetroPie-Setup.
- **The user's sudo access works without a password.** The default `pi` user has this. The launch scripts need it for the CPU governor and the `snd-aloop` sound mixer.
- **An internet connection.** The modules download from GitHub and apt.
- **About 1 GB free** for each downloaded Wine version, plus room for the Box64 build.

### Tested on

| | |
|---|---|
| Hardware | Raspberry Pi 5 (16 GB), 1080p over HDMI |
| OS | Raspberry Pi OS Bookworm Lite 64-bit (Debian 12.15) |
| RetroPie | 4.8.12 |
| Box64 | v0.4.5 (30d5c77), with Dynarec |
| Wine | 11.18 WoW64, vanilla (Kron4ek) |
| X server | xorg-server 2:21.1.7-3+rpt3+deb12u13 |

## ⚠️ Wine versions after 11.18

At the time of writing, **Wine versions newer than 11.18 do not work** with Box64 on the Pi 5:

- **11.19 and 11.20** crash at start.
- **11.21** wouldn't launch a game.
- **11.17 and 11.18** work.

By default the Wine module installs the **newest** release, so **pin it to 11.18 before installing**. Run this on the Pi:

```bash
echo 'version = "11.18"' > /opt/retropie/configs/all/wine-setup.cfg
```

Or, after installing, go to the module's **Configuration / Options → Choose Wine version**, pick `11.18`, and let it install. Any version you pick is kept when you choose Update. Switch back to `latest` once newer versions work again.

## Installing

RetroPie-Setup picks up extra modules from its `ext` folder. These modules go in:

```
~/RetroPie-Setup/ext/windows/scriptmodules/supplementary/
```

### Option 1 - clone with git (recommended)

This puts the whole repo in the right place, so a later `git pull` updates the modules:

```bash
git clone https://github.com/CARRisma1978/Wine-Box64-dependencies.git ~/RetroPie-Setup/ext/windows
```

To update later:

```bash
cd ~/RetroPie-Setup/ext/windows && git pull
```

Then choose **Update** on the modules in RetroPie-Setup.

### Option 2 - copy the files by hand

Download the `.sh` files from [this repo](https://github.com/CARRisma1978/Wine-Box64-dependencies) and copy them to the folder above. On Windows you can use Samba or WinSCP.

```bash
mkdir -p ~/RetroPie-Setup/ext/windows/scriptmodules/supplementary
```

If you edit the files on Windows, save them with **Unix (LF)** line endings. In Notepad++: *Edit → EOL Conversion → Unix (LF)*. Scripts with Windows (CRLF) line endings fail on the Pi.

The modules don't need to be made executable, because RetroPie-Setup loads them itself.

## Running

1. Start RetroPie-Setup:

   ```bash
   sudo ~/RetroPie-Setup/retropie_setup.sh
   ```

2. Go to **Manage packages → Manage experimental packages**.
3. Install the modules **in this order**:
   1. `wine-deps`
   2. `box64`. This takes several minutes to build. If it added `kernel=kernel8.img`, **reboot** before going on.
   3. `wine`. Pin it to 11.18 first; see above.
   4. `pulseaudio` and/or `fluidsynth`, if your game launch scripts use them.
4. Restart EmulationStation. A **Windows** system now appears once it has games in it.

Each module has a **Configuration / Options** menu for choosing versions and checking status.

### Using Wine in a game launch script

Put games in `~/RetroPie/roms/windows/`, each started by a `.sh` launch script. Point the scripts at the active Wine with:

```bash
WINE_DIR="$HOME/wine-wow64/wine/bin"
```

This path stays the same when you switch Wine versions.

## Updating

In RetroPie-Setup, choose **Update** on a module.

- **Box64** rebuilds if the chosen source has new changes. The build it replaces is kept and can be restored from Configuration / Options.
- **Wine** moves to the newest release only if `latest` is chosen.
- **wine-deps, pulseaudio and fluidsynth** install anything missing and upgrade their packages if apt has newer versions.

## Removing

Choose **Remove** on a module.

- **wine** deletes `~/wine-wow64` and the Windows system entry. Your games (`roms/windows`), `configs/windows` and `~/wine-prefixes` are kept.
- **box64** deletes the installed files. `kernel=kernel8.img` is left in `config.txt`; remove it by hand if you no longer want it.
- **pulseaudio** and **fluidsynth** unmask their services and uninstall their packages.
- **wine-deps** leaves its packages installed, as RetroPie and Raspberry Pi OS use them too.

## Credits

These modules download or install software from the following projects. None of it is included in this repo.

- [Box64](https://github.com/ptitSeb/box64) by ptitSeb (MIT)
- [Wine](https://www.winehq.org/) (LGPL), using the builds by [Kron4ek](https://github.com/Kron4ek/Wine-Builds)
- [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) (LGPL)
- [FluidSynth](https://github.com/FluidSynth/fluidsynth) (LGPL) and the FluidR3 GM soundfont
- [RetroPie-Setup](https://github.com/RetroPie/RetroPie-Setup) (GPL-3.0)

## Licence

The modules in this repo are released under the GNU General Public License v3.0, the same licence as RetroPie-Setup; see [LICENSE](LICENSE). The software they install is covered by its own licence, listed above.
