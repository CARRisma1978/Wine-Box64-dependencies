#!/usr/bin/env bash

# Wine dependencies - RetroPie-Setup module (ext/windows, Experimental section)
#
# Installs the packages the Windows game launch scripts (and their shared
# roms/windows/.scripts code) use, and checks the system settings they need:
#
#   xorg, xinit, x11-xserver-utils   X server, xinit, xrandr, xset, xsetroot
#   x11-utils                        xwininfo (window zoom)
#   python3, libx11-6, libxrandr2,   focus.py, panels.py, bootlog.py and the
#   libxfixes3                       per-game python helpers
#   alsa-utils                       alsaloop, aconnect (SOUND_MIXER=2, MIDI)
#   libgstreamer1.0-0,               GStreamer: Wine's winegstreamer plays and
#   gstreamer1.0-plugins-base,       decodes game videos (AVI, MPEG...) and
#   gstreamer1.0-plugins-good,       some music with it (Box64 passes it to
#   gstreamer1.0-libav               the Pi's own libraries). libav = decoders
#                                    for older video formats. Without it:
#                                    "MCI error" / no intro videos
#   kmod                             modprobe snd-aloop
#
# Not xserver-xorg-legacy (the setuid root X wrapper, set up by
# /etc/X11/Xwrapper.config): X started from EmulationStation's console runs
# as the user without it, and RetroPie-Setup removes it each time it starts.
#
# Checks: passwordless sudo (CPU governor, snd-aloop) and the snd-aloop module.
#
# Removing this module does not uninstall these packages: X, python3 and
# alsa-utils are also used by RetroPie and Raspberry Pi OS.

rp_module_id="wine-deps"
rp_module_desc="Wine dependencies - packages used by the Windows game launch scripts"
rp_module_help="Installs the packages used by the Windows game launch scripts:\n\nxorg, xinit, x11-xserver-utils, x11-utils (xwininfo), python3, alsa-utils, kmod, the X libraries used by the python helpers, and GStreamer with its base, good and libav plugins (Wine plays game videos with it - without it, intro videos give an 'MCI error').\n\nAlso checks for passwordless sudo (CPU governor and the snd-aloop sound mixer) and for the snd-aloop kernel module.\n\nUpdate installs anything missing and upgrades these packages if apt has newer versions.\n\nRemoving this module leaves the packages installed, as RetroPie and Raspberry Pi OS use them too."
rp_module_repo=":_pkg_info_wine-deps"
rp_module_section="exp"

function _packages_wine-deps() {
    echo xorg xinit x11-xserver-utils x11-utils python3 alsa-utils kmod libx11-6 libxrandr2 libxfixes3 \
        libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-libav
}

# returns 0 if any package is missing or apt has a newer version
function _apt_newer_wine-deps() {
    local pkg installed candidate
    for pkg in "$@"; do
        read -r installed candidate < <(apt-cache policy "$pkg" 2>/dev/null \
            | awk '/Installed:/ {i=$2} /Candidate:/ {c=$2} END {print i, c}')
        [[ -z "$installed" || "$installed" == "(none)" ]] && return 0
        [[ -n "$candidate" && "$candidate" != "(none)" && "$candidate" != "$installed" ]] && return 0
    done
    return 1
}

function _pkg_info_wine-deps() {
    case "$1" in
        get)
            echo "local pkg_repo_branch=\"apt\""
            echo "local pkg_repo_extra=\"$(_packages_wine-deps)\""
            ;;
        newer)
            _apt_newer_wine-deps $(_packages_wine-deps)
            return "$?"
            ;;
    esac
}

function depends_wine-deps() {
    getDepends $(_packages_wine-deps)
}

function sources_wine-deps() {
    # nothing to download - apt does the work
    :
}

function install_wine-deps() {
    # also upgrades these packages if apt has newer versions
    aptInstall --no-install-recommends $(_packages_wine-deps)
    local pkg
    for pkg in $(_packages_wine-deps); do
        hasPackage "$pkg" || md_ret_errors+=("Could not install $pkg")
    done
}

function configure_wine-deps() {
    [[ "$md_mode" == "remove" ]] && return

    local warnings=()
    if ! sudo -u "$__user" sudo -n true 2>/dev/null; then
        warnings+=("- $__user can't use sudo without a password. The launch scripts need it for the CPU governor (CPU_PERFORMANCE=1) and for loading snd-aloop (SOUND_MIXER=2).")
    fi
    if ! modinfo snd-aloop &>/dev/null; then
        warnings+=("- The snd-aloop kernel module was not found, so SOUND_MIXER=2 won't work.")
    fi
    if [[ "${#warnings[@]}" -gt 0 ]]; then
        local IFS=$'\n'
        md_ret_info+=("Wine dependencies - please check:\n\n${warnings[*]}\n\nThe launch scripts carry on without these, and write a warning to their log.")
    fi
}

function remove_wine-deps() {
    md_ret_info+=("Wine dependencies: no packages were uninstalled, as RetroPie and Raspberry Pi OS also use them:\n\n$(_packages_wine-deps)")
}
