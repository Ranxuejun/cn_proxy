load 'deploy' if respond_to?(:namespace) # cap2 differentiator


set :user, "deploy"
set :use_sudo, false
set :scm, :git
set :repository,  "git@github.com:user/example.git"
set :branch, 'master'
set :git_shallow_clone, 1
set :deploy_via, :copy
set :application, "example"

set :stage, "development" unless variables[:stage]

case stage
when "development"
  set :domain, "#{application}-development.example.org"
  set :deploy_to, "/home/webapps/#{application}-development"
when "staging"
  set :domain, "#{application}-development.example.org"
  set :deploy_to, "/home/webapps/#{application}-staging"
when "production"
  set :domain, "#{application}-development.example.org"
  set :deploy_to, "/home/webapps/#{application}"
end

role :web, domain
role :app, domain
role :db,  domain, :primary => true

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  # Assumes you are using Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

    # mkdir -p is making sure that the directories are there for some SCM's that don't save empty folders
    run <<-CMD
    rm -rf #{latest_release}/log &&
    mkdir -p #{latest_release}/public &&
    mkdir -p #{latest_release}/tmp &&
    ln -s #{shared_path}/log #{latest_release}/log &&
    mkdir -p #{shared_path}/config &&
    touch #{shared_path}/config/settings.yaml &&
    ln -nsf #{shared_path}/config/settings.yaml #{latest_release}/config/settings.yaml
    CMD

    if fetch(:normalize_asset_timestamps, true)
      stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
      asset_paths = %w(images stylesheets).map { |p| "#{latest_release}/public/#{p}" }.join(" ")
      run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
    end
  end

  desc "Print usage/help information"
  task :help do
    puts "Usage: cap <task> -S stage=[development|staging|production]"
    puts ""
    puts "(default=development)"
    puts ""
    puts "Examples:"
    puts "----------------------------------------------------------------------"
    puts "  Production:"
    puts "    $ cap deploy -S stage=production"
    puts ""
  end

end

namespace :rake do

  desc "List available rake tasks on #{domain}"
  task :show_tasks do
    stream("cd #{deploy_to}/current; rake -T")
  end

  desc "Show environment variables on #{domain}"
  task :show_env do
    stream("cd #{deploy_to}/current; rake show_env")
  end

  desc "Install required gems on #{domain} using bundler"
  task :bundler do
    stream("cd #{deploy_to}/current; bundle install")
  end

  desc "Generate templated assets customized for #{stage} on #{domain}"
  task :generate_assets do
    stream("cd #{deploy_to}/current; rake generate_assets[#{stage}]")
  end

  desc "Fill-out passwords and install in settings file for #{domain}"
  task :set_passwords do
    settings = YAML.load(File.new("config/settings.yaml.template").read)  
    fill_passwords! settings
    yaml = YAML::dump(settings)
    put yaml, "#{deploy_to}/shared/config/settings.yaml"
       
  end
  
  def fill_passwords! h, p=nil
    h.each_key do |k|
      if (h[k].class) == Hash   
        h[k] = fill_passwords!(h[k], k)
      else 
        if k.to_s =~ /_password$/ || k.to_s =~ /_key$/
          h[k] = Capistrano::CLI.password_prompt("Enter #{p} #{k}:")
        end
      end
    end
  end
  
end


