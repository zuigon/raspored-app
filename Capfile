# load 'deploy' if respond_to?(:namespace)
set :application, "raspored"
set :user, "bkrsta"
set :use_sudo, false

# set :scm, :git
set :scm, :none
set :repository, "git://github.com:bkrsta/raspored-app.git"
set :deploy_via, :checkout
set :deploy_to, "/stor/www/public/bkrsta.co.cc/apps/#{application}"

role :app, "srv1"
role :web, "srv1"
role :db, "srv1", :primary => true

set :runner, user
set :admin_runner, user

namespace :deploy do
  task :start, :roles => [:web, :app] do
    run "cd #{deploy_to} && nohup thin -C production_config.yml start"
    run "cd #{deploy_to} && nohup bash #{deploy_to}/caldaemon.sh"
  end

  task :stop, :roles => [:web, :app] do
    run "cd #{deploy_to} && nohup thin -C production_config.yml stop"
    run "kill `ps -ef | grep caldaemon | grep -v grep | awk '{print $2}'`"
  end

  task :restart, :roles => [:web, :app] do
    deploy.stop
    deploy.start
  end

  task :cold do
    deploy.update
    deploy.start
  end
end

namespace :app do
  task :log do
    run "tail -30f #{deploy_to}/app.log"
  end
end
