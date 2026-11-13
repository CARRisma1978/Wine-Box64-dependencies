#!/usr/bin/env bash

# Box64 - RetroPie-Setup module (ext/windows, Experimental section)
#
# Builds Box64 from source for the Raspberry Pi 5 and installs it system wide
# with "make install" (/usr/local/bin/box64, /etc/binfmt.d/box64.conf,
# /etc/box64.box64rc, /usr/lib/box64-x86_64-linux-gnu/).
#
# Configuration / Options menu:
#   - choose what to build: the latest source code, or a specific release tag
#   - restore the previous build (the build that was replaced is always kept)
#   - status (version, page size, kernel=kernel8.img, binfmt)
#
# Settings are kept in /opt/retropie/configs/all/box64-setup.cfg

rp_module_id="box64"
rp_module_desc="Box64 - x86_64 emulator used by Wine (built from source for the Pi 5)"
rp_module_help="Builds Box64 from https://github.com/ptitSeb/box64 with -DRPI5ARM64=1 and installs it system wide.\n\nUse 'Configuration / Options' to choose between the latest source code and a specific release, to restore the previous build, or to check the status.\n\nBox64 and Wine need the 4KB page kernel on the Pi 5. If kernel=kernel8.img is not already set, it is added to the end of the boot config.txt under [all] - a reboot is then needed."
rp_module_licence="MIT https://raw.githubusercontent.com/ptitSeb/box64/main/LICENSE"
rp_module_repo="git https://github.com/ptitSeb/box64.git :_branch_box64"
rp_module_section="exp"
rp_module_flags="!all rpi5 !32bit noinstclean"

# ----- settings -----------------------------------------------------------------

function _config_box64() {
    echo "$configdir/all/box64-setup.cfg"
}

# _get_setting_box64 KEY DEFAULT
function _get_setting_box64() {
    local file="$(_config_box64)"
    local value=""
    [[ -f "$file" ]] && value="$(grep -oP "^$1\s*=\s*\"\K[^\"]*" "$file" | tail -n1)"
    [[ -z "$value" ]] && value="$2"
    echo "$value"
}

# _set_setting_box64 KEY VALUE
function _set_setting_box64() {
    local file="$(_config_box64)"
    iniConfig " = " '"' "$file"
    iniSet "$1" "$2"
    chown "$__user":"$__group" "$file"
}

# the git branch / tag to build: "main" for the latest source, otherwise a release tag
function _branch_box64() {
    local version="$(_get_setting_box64 version latest)"
    [[ "$version" == "latest" ]] && version="main"
    echo "$version"
}

# _info_get_box64 FILE KEY - read a value from one of our .info files
function _info_get_box64() {
    [[ -f "$1" ]] && grep -oP "^$2=\"\K[^\"]*" "$1" | tail -n1
}

function _installed_version_box64() {
    local version=""
    [[ -x /usr/local/bin/box64 ]] && version="$(timeout 10 /usr/local/bin/box64 --version 2>/dev/null | grep -m1 -i 'box64')"
    [[ -z "$version" ]] && version="$(_info_get_box64 "$md_inst/current.info" version)"
    [[ -z "$version" ]] && version="not installed"
    echo "$version"
}

# ----- boot config / page size --------------------------------------------------

function _boot_config_box64() {
    if [[ -f /boot/firmware/config.txt ]]; then
        echo "/boot/firmware/config.txt"
    else
        echo "/boot/config.txt"
    fi
}

function _has_kernel8_box64() {
    grep -qE '^\s*kernel\s*=\s*kernel8\.img\s*$' "$(_boot_config_box64)" 2>/dev/null
}

# ----- install manifest helpers -------------------------------------------------

# _archive_box64 MANIFEST TARFILE - archive the files listed in a make install manifest
function _archive_box64() {
    local manifest="$1"
    local out="$2"
    local files=()
    local file
    while read -r file; do
        [[ -n "$file" && -e "$file" ]] && files+=("$file")
    done < "$manifest"
    [[ "${#files[@]}" -eq 0 ]] && return 1
    tar -cPf "$out" -- "${files[@]}"
}

