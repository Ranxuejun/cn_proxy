load 'deploy' if respond_to?(:namespace) # cap2 differentiator

set :application, 'cn_proxy'
set :use_sudo, false
set :scm, :git
set :repository, 'git@github.com:CrossRef/cn_proxy.git'
set :branch, 'master'
set :git_shallow_clone, 1
set :deploy_via, :copy
set :deploy_to, "/home/webapps/#{application}"

set :domain, "cnproxy" unless variables[:domain]
set :distro, "ubuntu" unless variables[:distro]

role :app, domain
role :web, domain
role :db, domain, :primary => true

desc "Bootstrap EC2 AMI instance"
task :bootstrap do
  set :user, 'ubuntu' unless variables[:user]
  bash_script = File.open(File.join('scripts',"bootstrap-#{distro}")).read()
  put(bash_script,"/home/#{user}/bootstrap")
  stream("cd /home/#{user}; sudo bash bootstrap")
end

desc "Create apache vhosts and application config"
task :configure do
  set :user, 'deploy' unless variables[:user]
  stream("cd #{deploy_to}/current/config; rm -f vhosts")
  stream("cd #{deploy_to}/current/config; rm -f settings.yaml")
  data_server_name = Capistrano::CLI.ui.ask("Enter vhost data server name: ")
  id_server_name = Capistrano::CLI.ui.ask("Enter vhost id server name: ")
  pid = Capistrano::CLI.ui.ask("Enter a CrossRef query pid: ")
  stream("cd #{deploy_to}/current; rake pid=#{pid} build_config ")
  stream("cd #{deploy_to}/current; rake data_server_name=#{data_server_name} id_server_name=#{id_server_name} build_vhosts")
end

desc "Install vhosts"
task :install do
  set :user, 'ubuntu' unless variables[:user]
  stream ("sudo bash -c 'touch /etc/apache2/sites-available/#{application}'")
  stream ("sudo bash -c 'cat #{deploy_to}/current/config/vhosts > /etc/apache2/sites-available/#{application}'")
  stream("sudo bash -c 'ln -nsf /etc/apache2/sites-available/#{application} /etc/apache2/sites-enabled/#{application}'")
end

desc "Restart apache"
task :restart_apache do
  set :user, 'ubuntu' unless variables[:user]
  stream("sudo bash -c 'apache2ctl restart'")
end

namespace :deploy do

  # TODO Should try to integrate :control:start/:end and :configure
  # into the deploy namespace.
  task :start do ; end
  task :stop do ; end
  task :restart do ; end

end
