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
set :deploy_to, "/home/ubuntu/#{application}"
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

desc "Create apache vhosts and application config, install vhosts"
task :configure do
  server_name = Capistrano::CLI.ui.ask("Enter the vhost server name: ")
  pid = Capistrano::CLI.ui.ask("Enter the CrossRef query pid: ")
  stream("cd #{deploy_to}; rake pid=#{pid} build_config ")
  stream("cd #{deploy_to}; rake server_name=#{server_name} thin_servers=#{thin_servers} build_vhosts")
  
  stream <<-APACHE
  sudo touch /etc/apache2/sites-available/cnproxy &&
  sudo sh -c "cat #{deploy_to}/config/vhosts > /etc/apache2/sites-available/cnproxy" &&
  sudo ln -nsf /etc/apache2/sites-available/cnproxy /etc/apache2/sites-enabled/cnproxy
  APACHE
end

namespace :control do
   
  desc "Start apache and thin servers"
  task :start do
    stream("thin start -d -s#{thin_servers} -R config.ru")
    stream("sudo apachectl start")
  end

  desc "Stop apache and thin servers"
  task :stop do
    stream("sudo apachectl stop")
    stream("thin stop")
  end

end
