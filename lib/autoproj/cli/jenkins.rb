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

            def parse_git_credentials(credentials)
                credentials.map do |git_url|
                    Autoproj::Jenkins::Updater::GitCredential.parse(git_url)
                end
            end

            def create_or_update_buildconf_job(*package_names, force: false, dev: false, credentials_id: nil, git_credentials: [])
                initialize_and_load

                if dev
                    gemfile = 'buildconf-vagrant-Gemfile'
                    autoproj_install_path = '/opt/autoproj/bin/autoproj_install'
                else
                    gemfile = 'buildconf-Gemfile'
                    autoproj_install_path = nil
                end

                source_packages, _ = finalize_setup(package_names, non_imported_packages: nil)
                source_packages = source_packages.map do |package_name|
                    ws.manifest.package_definition_by_name(package_name)
                end
                updater.create_or_update_buildconf_job(*source_packages, gemfile: gemfile,
                                                       autoproj_install_path: autoproj_install_path, dev: dev,
                                                       credentials_id: credentials_id,
                                                       git_credentials: parse_git_credentials(git_credentials))
            end

            def add_or_update_packages(*package_names, dev: false, git_credentials: [])
                initialize_and_load
                source_packages, _ = finalize_setup(package_names, ignore_non_imported_packages: false)
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
                    gemfile: gemfile,
                    autoproj_install_path: autoproj_install_path,
                    git_credentials: parse_git_credentials(git_credentials),
                    dev: dev).
                    map(&:name)
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

