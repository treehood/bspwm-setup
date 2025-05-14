#! /bin/bash

dir_script=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
source "$dir_script/common.sh"

function install_packages()
{
    log_info "installing packages..."

    if [ "$EUID" -ne 0 ]; then
        log_error "cannot install packages as non-root user"
        return 1
    fi

    local pkg_list_file="$dir_script/../packages.txt"
    if [ ! -f "$pkg_list_file" ]; then
        log_error "unable to find file with package list"
        return 1
    fi

    # Get each line, omit lines starting with `#` or empty lines.
    local pkg_list=$(grep -v -e '^#' -e '^$' "$pkg_list_file")

    while IFS= read -r line; do
        log_info "installing $line..."
        # Check if the package exists in apt.
        apt-cache show "$line" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_error "failed to find package: '$line'"
            return 1
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
        apt-get install -y "$line" > /dev/null 2>&1

        # Check the install status.
        if [ $? -ne 0 ]; then
            log_error "failed to install: '$line'"
            return 1
        else
            log_success "successfully installed: '$line'"
        fi
    done <<< "$pkg_list"

    log_success "installed all packages"

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_packages
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi
