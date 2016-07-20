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
        end
    end
end

