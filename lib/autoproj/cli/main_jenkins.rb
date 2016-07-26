module Autoproj
    module CLI
        # The 'jenkins' subcommand for autoproj
        class MainJenkins < Thor
            namespace 'jenkins'

            desc 'init URL', 'initialize the jenkins server by creating base jobs'
            option :force, desc: 'if set, delete any existing job'
            def init(url)
                require 'autoproj/cli/jenkins'
                ops = Jenkins.new(Autoproj::Workspace.from_pwd, server_url: url)
                ops.create_buildconf_job(force: options[:force])
            end

            desc 'add [PACKAGE_NAMES]', 'add the following package and its dependencies to the jenkins build'
            def add(url, *package_names)
                require 'autoproj/cli/jenkins'
                Autoproj.report(silent: !options[:debug], debug: options[:debug]) do
                    ops = Jenkins.new(Autoproj::Workspace.from_pwd, server_url: url)
                    ops.add_or_update_packages(*package_names)
                end
            end
        end
    end
end

