module Autoproj
    module CLI
        # The 'jenkins' subcommand for autoproj
        class MainJenkins < Thor
            class_option :password_file, desc: 'file containing the password used for authentication'
            class_option :job_prefix, desc: 'string that should be used as prefix to all generated job names',
                type: :string, default: ''

            namespace 'jenkins'

            no_commands do
                def create_ops(url)
                    if password_file = options[:password_file]
                        auth = Hash[username: 'autoproj-jenkins',
                                    password: File.read(password_file)]
                    else
                        auth = Hash.new
                    end

                    puts "connecting to jenkins '#{url}' with prefix '#{options[:prefix]}'"
                    Jenkins.new(Autoproj::Workspace.from_pwd,
                                job_prefix: options[:job_prefix],
                                server_url: url,
                                **auth)
                end
            end

            desc 'init URL [PACKAGE NAMES]', 'initialize the jenkins server by creating the base build job, optionally restricting the build to certain packages'
            option :force, desc: 'if set, delete any existing job'
            option :trigger, desc: 'trigger the job once created',
                type: :boolean, default: false
            option :dev, desc: 'assume that the jenkins instance is a development instance under vagrant and that autoproj-jenkins is made available as /opt/autoproj-jenkins',
                type: :boolean, default: false
            def init(url, *package_names)
                require 'autoproj/cli/jenkins'
                ops = create_ops(url)
                gemfile =
                    if options[:dev]
                        'buildconf-vagrant-Gemfile'
                    else
                        'buildconf-Gemfile'
                    end

                ops.create_or_update_buildconf_job(
                    *package_names,
                    gemfile: gemfile,
                    force: options[:force])
                if options[:trigger]
                    ops.trigger_buildconf_job
                end
            end


            desc 'update [PACKAGE_NAMES]', 'add the following package and its dependencies to the jenkins build'
            option :trigger, desc: 'trigger the packages once updated',
                type: :boolean, default: false
            option :force, desc: 'ignore the current state, generate jobs as if nothing was ever done'
            option :state_file, desc: 'the file containing the state of the buildconf last time #add was called',
                type: :string, default: 'autoproj-jenkins-state.yml'
            def update(url, *package_names)
                require 'autoproj/cli/jenkins'
                ops = create_ops(url)
                Autoproj.report(silent: !options[:debug], debug: options[:debug]) do
                    updated_packages = ops.add_or_update_packages(*package_names)
                    if options[:trigger]
                        ops.trigger_packages(*updated_packages)
                    end
                end
            end
        end
    end
end

