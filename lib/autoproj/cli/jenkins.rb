require 'autoproj/cli/inspection_tool'
require 'autoproj/jenkins'

module Autoproj
    module CLI
        class Jenkins < Autoproj::CLI::InspectionTool
            attr_reader :server
            attr_reader :updater

            def initialize(ws, job_prefix: '', **options)
                super(ws)
                @server = Autoproj::Jenkins::Server.new(**options)
                @updater = Autoproj::Jenkins::Updater.new(ws, server, job_prefix: job_prefix)
            end

            def parse_vcs_credentials(credentials)
                results = Autoproj::Jenkins::Credentials.new
                credentials.each do |argument|
                    credential = Autoproj::Jenkins::Credentials.parse(argument)
                    results.add(credential)
                end
                results
            end

            def create_or_update_buildconf_job(*package_names, seed: nil, dev: false, credentials_id: nil, vcs_credentials: [])
                initialize_and_load

                if dev
                    gemfile = 'buildconf-vagrant-Gemfile'
                    autoproj_install_path = '/opt/autoproj/bin/autoproj_install'
                else
                    gemfile = 'buildconf-Gemfile'
                    autoproj_install_path = nil
                end

                # Must NOT resolve the package names into packages. If they are
                # package sets/metapackages, they need to be provided as-is to
                # the buildconf template, so that the metapackage gets resolved
                # each time instead of only at the point 'jenkins init' was done
                updater.create_or_update_buildconf_job(*package_names, gemfile: gemfile,
                                                       seed: seed,
                                                       autoproj_install_path: autoproj_install_path, dev: dev,
                                                       credentials_id: credentials_id,
                                                       vcs_credentials: parse_vcs_credentials(vcs_credentials))
            end

            def add_or_update_packages(*package_names, seed: nil, dev: false, vcs_credentials: [])
                initialize_and_load
                source_packages, _ = finalize_setup(package_names, non_imported_packages: :ignore, auto_exclude: true)
                source_packages = source_packages.map do |package_name|
                    ws.manifest.package_definition_by_name(package_name)
                end

                if dev
                    gemfile = 'buildconf-vagrant-Gemfile'
                    autoproj_install_path = '/opt/autoproj/bin/autoproj_install'
                else
                    gemfile = 'buildconf-Gemfile'
                    autoproj_install_path = nil
                end

                updater.update(
                    *source_packages,
                    seed: seed,
                    gemfile: gemfile,
                    autoproj_install_path: autoproj_install_path,
                    vcs_credentials: parse_vcs_credentials(vcs_credentials))
            end

            # Returns the "roots" in the trigger graph
            #
            # The trigger graph is the inverse of the dependency graph
            # (a package's dependencies are built before the package itself)
            #
            # @param [Array<String>] package_names the packages whose trigger
            #   roots we want to find
            # @return [Array<String>] the trigger root packages
            def trigger_root_packages(*package_names)
                package_names.find_all do |pkg_name|
                    pkg = ws.manifest.find_autobuild_package(pkg_name)
                    if !pkg
                        raise ArgumentError, "#{pkg_name} is not a known package"
                    end
                    pkg.dependencies.all? do |dep_name|
                        !package_names.include?(dep_name)
                    end
                end
            end

            # Trigger the build of the given packages
            #
            # It actually only triggers the jobs that are roots in the trigger
            # graph
            #
            # @param [Array<String>] package_names the names of the packages to
            #   build
            def trigger_packages(*package_names)
                trigger_root_packages(*package_names).each do |pkg_name|
                    server.trigger_job(updater.job_name_from_package_name(pkg_name))
                end
            end
        end
    end
end

