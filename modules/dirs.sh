#! /bin/bash

dir_script=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
source "$dir_script/common.sh"

setup_dirs()
{
    log_info "setting up directories..."

    local dir_list_file="$dir_script/../dirs.txt"
    if [ ! -f "$dir_list_file" ]; then
        log_error "unable to find file with dir list"
        return 1
    fi

    local dir_list=$(grep -v -e '^#' -e '^$' "$dir_list_file")
    while IFS= read -r line; do
        if [[ ${#line[@]} -gt 2 ]]; then
            log_error "encountered unexpected word count in dir file"
            return 1
        fi

        OLD_IFS=$IFS
        IFS=' ' read -ra words <<< "$line"
        IFS=$OLD_IFS

        local first="${words[0]}"

        local second=""
        if [[ ${#words[@]} -eq 2 ]]; then
            second="${words[1]}"
            case "$second" in
                "DESKTOP"|"DOCUMENTS"|"DOWNLOAD"|"MUSIC"|"PICTURES"\
                |"PUBLICSHARE"|"TEMPLATES"|"VIDEOS")
                    ;;
                *)
                    log_error "invalid xdg dir name: '$second'"
                    return 1
                    ;;
            esac
        fi

        local dir_full="$HOME/$first"
        mkdir -p "$dir_full"
        if [ $? -ne 0 ]; then
            log_error "failed to create dir: '$dir_full'"
            return 1
        fi

        if [ -z "$second" ]; then
            log_success "created directory '$dir_full'"
            continue
        fi

        # Note, xdg-user-dir facilitates arbitrary code execution from
        # unsanitized input. This is being used with a file inputs, which
        # should be checked before running this.
        xdg-user-dirs-update --set "$second" "$HOME/$first"
        if [ $? -ne 0 ]; then
            log_error "failed to updated xdg dir: '$second' to '$dir_full'"
            return 1
        else
            log_success "created directory '$dir_full' mapped to '$second'"
        fi
    done <<< "$dir_list"

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_dirs
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi
