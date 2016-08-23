module Autoproj
    module CLI
        # The 'jenkins' subcommand for autoproj
        class MainJenkins < Thor
            class_option :username, desc: 'username to the Jenkins CLI (a password will be requested if --password is not given)'
            class_option :password, desc: 'password to the Jenkins CLI (needs --username)'
            class_option :job_prefix, desc: 'string that should be used as prefix to all generated job names',
                type: :string, default: ''

            namespace 'jenkins'

            no_commands do
                def request_password
                    STDOUT.print "Password: "
                    STDOUT.flush
                    STDIN.noecho do |io|
                        io.readline.chomp
                    end
                end

                def create_ops(url, target_os: nil)
                    if username = options[:username]
                        password = options[:password] || request_password
                        auth = Hash[username: username,
                                    password: password]
                    elsif options[:password]
                        raise ArgumentError, "--password given without --username"
                    else
                        auth = Hash.new
                    end

                    workspace_options = Hash.new
                    if target_os
                        names, versions =  target_os.split(':')
                        names = names.split(',')
                        names << 'default'
                        versions = versions.split(',')
                        versions << 'default'
                        workspace_options[:os_package_resolver] = OSPackageResolver.new(operating_system: [names, versions])
                    end
                    ws = Autoproj::Workspace.default(**workspace_options)

                    puts "connecting to jenkins '#{url}' with prefix '#{options[:prefix]}'"
                    Jenkins.new(ws,
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
            option :target_os, desc: "the autoproj definition for the target OS as name0,name1:version0,version1",
                default: nil
            option :credentials_id, desc: "the credentials ID of the username/password credentials that autoproj-jenkins should use to access the jenkins CLI. Won't use any credentials if not given"
            def init(url, *package_names)
                require 'autoproj/cli/jenkins'
                ops = create_ops(url, target_os: options[:target_os])

                ops.create_or_update_buildconf_job(
                    *package_names,
                    credentials_id: options[:credentials_id],
                    force: options[:force],
                    dev: options[:dev])
                if options[:trigger]
                    ops.trigger_buildconf_job
                end
            end


            desc 'update [PACKAGE_NAMES]', 'add the following package and its dependencies to the jenkins build'
            option :trigger, desc: 'trigger the packages once updated',
                type: :boolean, default: false
            option :force, desc: 'ignore the current state, generate jobs as if nothing was ever done'
            option :dev, desc: 'assume that the jenkins instance is a development instance under vagrant and that autoproj-jenkins is made available as /opt/autoproj-jenkins',
                type: :boolean, default: false
            option :state_file, desc: 'the file containing the state of the buildconf last time #add was called',
                type: :string, default: 'autoproj-jenkins-state.yml'
            def update(url, *package_names)
                require 'autoproj/cli/jenkins'
                ops = create_ops(url)
                Autoproj.report(silent: !options[:debug], debug: options[:debug]) do
                    updated_packages = ops.add_or_update_packages(*package_names, dev: options[:dev])
                    if options[:trigger]
                        ops.trigger_packages(*updated_packages)
                    end
                end
            end
            
            desc 'postprocess-tests OUTPUT_DIR [PACKAGE_NAME]', 'postprocesses test result formatted in various formats to convert them into the JUnit XML format understood by Jenkins'
            option :after, desc: "if provided, any report file that is older than this file will be ignored",
                default: nil
            def postprocess_tests(output_dir, *package_names)
                require 'autoproj/cli/test_postprocessing'
                ops = TestPostprocessing.new(Workspace.default)
                if options[:after]
                    reference_time = File.stat(options[:after]).mtime
                end
                ops.process(output_dir, *package_names, after: reference_time)
            end
        end
    end
end

