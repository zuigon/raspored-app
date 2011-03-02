load 'deploy' if respond_to?(:namespace)
set :application, "raspored"
set :user, "bkrsta"
set :use_sudo, false

set :scm, :git
# set :scm, :none
set :repository, "git://github.com/bkrsta/raspored-app.git"
set :deploy_via, :checkout
set :deploy_to, "/stor/www/public/bkrsta.co.cc/apps/#{application}"

role :app, "srv1"
role :web, "srv1"
role :db, "srv1", :primary => true

set :runner, user
set :admin_runner, user

namespace :deploy do
  task :start, :roles => [:web, :app] do
    run "cd #{deploy_to}/current && nohup thin -C production_config.yml -R app.rb start"
    run "X=`ps -ef | grep raspored/current/caldaemon.sh | grep -v grep | awk '{print $2}'` && if [ $X ]; then kill $X; fi"
    run "cd #{deploy_to}/current && nohup #{deploy_to}/current/caldaemon.sh >/dev/null 2>&1 &"
  end

  task :stop, :roles => [:web, :app] do
    run "cd #{deploy_to}/current && nohup thin -C production_config.yml stop"
    run "X=`ps -ef | grep raspored/current/caldaemon.sh | grep -v grep | awk '{print $2}'` && if [ $X ]; then kill $X; fi"
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
    run "tail -30f #{deploy_to}/current/app.log"
  end
end
