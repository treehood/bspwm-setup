#! /bin/bash

dir_script=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
source "$dir_script/common.sh"

function install_dots()
{
    flag_symlink=0
    if [ -n "$1" ]; then
        flag_symlink=$1
    fi

    log_info "installing dot files..."

    local dir_dots="$dir_script/../dots/"
    if [ ! -d "$dir_dots" ]; then
        log_error "unable to find file with package list"
        return 1
    fi

    # Create a tmp directory for any files replaced.
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
            log_warning "directory hidden, skipping: '$dir_local'"
            continue
        fi

        # Check that file is not hidden, skip if it is.
        if [[ ${#file_local} -gt 1 && $file_local == \.* ]]; then
            log_warning "file hidden, skipping: '$file_local'"
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
            mkdir -p "$to_make_dir"
        fi

        # Move or remove any pre-existing dot files.
        if [ -L "$to_make_file" ]; then
            # Remove symlinks, they already exist elsewhere.
            log_warning "removing symlink: '$to_make_file'"
            rm "$to_make_file"
        elif [ -f "$to_make_file" ]; then
            # Backup file to tmp dir if one already exists.
            local dst="$dir_tmp/$dir_local/"
            if [ "$dir_local" == "." ]; then
                dst="$dir_tmp"
            fi
            local dst_filename="$dst/$file_local"

            log_warning "backing up '$to_make_file' to '$dst_filename'"
            mkdir -p "$dst"
            mv "$to_make_file" "$dst_filename"
            if [ $? -ne 0 ]; then
                log_error "failed to backup file '$to_make_file'"
                return 1
            fi
        fi

        if [ $flag_symlink -ne 0 ]; then
            log_info "creating symlink: '$filepath' -> '$to_make_file'"
            ln -s "$filepath" "$to_make_file"
        else
            log_info "copying files: '$filepath' -> '$to_make_file'"
            cp "$filepath" "$to_make_file"
        fi
    done

    log_success "completed installing dot files"

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    flag_symlink=0
    while getopts "sh" opt; do
        case $opt in
            s)
                flag_symlink=1
                ;;
            h)
                echo "Usage: $0 [OPTION]..."
                echo "Install dot files by copy or symlink."
                echo "  -s          symlink dot files"
                echo "  -h          show this help message."
                exit 0
                ;;
            *)
                exit 1
                ;;
        esac
    done

    install_dots "$flag_symlink"
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi
