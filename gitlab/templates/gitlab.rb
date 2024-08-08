## Managed by puppet
<% if @https -%>
external_url 'https://<%= @server_fdqn %>'
<% else -%>
external_url 'http://<%= @server_fdqn %>'
<% end -%>
gitlab_rails['gitlab_email_enabled'] = <%= (@smtp_enable ? "true" : "false") %>
<% if ! @ssh_host.nil? -%>
gitlab_rails['gitlab_ssh_host'] = '<%= @ssh_host %>'
<% end -%>
gitlab_rails['incoming_email_enabled'] = false
gitlab_rails['smtp_enable'] = <%= (@smtp_enable ? "true" : "false") %>
<% if @smtp_enable -%>
gitlab_rails['smtp_address'] = '<%= @smtp_server %>'
gitlab_rails['smtp_port'] = 25
gitlab_rails['gitlab_email_from'] = 'gitlab@<%= @server_fdqn %>'
gitlab_rails['gitlab_email_display_name'] = 'Gitlab'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@<%= @server_fdqn %>'
<% end -%>
letsencrypt['enable'] = <%= (@letsencrypt ? "true" : "false") %>
<% if @https -%>
nginx['listen_https'] = false
nginx['redirect_http_to_https'] = false
<% else -%>
nginx['listen_https'] = true
nginx['redirect_http_to_https'] = true
<% end -%>
nginx['listen_port'] = 80