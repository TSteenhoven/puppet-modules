# Managed by puppet

# Check if mail is available
MAIL=/usr/bin/mail
test -x $MAIL || exit 1

# Current date
NOW=$(date)

# Try to get IP
if [ -n "$(echo $SSH_CLIENT)" ]; then
    IP=$(echo $SSH_CLIENT | awk '{ print $1}')
elif [ -n "$(echo $SSH_CONNECTION)" ]; then
    IP=$(echo $SSH_CONNECTION | awk '{ print $1}')
else
    IP="UNKNOWN"
fi

# Chec if we are in interactive shell
if [ -n "$PS1" ]; then
    # Show message 
    if [ "$USER" = "root" ]; then
        printf "\033[0;31mYou login as root, this action is registered and sent to the server administrator(s).\033[0m\n"
    else
        printf "\033[0;36mYour IP ($IP), login time ($NOW) and username ($USER) have been registered and sent to the server administrator(s).\033[0m\n"
    fi
fi

# Send message
printf '%b\n' "User $USER logged into the <%= @server_fdqn %> at $NOW\nIP: $IP" | $MAIL -s "Audit login $USER" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"