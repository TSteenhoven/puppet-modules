#!/bin/sh
# Managed by puppet

# Check if date is available
DATE=/usr/bin/date
test -x $DATE || exit 1

# Check if grep is available
GREP=/usr/bin/grep
test -x $GREP || exit 1

# Check if mail is available
MAIL=/usr/bin/mail
test -x $MAIL || exit 1

# Check if whoami is available
WHOAMI=/usr/bin/whoami
test -x $WHOAMI || exit 1

# Current date
NOW=$($DATE)
TARGET_USER=$($WHOAMI)

# Check if user variable is not given
if [ -z "$USER" ]; then
	USER="$TARGET_USER"
    TARGET_USER="${1:-root}"
fi

# Try to get IP
IP_TMP=$(who -u am i | awk '{print $NF}' | tr -d '()')
if [ -z "$IP_TMP" ]; then
    IP="$IP_TMP"
else
    IP="UNKNOWN"
fi

# Chec if we are in interactive shell
if echo "$0" | $GREP -q '^-'; then
    if [[ "$TARGET_USER" = "root" ]]; then
        printf "\033[0;31mYou login as root, this action is registered and sent to the server administrator(s).\033[0m\n"
    elif [ "$TARGET_USER" = "$USER" ]; then
        printf "\033[0;36mYour IP (%s), login time (%s) and username (%s) have been registered and sent to the server administrator(s).\033[0m\n" "$IP" "$NOW" "$USER"
    else
        printf "\033[0;36mYou login as $TARGET_USER, this action is registered and sent to the server administrator(s).\033[0m\n"
    fi
fi

# Send message
if [ "$TARGET_USER" = "root" ]; then
    printf '%b\n' "User $USER logged in as root into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit $USER logged in as root" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
elif [ "$TARGET_USER" = "$USER" ]; then
    printf '%b\n' "User $USER logged into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit login $USER" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
else
    printf '%b\n' "User $USER logged in as $TARGET_USER into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit $USER logged in as $TARGET_USER" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
fi