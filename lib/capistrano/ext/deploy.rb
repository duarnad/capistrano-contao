Capistrano::Configuration.instance(:must_exist).load do
  namespace :deploy do
    desc 'Check if the remote is ready, should we run cap deploy:setup?'
    task :check_if_remote_ready, :roles => :app do
      unless remote_file_exists?(shared_path)
        logger.important 'ERROR: The project is not ready for deployment.'
        logger.important 'please run `cap deploy:setup'
        abort
      end
    end

    desc 'Fix permissions'
    task :fix_permissions, :roles => :app do
      if exists?(:app_owner) or exists?(:app_group)
        run <<-CMD
          #{try_sudo} chown -R \
            #{fetch :app_owner, 'www-data'}:#{fetch :app_group, 'www-data'} \
            #{fetch :deploy_to}/releases \
            #{fetch :deploy_to}/shared
        CMD
      end

      run "chmod -R g+w #{fetch :latest_release}" if fetch(:group_writable, true)
    end

    desc '[internal] create the required folders.'
    task :folders, :roles => :app do
      backup_path = fetch :backup_path, "#{fetch :deploy_to}/backups"

      run <<-CMD
        #{try_sudo} mkdir -p \
          #{fetch :deploy_to} \
          #{backup_path} \
          #{fetch :shared_path}/items \
          #{fetch :shared_path}/__system__ \
          #{fetch :logs_path, ''}
      CMD
    end

    desc '[internal] Setup if needed'
    task :setup_if_needed, :roles => :app do
      setup unless main_task == 'deploy:setup'
    end

    desc '[internal] Clean up folders'
    task :clean_folders, :roles => :app do
      clean_folder fetch(:deploy_to)
    end

    desc '[internal] Symlink public folder'
    task :symlink_public_folders, :roles => :web, :except => { :no_release => true } do
      deploy_to = fetch :deploy_to

      ['htdocs', 'httpdocs', 'www'].each do |folder|
        if remote_file_exists?("#{deploy_to}/#{folder}")
          begin
            run <<-CMD
              #{try_sudo} mkdir -p #{deploy_to}/old &&
              #{try_sudo} mv #{deploy_to}/#{folder} #{deploy_to}/old/#{folder} &&
              #{try_sudo} ln -nsf #{fetch :public_path} #{deploy_to}/#{folder}
            CMD
          rescue Capistrano::CommandError
            logger.info "WARNING: I could not replace the #{folder}  please do so manually"
          end
          logger.info "The #{folder} folder has been moved to the #{deploy_to}/old/#{folder}"
        end
      end
    end
  end

  # Dependencies
  before 'deploy',         'deploy:check_if_remote_ready'
  after  'deploy:restart', 'deploy:fix_permissions'
  after  'deploy:restart', 'deploy:clean_folders'
  before 'deploy:setup',   'deploy:folders'
  after  'deploy:setup',   'deploy:symlink_public_folders'
end
