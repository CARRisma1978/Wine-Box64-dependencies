#!/usr/bin/env bash

# PulseAudio - RetroPie-Setup module (ext/windows, Experimental section)
#
# Installs PulseAudio for Windows games set to SOUND_MIXER=1. Its user services
# are masked, so it never starts by itself - EmulationStation and the emulators
# stay on plain ALSA, and a game script starts its own private PulseAudio only
# while that game runs. The masks are re-applied after every install / update.
#
# Removing this module unmasks the services and uninstalls PulseAudio
# (libpulse0 stays, as SDL2 and other programs use it).

rp_module_id="pulseaudio"
rp_module_desc="PulseAudio - for games set to SOUND_MIXER=1, never starts by itself"
rp_module_help="Installs pulseaudio and pulseaudio-utils without the recommended extras.\n\nThe pulseaudio.socket and pulseaudio.service user units are masked, so PulseAudio never starts by itself. EmulationStation and the emulators stay on ALSA, and a game set to SOUND_MIXER=1 starts its own private PulseAudio while it runs.\n\nUpdate installs anything missing and upgrades both packages if apt has newer versions.\n\nRemove unmasks the services and uninstalls both packages."
rp_module_licence="LGPL https://gitlab.freedesktop.org/pulseaudio/pulseaudio/-/raw/master/LICENSE"
rp_module_repo=":_pkg_info_pulseaudio"
rp_module_section="exp"

function _packages_pulseaudio() {
    echo pulseaudio pulseaudio-utils
}

function _units_pulseaudio() {
    echo pulseaudio.socket pulseaudio.service
}

# returns 0 if any package is missing or apt has a newer version
function _apt_newer_pulseaudio() {
    local pkg installed candidate
    for pkg in "$@"; do
        read -r installed candidate < <(apt-cache policy "$pkg" 2>/dev/null \
            | awk '/Installed:/ {i=$2} /Candidate:/ {c=$2} END {print i, c}')
        [[ -z "$installed" || "$installed" == "(none)" ]] && return 0
        [[ -n "$candidate" && "$candidate" != "(none)" && "$candidate" != "$installed" ]] && return 0
    done
    return 1
}

function _pkg_info_pulseaudio() {
    case "$1" in
        get)
            local version="$(dpkg-query -W --showformat='${Version}' pulseaudio 2>/dev/null)"
            echo "local pkg_repo_branch=\"apt\""
            echo "local pkg_repo_extra=\"pulseaudio $version\""
            ;;
        newer)
            _apt_newer_pulseaudio $(_packages_pulseaudio)
            return "$?"
            ;;
    esac
}

# run "systemctl --user" for the RetroPie user, if they have a session running
function _user_systemctl_pulseaudio() {
    local uid="$(id -u "$__user")"
    [[ -d "/run/user/$uid" ]] || return 0
    sudo -u "$__user" XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user "$@" &>/dev/null
}

function depends_pulseaudio() {
    getDepends $(_packages_pulseaudio)
}

function sources_pulseaudio() {
    # nothing to download - apt does the work
    :
}

function install_pulseaudio() {
    # also upgrades both packages if apt has newer versions
    aptInstall --no-install-recommends $(_packages_pulseaudio)
    md_ret_require=("/usr/bin/pulseaudio" "/usr/bin/pactl")
}

function configure_pulseaudio() {
    [[ "$md_mode" == "remove" ]] && return

    # never start by itself - only a game script set to SOUND_MIXER=1 starts it
    _user_systemctl_pulseaudio stop $(_units_pulseaudio)
    systemctl --global mask $(_units_pulseaudio)
    printMsgs "console" "pulseaudio.socket and pulseaudio.service are masked - PulseAudio only runs when a game script starts it"
}

function remove_pulseaudio() {
    _user_systemctl_pulseaudio stop $(_units_pulseaudio)
    systemctl --global unmask $(_units_pulseaudio)

    # also clear any per-user masks (systemctl --user mask) left from a manual setup
    local unit link
    for unit in $(_units_pulseaudio); do
        link="$home/.config/systemd/user/$unit"
        if [[ -L "$link" && "$(readlink "$link")" == "/dev/null" ]]; then
            rm -f "$link"
        fi
    done

    apt-get purge -y $(_packages_pulseaudio)
    md_ret_info+=("PulseAudio has been uninstalled and its services unmasked.\n\nGames set to SOUND_MIXER=1 will have no sound until PulseAudio is installed again - use SOUND_MIXER=0 or 2 instead.")
}