# _remove_files_box64 MANIFEST - delete the files listed in a manifest, and any
# box64 folders left empty
function _remove_files_box64() {
    local manifest="$1"
    local file
    local dirs=()
    while read -r file; do
        [[ -z "$file" ]] && continue
        rm -f "$file"
        [[ "${file%/*}" == *box64* ]] && dirs+=("${file%/*}")
    done < "$manifest"
    local dir
    while read -r dir; do
        [[ -n "$dir" ]] && rmdir --ignore-fail-on-non-empty "$dir" 2>/dev/null
    done < <(printf '%s\n' "${dirs[@]}" | sort -ru)
}

# ----- module functions ---------------------------------------------------------

function depends_box64() {
    getDepends git build-essential cmake python3
}

function sources_box64() {
    # always start from a fresh clone, so switching between the latest source
    # and a release tag can't trip over an old checkout
    find "$md_build" -mindepth 1 -delete 2>/dev/null
    gitPullOrClone
}

function build_box64() {
    # the same build as the manual install: no RetroPie compiler flags, all 4 cores
    rm -rf "$md_build/build"
    runCmd env -u CFLAGS -u CXXFLAGS -u ASFLAGS -u LDFLAGS \
        cmake -S "$md_build" -B "$md_build/build" -DRPI5ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo
    runCmd env -u CFLAGS -u CXXFLAGS -u ASFLAGS -u LDFLAGS \
        make -C "$md_build/build" -j"$(nproc)"
    md_ret_require=("$md_build/build/box64")
}

function install_box64() {
    local build="$md_build/build"
    local new_commit="$(git -C "$md_build" rev-parse HEAD 2>/dev/null)"
    local old_commit="$(_info_get_box64 "$md_inst/current.info" commit)"

    # keep the Box64 being replaced, so it can be restored from Configuration / Options
    if [[ -f "$md_inst/install_manifest.txt" && -n "$old_commit" && "$old_commit" != "$new_commit" ]]; then
        if _archive_box64 "$md_inst/install_manifest.txt" "$md_inst/previous.tar.new"; then
            mv -f "$md_inst/previous.tar.new" "$md_inst/previous.tar"
            cp -f "$md_inst/install_manifest.txt" "$md_inst/previous_manifest.txt"
            cp -f "$md_inst/current.info" "$md_inst/previous.info"
            printMsgs "console" "Kept the previous Box64 build ($(_info_get_box64 "$md_inst/previous.info" version))"
        else
            rm -f "$md_inst/previous.tar.new"
        fi
    fi

    runCmd env -u CFLAGS -u CXXFLAGS -u ASFLAGS -u LDFLAGS make -C "$build" install || return 1
    cp -f "$build/install_manifest.txt" "$md_inst/install_manifest.txt"

    local version="$(timeout 10 "$build/box64" --version 2>/dev/null | grep -m1 -i 'box64')"
    cat > "$md_inst/current.info" <<_EOF_
version="$version"
branch="$(_branch_box64)"
commit="$new_commit"
date="$(date -Iseconds)"
_EOF_

    systemctl restart systemd-binfmt
    md_ret_require=("/usr/local/bin/box64")
}

function configure_box64() {
    [[ "$md_mode" == "remove" ]] && return

    local config="$(_boot_config_box64)"
    if [[ ! -f "$config" ]]; then
        md_ret_info+=("Box64: could not find $config - please check that kernel=kernel8.img is set (Box64 and Wine need the 4KB page kernel on the Pi 5).")
    elif ! _has_kernel8_box64; then
        cp -p "$config" "$config.bak-box64"
        printf '\n[all]\nkernel=kernel8.img\n' >> "$config"
        md_ret_info+=("Box64: added kernel=kernel8.img to the end of $config (under [all]).\n\nBackup: $config.bak-box64\n\nPlease reboot before running any Windows games.")
    fi

    local pagesize="$(getconf PAGESIZE)"
    if [[ "$pagesize" != "4096" ]]; then
        md_ret_info+=("Box64: the running kernel uses ${pagesize}-byte pages. Box64 and Wine need 4096 - please reboot so kernel=kernel8.img takes effect.")
    fi
}

