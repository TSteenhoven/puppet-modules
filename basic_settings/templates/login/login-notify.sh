#!/bin/sh
# Managed by puppet

# Check if mail is available
MAIL=/usr/bin/mail
test -x $MAIL || exit 1

# Check if date is available
DATE=/usr/bin/date
test -x $DATE || exit 1

# Check if whoami is available
WHOAMI=/usr/bin/whoami
test -x $WHOAMI || exit 1

# Current date
NOW=$($DATE)
CURRENT_USER=${$WHOAMI}

# Try to get IP
if [ -n "$(echo $SSH_CLIENT)" ]; then
    IP=$(echo $SSH_CLIENT | awk '{ print $1}')
elif [ -n "$(echo $SSH_CONNECTION)" ]; then
    IP=$(echo $SSH_CONNECTION | awk '{ print $1}')
else
    IP="UNKNOWN"
fi

# Chec if we are in interactive shell
if [[ "$0" =~ ^- ]]; then
    if [[ "$CURRENT_USER" = "root" ]]; then
        printf "\033[0;31mYou login as root, this action is registered and sent to the server administrator(s).\033[0m\n"
    else
        printf "\033[0;36mYour IP (%s), login time (%s) and username (%s) have been registered and sent to the server administrator(s).\033[0m\n" "$IP" "$NOW" "$USER"
    fi    
fi

# Send message
if [ "$CURRENT_USER" = "root" ]; then
    printf '%b\n' "User $USER logged in as root into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit root login $USER" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
else
    printf '%b\n' "User $USER logged into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit login $USER" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
fi