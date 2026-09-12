# Managed by Puppet.
# Set the interactive shell idle timeout to <%= @tmout %> seconds.
case $- in
    *i*)
        # Preserve an existing readonly value when a running shell reloads its profile.
        if (unset TMOUT) 2>/dev/null; then
            TMOUT=<%= @tmout %>
        fi
        readonly TMOUT
        export TMOUT
        ;;
esac