function remove_box64() {
    if [[ -f "$md_inst/install_manifest.txt" ]]; then
        _remove_files_box64 "$md_inst/install_manifest.txt"
    else
        # no manifest - fall back to the files "make install" puts in place
        rm -f /usr/local/bin/box64 /etc/binfmt.d/box64.conf /etc/box64.box64rc
        rm -rf /usr/lib/box64-x86_64-linux-gnu /usr/lib/box64-i386-linux-gnu
    fi
    rm -f "$(_config_box64)"
    systemctl restart systemd-binfmt

    md_ret_info+=("Box64 has been removed.\n\nkernel=kernel8.img has been left in place in:\n\n$(_boot_config_box64)\n\nIt is harmless, and Wine needs it if Box64 is installed again. Remove the line by hand if you no longer want the 4KB page kernel.")
}

# ----- Configuration / Options --------------------------------------------------

function _tags_box64() {
    git ls-remote --tags --refs "$(rp_resolveRepoParam "$md_repo_url")" 2>/dev/null \
        | awk -F/ '{print $3}' | grep -E '^v[0-9]' | sort -rV
}

# run an install with its output shown on screen as well as written to the log
function _install_now_box64() {
    clear
    rp_callModule "$md_id" _source_ > >(tee /dev/tty) 2>&1
    sleep 1
}

function _choose_version_box64() {
    local current="$(_get_setting_box64 version latest)"

    dialog --backtitle "$__backtitle" --infobox "Getting the list of Box64 releases ..." 3 50 >/dev/tty
    local tags=()
    mapfile -t tags < <(_tags_box64)
    if [[ "${#tags[@]}" -eq 0 ]]; then
        printMsgs "dialog" "Could not get the list of Box64 releases from GitHub. Please check your network connection."
        return
    fi

    local options=(latest "Latest source code (main branch)")
    local tag
    for tag in "${tags[@]}"; do
        options+=("$tag" "Release $tag")
    done

    local cmd=(dialog --backtitle "$__backtitle" --cancel-label "Back" --default-item "$current" \
        --menu "Which Box64 should be built?\n\nCurrently chosen: $current\n\n'latest' follows the newest source code on every update. A release stays on that release until you choose something else." 22 76 12)
    local choice
    choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
    [[ -z "$choice" ]] && return

    _set_setting_box64 version "$choice"
    rp_clearCachedInfo "$md_id"

    # build if a different branch / tag was chosen, the chosen one has new
    # commits, or the box64 program is missing (e.g. removed by another package)
    local installed_branch="$(_info_get_box64 "$md_inst/current.info" branch)"
    local need=1
    if [[ "$(_branch_box64)" == "$installed_branch" && -x /usr/local/bin/box64 ]]; then
        local __ignore_module_date=1
        rp_hasNewerModule "$md_id" "source"
        [[ "$?" -eq 0 ]] || need=0
    fi
    if [[ "$need" -eq 1 ]]; then
        if dialog --backtitle "$__backtitle" --yesno "Build and install Box64 ($choice) now?\n\nThis takes several minutes. If you choose No, it will be built the next time you choose Update." 12 70 2>&1 >/dev/tty; then
            _install_now_box64
        fi
    elif dialog --backtitle "$__backtitle" --defaultno --yesno "Box64 ($choice) is already installed and up to date.\n\nBuild and install it again anyway (e.g. if its files were changed or removed)? This takes several minutes." 12 70 2>&1 >/dev/tty; then
        _install_now_box64
    fi
}

# swap two files (either may be missing)
function _swap_box64() {
    local a="$1" b="$2"
    local tmp="$a.swap"
    [[ -e "$a" ]] && mv -f "$a" "$tmp"
    [[ -e "$b" ]] && mv -f "$b" "$a"
    [[ -e "$tmp" ]] && mv -f "$tmp" "$b"
}

