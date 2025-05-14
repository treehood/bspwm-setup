#! /bin/bash

color_reset="\033[0m"
color_red="\033[31m"
color_green="\033[32m"
color_yellow="\033[33m"
color_blue="\033[34m"

has_color_support()
{
    case "$TERM" in
        xterm-color|*-256color|alacritty)
            return 0
            ;;
    esac

    return 1
}

log_log()
{
    # if [ "$flag_log_level" -gt "$1" ]; then
    #     return
    # fi

    if has_color_support; then
        echo -n "$(date '+%Y-%m-%d %H:%M:%S') "
        echo -e "[$1$2${color_reset}]: $3"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$2]: $3"
    fi
}

log_success()
{
    log_log "${color_green}" "SUCCESS" "$1"
}

log_info()
{
    log_log "${color_blue}" "INFO" "$1"
}

log_warning()
{
    log_log  "${color_yellow}" "WARNING" "$1"
}

log_error()
{
    log_log "${color_red}" "ERROR" "$1"
}
