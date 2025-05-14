#! /bin/bash

dir_script=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
source "$dir_script/common.sh"

# Implement your functions here!

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "executing as a script..."
fi