function _restore_box64() {
    if [[ ! -f "$md_inst/previous.tar" || ! -f "$md_inst/install_manifest.txt" ]]; then
        printMsgs "dialog" "There is no previous Box64 build to restore."
        return
    fi

    local cur="$(_info_get_box64 "$md_inst/current.info" version)"
    local prev="$(_info_get_box64 "$md_inst/previous.info" version)"
    dialog --backtitle "$__backtitle" --defaultno --yesno "Restore the previous Box64 build?\n\nInstalled now: $cur\nPrevious:      $prev\n\nThe build installed now is kept, so you can swap back the same way." 14 76 2>&1 >/dev/tty || return

    if ! _archive_box64 "$md_inst/install_manifest.txt" "$md_inst/current.tar"; then
        printMsgs "dialog" "Could not back up the installed Box64 - nothing was changed."
        return
    fi
    _remove_files_box64 "$md_inst/install_manifest.txt"
    if ! tar -xpPf "$md_inst/previous.tar"; then
        tar -xpPf "$md_inst/current.tar"
        rm -f "$md_inst/current.tar"
        printMsgs "dialog" "Could not restore the previous build - the installed Box64 has been put back."
        return
    fi

    mv -f "$md_inst/current.tar" "$md_inst/previous.tar"
    _swap_box64 "$md_inst/install_manifest.txt" "$md_inst/previous_manifest.txt"
    _swap_box64 "$md_inst/current.info" "$md_inst/previous.info"
    systemctl restart systemd-binfmt

    # keep 'Package version information' in step with what is now installed
    if [[ -f "$md_inst/retropie.pkg" ]]; then
        iniConfig "=" '"' "$md_inst/retropie.pkg"
        iniSet "pkg_repo_branch" "$(_info_get_box64 "$md_inst/current.info" branch)"
        iniSet "pkg_repo_commit" "$(_info_get_box64 "$md_inst/current.info" commit)"
    fi
    rp_clearCachedInfo "$md_id"

    local msg="Box64 restored:\n\n$(_installed_version_box64)"
    local chosen="$(_get_setting_box64 version latest)"
    local restored="$(_info_get_box64 "$md_inst/current.info" branch)"
    if [[ "$(_branch_box64)" != "$restored" ]]; then
        [[ "$restored" == "main" ]] && restored="latest"
        msg+="\n\nNote: Box64 is set to build '$chosen', so Update would build that again. To keep this build, choose '$restored' under 'Choose which Box64 to build'."
    elif [[ "$chosen" == "latest" ]]; then
        msg+="\n\nNote: 'latest' is chosen, so Update will build the newest source code again when there are new changes. To stay on a fixed version, choose a release under 'Choose which Box64 to build'."
    fi
    printMsgs "dialog" "$msg"
}

function _status_box64() {
    local pagesize="$(getconf PAGESIZE)"
    local page_msg="$pagesize - OK"
    [[ "$pagesize" != "4096" ]] && page_msg="$pagesize - needs kernel=kernel8.img and a reboot"
    local kernel8="no"
    _has_kernel8_box64 && kernel8="yes"
    local binfmt="no"
    [[ -e /proc/sys/fs/binfmt_misc/box64 ]] && binfmt="yes"
    local prev="none"
    [[ -f "$md_inst/previous.tar" ]] && prev="$(_info_get_box64 "$md_inst/previous.info" version)"
    local commit="$(_info_get_box64 "$md_inst/current.info" commit)"

    printMsgs "dialog" "Installed: $(_installed_version_box64)\nBuilt from: $(_info_get_box64 "$md_inst/current.info" branch) ${commit:0:9}\nChosen to build: $(_get_setting_box64 version latest)\nPrevious build kept: $prev\n\nPage size: $page_msg\nkernel=kernel8.img in $(_boot_config_box64): $kernel8\nRegistered for x86_64 programs (binfmt): $binfmt"
}

function gui_box64() {
    local default
    while true; do
        local version="$(_get_setting_box64 version latest)"
        local options=(1 "Choose which Box64 to build (now: $version)")
        if [[ -f "$md_inst/previous.tar" ]]; then
            options+=(2 "Restore previous build ($(_info_get_box64 "$md_inst/previous.info" version))")
        fi
        options+=(3 "Status")

        local cmd=(dialog --backtitle "$__backtitle" --cancel-label "Back" --default-item "$default" \
            --menu "Box64 options\n\nInstalled: $(_installed_version_box64)" 16 76 6)
        local choice
        choice=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
        default="$choice"
        case "$choice" in
            1) _choose_version_box64 ;;
            2) _restore_box64 ;;
            3) _status_box64 ;;
            *) break ;;
        esac
    done
}
