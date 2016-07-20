module Autoproj::Jenkins
    # Update a jenkins server configuration from an autoproj workspace
    class Updater
        # The autoproj workspace
        #
        # @return [Autoproj::Workspace]
        attr_reader :ws

        # The server we have to update
        #
        # @return [Server]
        attr_reader :server

        # A string that is prefixed to all job names
        #
        # @return [String]
        attr_reader :job_prefix


        # Create a new updater context for an autoproj workspace and Jenkins
        # server
        #
        # @param [Autoproj::Workspace] ws
        # @param [Server] server
        # @param [String] job_prefix a string that should be prefixed to all job
        #   names
        def initialize(ws, server, job_prefix: '')
            @ws = ws
            @server = server
            @job_prefix = job_prefix
        end

        # Create the master buildconf job
        #
        # @return [void]
        def create_buildconf_job
            server.create_job("#{job_prefix}buildconf", 'buildconf.xml',
                vcs: ws.manifest.vcs)
        end
    end
end
