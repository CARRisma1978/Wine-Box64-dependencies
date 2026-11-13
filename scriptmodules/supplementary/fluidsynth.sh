#!/usr/bin/env bash

# FluidSynth - RetroPie-Setup module (ext/windows, Experimental section)
#
# Installs FluidSynth and the FluidR3 General MIDI soundfont
# (/usr/share/sounds/sf2/FluidR3_GM.sf2) for Windows games with MIDI music.
#
# The fluidsynth user service is masked, so FluidSynth never runs in the
# background - it only runs while a game launch script has started it
# (e.g. Lemmings, 3D Pinball). The mask is re-applied after every install / update.
#
# Removing this module unmasks the service and uninstalls both packages.

rp_module_id="fluidsynth"
rp_module_desc="FluidSynth - MIDI synth + FluidR3 soundfont, started only by game scripts"
rp_module_help="Installs fluidsynth and fluid-soundfont-gm (/usr/share/sounds/sf2/FluidR3_GM.sf2).\n\nThe fluidsynth user service is masked, so FluidSynth only runs when a game launch script starts it.\n\nUpdate installs anything missing and upgrades both packages if apt has newer versions.\n\nRemove unmasks the service and uninstalls both packages."
rp_module_licence="LGPL https://raw.githubusercontent.com/FluidSynth/fluidsynth/master/LICENSE"
rp_module_repo=":_pkg_info_fluidsynth"
rp_module_section="exp"

function _packages_fluidsynth() {
    echo fluidsynth fluid-soundfont-gm
}

# returns 0 if any package is missing or apt has a newer version
function _apt_newer_fluidsynth() {
    local pkg installed candidate
    for pkg in "$@"; do
        read -r installed candidate < <(apt-cache policy "$pkg" 2>/dev/null \
            | awk '/Installed:/ {i=$2} /Candidate:/ {c=$2} END {print i, c}')
        [[ -z "$installed" || "$installed" == "(none)" ]] && return 0
        [[ -n "$candidate" && "$candidate" != "(none)" && "$candidate" != "$installed" ]] && return 0
    done
    return 1
}

function _pkg_info_fluidsynth() {
    case "$1" in
        get)
            local version="$(dpkg-query -W --showformat='${Version}' fluidsynth 2>/dev/null)"
            echo "local pkg_repo_branch=\"apt\""
            echo "local pkg_repo_extra=\"fluidsynth $version\""
            ;;
        newer)
            _apt_newer_fluidsynth $(_packages_fluidsynth)
            return "$?"
            ;;
    esac
}

# run "systemctl --user" for the RetroPie user, if they have a session running
function _user_systemctl_fluidsynth() {
    local uid="$(id -u "$__user")"
    [[ -d "/run/user/$uid" ]] || return 0
    sudo -u "$__user" XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user "$@" &>/dev/null
}

function depends_fluidsynth() {
    getDepends $(_packages_fluidsynth)
}

function sources_fluidsynth() {
    # nothing to download - apt does the work
    :
}

function install_fluidsynth() {
    # also upgrades both packages if apt has newer versions
    aptInstall --no-install-recommends $(_packages_fluidsynth)
    md_ret_require=("/usr/bin/fluidsynth" "/usr/share/sounds/sf2/FluidR3_GM.sf2")
}

function configure_fluidsynth() {
    [[ "$md_mode" == "remove" ]] && return

    # never run in the background - only when a game script starts it
    _user_systemctl_fluidsynth stop fluidsynth.service
    systemctl --global mask fluidsynth.service
    printMsgs "console" "fluidsynth.service is masked - FluidSynth only runs when a game script starts it"
}

function remove_fluidsynth() {
    _user_systemctl_fluidsynth stop fluidsynth.service
    systemctl --global unmask fluidsynth.service
    apt-get purge -y $(_packages_fluidsynth)
    md_ret_info+=("FluidSynth and the FluidR3 soundfont have been uninstalled, and the fluidsynth service unmasked.")
}
