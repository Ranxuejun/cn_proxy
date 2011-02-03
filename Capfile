load 'deploy' if respond_to?(:namespace) # cap2 differentiator

set :application, 'cn_proxy'
set :thin_servers, 4 unless variables[:thin_servers]

set :user, 'deploy' unless variables[:user]
set :use_sudo, false
set :scm, :git
set :repository, 'git@github.com:CrossRef/cn_proxy.git'
set :branch, 'master'
set :git_shallow_clone, 1
set :deploy_via, :copy
set :deploy_to, "/home/webapps/#{application}"
set :domain, "cnproxy" unless variables[:domain]

role :app, domain
role :web, domain
role :db, domain, :primary => true

desc "Bootstrap EC2 AMI instance"
task :bootstrap do
  set :user, 'ubuntu'
  bash_script = File.open(File.join('scripts','bootstrap')).read()
  put(bash_script,"/home/#{user}/bootstrap")
  stream("cd /home/#{user}; sudo bash bootstrap")
end

desc "Create apache vhosts and application config"
task :configure do
  server_name = Capistrano::CLI.ui.ask("Enter the vhost server name: ")
  pid = Capistrano::CLI.ui.ask("Enter the CrossRef query pid: ")
  stream("cd #{deploy_to}/current; rake pid=#{pid} build_config ")
  stream("cd #{deploy_to}/current; rake server_name=#{server_name} thin_servers=#{thin_servers} build_vhosts")
end

desc "Install vhosts"
task :install do
  set :user, 'ubuntu'
  stream ("sudo bash -c 'touch /etc/apache2/sites-available/#{application}'")
  stream ("sudo bash -c 'cat #{deploy_to}/current/config/vhosts > /etc/apache2/sites-available/#{application}'")
  stream("sudo bash -c 'ln -nsf /etc/apache2/sites-available/#{application} /etc/apache2/sites-enabled/#{application}'")
end


namespace :deploy do

  # TODO Should try to integrate :control:start/:end and :configure
  # into the deploy namespace.
  task :start do ; end
  task :stop do ; end
  task :restart do ; end

end

namespace :control do
   
  desc "Start thin servers"
  task :start do
    stream("cd #{deploy_to}/current; thin start -d -s#{thin_servers} -R config.ru")
  end

  desc "Stop apache and thin servers"
  task :stop do
    stream("cd #{deploy_to}/current; thin -s#{thin_servers} stop")
  end

  desc "Restart apache"
  task :restart_apache do
    set :user, 'ubuntu'
    stream("sudo bash -c 'apache2ctl restart'")
  end

end
