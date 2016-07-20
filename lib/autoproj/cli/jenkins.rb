require 'autoproj/cli/inspection_tool'
require 'autoproj/jenkins'

module Autoproj
    module CLI
        class Jenkins < Autoproj::CLI::InspectionTool
            attr_reader :server
            attr_reader :updater

            def initialize(ws, **options)
                super(ws)
                @server = Autoproj::Jenkins::Server.new(**options)
                @updater = Autoproj::Jenkins::Updater.new(ws, server)
            end

            def create_buildconf_job(force: false)
                initialize_and_load
                updater.create_buildconf_job(force: force)
            end
        end
    end
end

