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

            def add_or_update_packages(*package_names)
                initialize_and_load
                source_packages, _ = finalize_setup(package_names, ignore_non_imported_packages: false)
                source_packages = source_packages.map do |package_name|
                    ws.manifest.package(package_name)
                end
                updater.update(*source_packages)
            end
        end
    end
end

