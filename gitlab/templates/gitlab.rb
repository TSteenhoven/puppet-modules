# Managed by puppet
<% if @https -%>
external_url 'https://<%= @server_fdqn %>'
<% else -%>
external_url 'http://<%= @server_fdqn %>'
<% end -%>
gitlab_rails['gitlab_email_enabled'] = <%= (@smtp_enable ? "true" : "false") %>
gitlab_rails['gitlab_ssh_host'] = '<%= @ssh_host_correct %>'
gitlab_rails['gitlab_shell_ssh_port'] = <%= @ssh_port %>
gitlab_rails['incoming_email_enabled'] = false
gitlab_rails['smtp_enable'] = <%= (@smtp_enable ? "true" : "false") %>
<% if @smtp_enable -%>
gitlab_rails['smtp_address'] = '<%= @smtp_server_correct %>'
gitlab_rails['smtp_port'] = 25
gitlab_rails['gitlab_email_from'] = 'gitlab@<%= @server_fdqn %>'
gitlab_rails['gitlab_email_display_name'] = 'Gitlab'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@<%= @server_fdqn %>'
<% end -%>
letsencrypt['enable'] = <%= (@letsencrypt ? "true" : "false") %>
<% if @https -%>
nginx['hsts_max_age'] = 31536000
nginx['hsts_include_subdomains'] = false
nginx['redirect_http_to_https'] = true
<% if ! @ssl_certificate.nil? -%>
nginx['ssl_certificate'] = '<%= @ssl_certificate %>'
<% end -%>
<% if ! @ssl_certificate_key.nil? -%>
nginx['ssl_certificate_key'] = '<%= @ssl_certificate_key %>'
<% end -%>
<% else -%>
nginx['redirect_http_to_https'] = false
<% end -%>
nginx['listen_port'] = 80