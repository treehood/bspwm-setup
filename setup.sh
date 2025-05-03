#! /bin/bash

# =============================================================================
# Script Name: install_and_setup.sh
# Description: A script to install and setup packages for a bspwm desktop
#              environment based on Debian.
# Author: treehood
# =============================================================================

level_info=0
level_warning=1
level_error=2
color_reset="\033[0m"
color_bold="\033[1m"
color_red="\033[31m"
color_green="\033[32m"
color_yellow="\033[33m"
color_blue="\033[34m"
color_magenta="\033[35m"
color_cyan="\033[36m"
color_white="\033[37m"

usage()
{
    echo "Usage: $0 [OPTION]..."
    echo "Install and setup packages on a plain Debian distro."
    echo "  -d          log changes without making system modifications."
    echo "  -l          set log level to 'info', 'warning', or 'error'."
    echo "  -s          symlink dot files"
    echo "  -h          show this help message."
}

flag_dry_run=0
flag_log_level=$level_info
flag_symlink=0
while getopts "dl:sh" opt; do
    case $opt in
        d)
            flag_dry_run=1
            ;;
        l)
            if [ "$OPTARG" == "info" ]; then
                flag_log_level=$level_info
            elif [ "$OPTARG" == "warning" ]; then
                flag_log_level=$level_warning
            elif [ "$OPTARG" == "error" ]; then
                flag_log_level=$level_error
            else
                usage
                exit 1
            fi
            ;;
        s)
            flag_symlink=1
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# Get script absolute path, it should be in the same location as resources.
dir_script=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")

color_support=false
if [[ -n "$TERM" && "$TERM" != "dumb" && "$TERM" != "linux" && -t 1 ]]; then
    color_support=true
fi

log_log()
{
    if [ "$flag_log_level" -gt "$1" ]; then
        return
    fi

    if $color_support; then
        echo -n "$(date '+%Y-%m-%d %H:%M:%S') "
        echo -e "[$2$3${color_reset}]: $4"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$3]: $4"
    fi
}

log_success()
{
    log_log "$level_info" "${color_green}" "SUCCESS" "$1"
}

log_info()
{
    log_log "$level_info" "${color_blue}" "INFO" "$1"
}

log_warning()
{
    log_log "$level_info" "${color_yellow}" "WARNING" "$1"
}

log_error()
{
    log_log "$level_info" "${color_red}" "ERROR" "$1"
}

log_exec()
{
    if [ "$flag_dry_run" -eq 0 ]; then
        local res=1
        eval "$1 && res=0"

        if [ "$res" -ne 0 ]; then
            log_error "failed to exec: '$1'"
        fi

        return $res
    fi

    if $color_support; then
        echo -n "$(date '+%Y-%m-%d %H:%M:%S') "
        echo -e "[${color_magenta}DRY${color_reset}]: $1"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DRY]: $1"
    fi

    return 0
}

function install_packages()
{
    local res=0
    log_info "installing packages..."
    # Get each line, omit lines starting with `#` or empty lines.
    local package_list=$(grep -v -e '^#' -e '^$' "$dir_script/packages.txt")

    while IFS= read -r line; do
        log_info "installing $line..."
        # Check if the package exists in apt.
        apt-cache show "$line" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_error "failed to find package: '$line'"
            res=1
            continue
        fi

        # Check if the package is already installed.
        # We do not just check against the return code because this can return
        # zero, but can return a message like "deinstall ok config-files",
        # indicating the package is actually uninstalled but config files are
        # remaining.
        local pkg_status=$(dpkg-query -W -f='${Status}' $line 2>/dev/null)
        if [[ "$pkg_status" == "install ok installed" ]]; then
            log_info "already installed: '$line'"
            continue
        fi

        # Install the package with apt.
        log_exec "apt-get install -y \"$line\" > /dev/null 2>&1"

        # Check the install status.
        if [ $? -ne 0 ]; then
            log_error "failed to install: '$line'"
            res=1
        else
            log_success "successfully installed: '$line'"
        fi
    done <<< "$package_list"

    return "$res"
}

