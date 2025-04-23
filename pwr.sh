#!/bin/bash

# szmelc universal power manager (init-independent)
# [PWR] [v2]
# DEPENDENCIES: dialog, root
# cat /tmp/pwr.log to see current state of delay timer.

sudo -v

sleep_cmd="echo mem > /sys/power/state"
hibernate_cmd="echo disk > /sys/power/state"
shutdown_cmd="poweroff"
reboot_cmd="reboot"
log_file="/tmp/pwr.log"

# Parse delay string into seconds
parse_delay() {
    local d="$1"
    case "$d" in
        *s) echo "${d%s}" ;;
        *m) echo "$(( ${d%m} * 60 ))" ;;
        *h) echo "$(( ${d%h} * 3600 ))" ;;
        *) echo "$d" ;;
    esac
}

# Countdown writer (runs in background)
write_countdown_log() {
    local sec=$1
    local action=$2

    while [ "$sec" -gt 0 ]; do
        echo "Action \"$action\" in $sec seconds." > "$log_file"
        sleep 1
        sec=$((sec - 1))
    done
    echo "Executing \"$action\" now..." > "$log_file"
}

# Perform action, maybe delayed
perform_action() {
    action=$1
    delay=$2

    if [ "$delay" == "NOW" ]; then
        echo "Executing: $action"
        sudo sh -c "$action"
    else
        sec=$(parse_delay "$delay")
        echo "Preparing delayed execution of \"$action\" in $sec seconds..."
        write_countdown_log "$sec" "$action" &
        log_pid=$!
        sudo sh -c "sleep $sec; kill $log_pid; rm -f $log_file; $action"
    fi
}

# Main menu
CHOICE=$(dialog --clear --backtitle "Power Management" --title "Choose Action" \
        --menu "Select a power action:" 15 50 4 \
        "1" "Shutdown" \
        "2" "Reboot" \
        "3" "Sleep" \
        "4" "Hibernate" 2>&1 >/dev/tty)

[ $? -ne 0 ] && exit 0

# Timing menu
TIME_CHOICE=$(dialog --clear --backtitle "Timing" --title "Choose Timing" \
             --menu "Select when to perform the action:" 15 50 3 \
             "1" "NOW" \
             "2" "DELAY" 2>&1 >/dev/tty)

[ $? -ne 0 ] && exit 0

# Delay input
if [ "$TIME_CHOICE" == "2" ]; then
    DELAY=$(dialog --title "Enter Delay" --inputbox "Enter delay (e.g. 30s, 5m, 1h):" 8 40 2>&1 >/dev/tty)
    [ $? -ne 0 ] && exit 0
else
    DELAY="NOW"
fi

# Perform
case $CHOICE in
    1)
        perform_action "$shutdown_cmd" "$DELAY"
        ;;
    2)
        perform_action "$reboot_cmd" "$DELAY"
        ;;
    3)
        if grep -q mem /sys/power/state; then
            perform_action "$sleep_cmd" "$DELAY"
        else
            dialog --msgbox "Sleep not supported on this system." 6 40
        fi
        ;;
    4)
        if grep -q disk /sys/power/state; then
            perform_action "$hibernate_cmd" "$DELAY"
        else
            dialog --msgbox "Hibernate not supported on this system." 6 40
        fi
        ;;
esac

clear
