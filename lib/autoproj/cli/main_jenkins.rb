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

                    STDERR.puts "connecting to jenkins '#{url}' with prefix '#{options[:prefix]}'"
                    Jenkins.new(ws,
                                job_prefix: options[:job_prefix],
                                server_url: url,
                                **auth)
                end
            end

            desc 'init URL [PACKAGE NAMES]', 'initialize the jenkins server by creating the base build job, optionally restricting the build to certain packages'
            option :trigger, desc: 'trigger the job once created',
                type: :boolean, default: false
            option :dev, desc: 'assume that the jenkins instance is a development instance under vagrant and that autoproj-jenkins is made available as /opt/autoproj-jenkins',
                type: :boolean, default: false
            option :target_os, desc: "the autoproj definition for the target OS as name0,name1:version0,version1",
                default: nil
            option :credentials_id, desc: "the credentials ID of the username/password credentials that autoproj-jenkins should use to access the jenkins CLI",
                default: 'autoproj-jenkins-cli'
            option :vcs_credentials, desc: 'list of vcs_type:URLs for which credentials should be provided (see documentation)',
                type: :array, default: []
            option :seed, desc: 'a YAML file containing seed configuration',
                type: :string
            def init(url, *package_names)
                require 'autoproj/cli/jenkins'
                ops = create_ops(url, target_os: options[:target_os])

                if options[:seed]
                    seed = File.read(options[:seed])
                end

                ops.create_or_update_buildconf_job(
                    *package_names,
                    seed: seed,
                    credentials_id: options[:credentials_id],
                    vcs_credentials: options[:vcs_credentials],
                    dev: options[:dev])
                if options[:trigger]
                    ops.trigger_buildconf_job
                end
            end


            desc 'update URL [PACKAGE_NAMES]', 'add the following package and its dependencies to the jenkins build'
            option :dev, desc: 'assume that the jenkins instance is a development instance under vagrant and that autoproj-jenkins is made available as /opt/autoproj-jenkins',
                type: :boolean, default: false
            option :vcs_credentials, desc: 'list of vcs_type:URLs for which credentials should be provided (see documentation)',
                type: :array, default: []
            option :seed, desc: 'a YAML file containing seed configuration',
                type: :string
            def update(url, *package_names)
                require 'autoproj/cli/jenkins'

                if options[:seed]
                    seed = File.read(options[:seed])
                end

                ops = create_ops(url)
                Autoproj.report(silent: !options[:debug], debug: options[:debug]) do
                    updated_jobs = ops.add_or_update_packages(*package_names, seed: seed, dev: options[:dev], vcs_credentials: options[:vcs_credentials])
                    updated_jobs.sort.each do |job_name|
                        puts job_name
                    end
                end
            end
            
            desc 'postprocess-tests OUTPUT_DIR [PACKAGE_NAME]', 'postprocesses test result formatted in various formats to convert them into the JUnit XML format understood by Jenkins',
                hide: true
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

            desc 'relativize ROOT_DIR INPUT_TEXT OUTPUT_TEXT', 'replaces INPUT_TEXT by OUTPUT_TEXT in all files that can contain absolute paths',
                hide: true
            def relativize(root_dir, input_text, output_text)
                require 'autoproj/jenkins'
                relativize = Autoproj::Jenkins::Relativize.new(Pathname.new(root_dir), input_text, output_text)
                processed_paths = relativize.process
                puts "modified #{processed_paths.size} file"
                processed_paths.each do |p|
                    puts "  #{p}"
                end
            end
        end
    end
end