function setup_dots()
{
    local dir_dots="$dir_script/dots/"
    # Create a tmp directory for any files replaced with symlinks.
    local dir_tmp=$(mktemp -d /tmp/dots.XXXXXX)

    # Enable globstar for recursive globbing.
    # This is only available as of Bash 4+.
    shopt -s globstar
    for filepath in "$dir_dots"**/*; do
        if [ ! -f "$filepath" ]; then
            continue
        fi

        # Get the file path relative to the 'dots' folder.
        local path_relative=$(echo "$filepath" | sed "s#$dir_dots##")
        local dir_local=$(dirname "$path_relative")
        local file_local=$(basename "$path_relative")

        # Check that directory is not hidden, skip if it is.
        if [[ ${#dir_local} -gt 1 && $dir_local == \.* ]]; then
            log_err "directory should not be hidden, skipping: '$dir_local'"
            continue
        fi

        # Check that file is not hidden, skip if it is.
        if [[ ${#file_local} -gt 1 && $file_local == \.* ]]; then
            log_err "file should not be hidden, skipping: '$file_local'"
            continue
        fi

        # Declare dot file and directory with dot placement on file or dir.
        # Assume the non-nested case, check if file is nested and adjust.
        local to_make_dir=""
        local to_make_file="$HOME/.$file_local"
        if [[ "$dir_local" != "." ]]; then
            to_make_dir="$HOME/.$dir_local"
            to_make_file="$to_make_dir/$file_local"
        fi

        # Make necessary directory(s) for dot files.
        if [[ "$to_make_dir" != "" && ! -d "$to_make_dir" ]]; then
            log_info "directory does not exist, making: '$to_make_dir'"
            log_exec "mkdir -p \"$to_make_dir\""
        fi

        # Move or remove any pre-existing dot files.
        if [ -L "$to_make_file" ]; then
            # Remove symlinks, they already exist elsewhere.
            log_warning "removing symlink: '$to_make_file'"
            log_exec "rm \"$to_make_file\""
        elif [ -f "$to_make_file" ]; then
            # Backup file to tmp dir if one already exists.
            local dst="$dir_tmp/$dir_local/"
            if [ "$dir_local" == "." ]; then
                dst="$dir_tmp"
            fi
            local dst_filename="$dst/$file_local"

            log_warning "moving '$to_make_file' to '$dst_filename'"
            log_exec "mkdir -p \"$dst\""
            log_exec "mv \"$to_make_file\" \"$dst_filename\""
        fi

        # Create dot file symlink
        if [ $flag_symlink -ne 0 ]; then
            log_info "creating symlink: '$filepath' -> '$to_make_file'"
            log_exec "ln -s \"$filepath\" \"$to_make_file\""
        else
            log_info "copying files: '$filepath' -> '$to_make_file'"
            log_exec "cp \"$filepath\" \"$to_make_file\""
        fi
    done
}

function setup_dirs()
{
    log_info "setting up directories..."

    # XXX: Ideally this is set from a file, however due to the nature of
    # `xdg-user-dirs-update` (it performs an eval without doing sanity checks
    # on input), we do it this way for now.
    # The file that contains these mappings is: `user-dirs.dirs`.

    log_info "making home directories..."

    log_exec "mkdir -p \"$HOME/art\""
    log_exec "mkdir -p \"$HOME/code\""
    log_exec "mkdir -p \"$HOME/files\""
    log_exec "mkdir -p \"$HOME/files/templates\""
    log_exec "mkdir -p \"$HOME/files/public\""
    log_exec "mkdir -p \"$HOME/media/photos\""
    log_exec "mkdir -p \"$HOME/media/images\""
    log_exec "mkdir -p \"$HOME/media/music\""
    log_exec "mkdir -p \"$HOME/media/video\""
    log_exec "mkdir -p \"$HOME/tmp\""

    log_info "finished making home directories"

    log_info "updating xdg user dirs..."

    log_exec "xdg-user-dirs-update --set DESKTOP     \"$HOME/tmp\""
    log_exec "xdg-user-dirs-update --set DOCUMENTS   \"$HOME/files\""
    log_exec "xdg-user-dirs-update --set DOWNLOAD    \"$HOME/tmp\""
    log_exec "xdg-user-dirs-update --set MUSIC       \"$HOME/media/music\""
    log_exec "xdg-user-dirs-update --set PICTURES    \"$HOME/media/images\""
    log_exec "xdg-user-dirs-update --set PUBLICSHARE \"$HOME/files/public\""
    log_exec "xdg-user-dirs-update --set TEMPLATES   \"$HOME/files/templates\""
    log_exec "xdg-user-dirs-update --set VIDEOS      \"$HOME/media/video"\"

    log_info "finished updating xdg user dirs"

    log_info "finished setting up directories"

    return 0
}

log_info "running as '$(whoami)'..."

if [ "$EUID" -eq 0 ]; then
    if [ -n "$SUDO_UID" ]; then
        original_uid="$SUDO_UID"

        install_packages

        # Rerun script as original user.
        sudo -u "#$original_uid" "$0" "$@"
        exit 0
    else
        log_error "sudo user id is not set, this should not happen"
        exit 1
    fi
else
    setup_dots

    setup_dirs
fi
