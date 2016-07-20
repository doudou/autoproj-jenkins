module Autoproj
    module CLI
        # The 'jenkins' subcommand for autoproj
        class MainJenkins < Thor
            namespace 'jenkins'

            desc 'init URL', 'initialize the jenkins server by creating base jobs'
            def init(url)
                require 'autoproj/cli/jenkins'
                ops = Jenkins.new(Autoproj::Workspace.from_pwd, server_url: url)
                ops.create_buildconf_job
            end
        end
    end
end

