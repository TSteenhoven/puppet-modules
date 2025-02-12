#!/bin/sh
# Managed by puppet

# Check if awk is available
AWK=/usr/bin/awk
test -x $AWK || exit 1

# Check if date is available
DATE=/usr/bin/date
test -x $DATE || exit 1

# Check if head is available
HEAD=/usr/bin/head
test -x $HEAD || exit 1

# Check if last is available
LAST=/usr/bin/last
test -x $LAST || exit 1

# Check if mail is available
if [ -z"$MAIL" ]; then
    MAIL=/usr/bin/mail
    test -x $MAIL || exit 1
fi

# Check if PAM values exits
if [ -n "$PAM_RUSER" ]; then
    USER="$PAM_RUSER"
    TARGET_USER="$PAM_USER"
else
    # Check if whoami is available
    WHOAMI=/usr/bin/whoami
    test -x $WHOAMI || exit 1
    TARGET_USER=$($WHOAMI)
fi

# Try to get IP
if [ -n "$SSH_CLIENT" ]; then
    IP=$(echo $SSH_CLIENT | $AWK '{ print $1}')
elif [ -n "$SSH_CONNECTION" ]; then
    IP=$(echo $SSH_CONNECTION | $AWK '{ print $1}')
else
    IP_TMP=$($LAST -i -n 1 $USER | $AWK '{print $3}' | $HEAD -n 1)
    if [ -n "$IP_TMP" ]; then
        IP="$IP_TMP"
    else
        IP="UNKNOWN"
    fi
fi

# Set variables
NOW=$($DATE)

# Chec if we are in interactive shell
if [ -n "$PS1" ]; then
    if [[ "$TARGET_USER" = "root" ]]; then
        printf "\033[0;31mYou login as root, this action is registered and sent to the server administrator(s).\033[0m\n"
    elif [ "$TARGET_USER" = "$USER" ]; then
        printf "\033[0;36mYour IP (%s), login time (%s) and username (%s) have been registered and sent to the server administrator(s).\033[0m\n" "$IP" "$NOW" "$USER"
    else
        printf "\033[0;36mYou login as $TARGET_USER, this action is registered and sent to the server administrator(s).\033[0m\n"
    fi
fi

# Send message
if [ "$TARGET_USER" = "$USER" ]; then
    printf '%b\n' "User $USER logged into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit login $USER" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
else
    printf '%b\n' "User $USER logged in as $TARGET_USER into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit $USER logged in as $TARGET_USER" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
fi