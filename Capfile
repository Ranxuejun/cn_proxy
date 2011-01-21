load 'deploy' if respond_to?(:namespace) # cap2 differentiator

set :application, 'cn_proxy'
set :thin_servers, 20 unless variables[:thin_servers]

set :user, 'deploy'
set :use_sudo, false
set :scm, :git
set :repository, 'git@github.com:CrossRef/cn_proxy.git'
set :branch, 'master'
set :git_shallow_clone, 1
set :deploy_via, :copy
set :deploy_to, "/home/webapps/#{application}"
set :domain, "cnproxy" unless variables[:domain]

desc "Bootstrap EC2 AMI instance on domain: #{domain}"
task :bootstrap do
  set :user, 'ubuntu'
  bash_script = File.open(File.join('scripts','bootstrap')).read()
  put(bash_script,"/home/#{user}/bootstrap")
  stream("cd /home/#{user}/; sudo bash bootstrap")
end

namespace :control do
   
  desc "Start nginx and thin servers"
  task :start do
    stream("thin start -d -s#{thin_servers} --socket /tmp/thin.sock -R config.ru")
  end

  desc "Stop nginx and thin servers"
  task :stop do
    stream("thin stop")
  end

end

