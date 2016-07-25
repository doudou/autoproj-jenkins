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
        def create_buildconf_job(force: false)
            if force
                server.delete_job("#{job_prefix}buildconf")
            end
            server.create_job("#{job_prefix}buildconf", 'buildconf.xml',
                vcs: ws.manifest.vcs)
        end

        # Returns the job name of a given package
        #
        # @param [String] package_name
        # @return [String]
        def job_name_from_package_name(package_name)
            "#{job_prefix}#{package_name.gsub('/', '-')}"
        end

        # Create a job for a package
        #
        # @return [void]
        def create_package_job(package, job_name: job_name_from_package_name(package.name), force: false)
            job_name = job_name_from_package_name(package.name)
            if force
                server.delete_job(job_name)
            end

            server.create_job(job_name, 'package.xml')
        end

        # Resolve a package by its name
        def package_by_name(package_name)
            package = ws.manifest.find_package_definition(package_name)
            if !package
                raise ArgumentError, "no package called #{package_name}"
            end
        end

        # Create jobs and dependencies to handle the given set of packages
        def update(*packages)
            reverse_dependencies = ws.manifest.compute_revdeps

            packages.each do |package|
                job_name = job_name_from_package_name(package.name)
                if !server.has_job?(job_name)
                    create_package_job(package, job_name: job_name)
                end
            end

            package_names = packages.map(&:name).to_set
            packages.each do |package|
                job_name = job_name_from_package_name(package.name)
                upstream_jobs = package.autobuild.dependencies.
                    map { |pkg_name| job_name_from_package_name(pkg_name) if package_names.include?(pkg_name) }

                downstream_jobs = (reverse_dependencies[package.name] & package_names).
                    map { |pkg_name| job_name_from_package_name(pkg_name) }
                server.update_job_pipeline(job_name, 'package.pipeline',
                    buildconf_vcs: ws.manifest.vcs,
                    vcs: package.vcs,
                    package_name: package.name,
                    job_name: job_name,
                    package_dir: Pathname.new(package.autobuild.srcdir).relative_path_from(Pathname.new(ws.root_dir)).to_s,
                    upstream_jobs: upstream_jobs,
                    downstream_jobs: downstream_jobs)
            end
        end
    end
end
