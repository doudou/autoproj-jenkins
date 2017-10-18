module Autoproj::Jenkins
    # Returns true if the given VCS type is supported
    #
    # @param [#to_s] vcs the VCS type (e.g. 'git')
    def self.vcs_supported?(vcs)
        Autoproj::Jenkins.has_template?("import-#{vcs}.pipeline")
    end

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

        # The string used as project name by default
        #
        # If there is a job prefix, it is initialized with the job prefix minus
        # any trailing non-string character (i.e. rock- becomes rock).
        # Otherwise, it is 'default'
        attr_accessor :project_name

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
            if @job_prefix && !@job_prefix.empty?
                @project_name = @job_prefix.gsub(/[^\w]+$/, '')
            else
                @project_name = 'default'
            end
        end

        # Update the buildconf pipeline
        #
        # @param [String] gemfile the gemfile template that should be used for
        #   the autoproj bootstrap. Mostly used for autoproj-jenkins development
        #   within VMs
        # @param [String] autoproj_install_path a path local to the jenkins
        #   workspace where the autoproj_install script will be. If unset,
        #   downloads it from github.com
        # @param [Boolean] dev whether the packages pipelines should be updated
        #   with --dev or not
        # @param [Array<Autoproj::PackageDefinition>] packages if non-empty,
        #   restrict operations to these packages and their dependencies
        def render_buildconf_pipeline(*package_names, gemfile: 'buildconf-Gemfile', autoproj_install_path: nil, dev: false, credentials_id: nil, vcs_credentials: Credentials.new, seed: nil, status_publisher: nil)
            manifest_vcs = ws.manifest.vcs
            if manifest_vcs.local? || manifest_vcs.none?
                raise ArgumentError, "cannot use Jenkins to build an autoproj buildconf that is not on a remotely acessible VCS"
            end

            job_name = job_name_from_package_name("buildconf")
            server.render_pipeline(job_name, 'buildconf.pipeline',
                vcs: manifest_vcs,
                package_names: package_names,
                gemfile: gemfile,
                autoproj_install_path: autoproj_install_path,
                job_prefix: job_prefix,
                credentials_id: credentials_id,
                seed: seed,
                vcs_credentials: vcs_credentials,
                dev: dev,
                status_publisher: status_publisher)
        end

        # Update the status pipeline
        #
        # @param [Array<String>] package_names the list of
        #   packages we're building
        def render_status_pipeline(*job_names, publisher: nil, project_name: self.project_name)
            job_name = job_name_from_package_name("status")
            server.render_pipeline(job_name, 'status.pipeline',
                job_names: job_names, publisher: publisher, project_name: project_name)
        end

        # Create or update the buildconf (master) job
        #
        # @param [Array<Autoproj::PackageDefinition>] packages if non-empty,
        #   restrict operations to these packages and their dependencies
        # @param [String] gemfile the gemfile template that should be used for
        #   the autoproj bootstrap. Mostly used for autoproj-jenkins development
        #   within VMs
        # @param [Integer] quiet_period the job's quiet period, in seconds.
        #   Mostly used within autoproj-jenkins tests
        def create_or_update_buildconf_job(*package_names, gemfile: 'buildconf-Gemfile', autoproj_install_path: nil, seed: nil, dev: false, quiet_period: 5, credentials_id: nil, vcs_credentials: Credentials.new, status_publisher: nil)
            job_name = job_name_from_package_name("buildconf")
            pipeline = render_buildconf_pipeline(
                *package_names,
                gemfile: gemfile,
                autoproj_install_path: autoproj_install_path,
                credentials_id: credentials_id,
                vcs_credentials: vcs_credentials,
                seed: seed,
                dev: dev,
                status_publisher: status_publisher)
            server.create_or_reset_job(
                job_name, 'buildconf.xml', pipeline: pipeline, quiet_period: quiet_period)
        end

        # Returns the job name of a given package
        #
        # @param [String] package_name
        # @return [String]
        def job_name_from_package_name(package_name)
            "#{job_prefix}#{package_name.gsub('/', '-')}"
        end

        # Resolve a package by its name
        def package_by_name(package_name)
            package = ws.manifest.find_package_definition(package_name)
            if !package
                raise ArgumentError, "no package called #{package_name}"
            end
        end

        def compute_upstream_packages(package)
            upstream_packages = package.autobuild.dependencies.inject(Set.new) do |all, pkg_name|
                all << pkg_name
                ws.manifest.find_autobuild_package(pkg_name).all_dependencies(all)
            end
            upstream_packages.delete(package.name)
            upstream_packages
        end

        def compute_downstream_packages(package, reverse_dependencies)
            queue   = [package.name]
            results = Set.new
            while !queue.empty?
                p_name = queue.shift
                if !results.include?(p_name)
                    results << p_name
                    queue.concat(reverse_dependencies[p_name].to_a)
                end
            end
            results.delete(package.name)
            results
        end

        def compute_job_to_package_map(package_names, included_package_names)
            result = Hash.new
            package_names.each do |pkg_name|
                if included_package_names.include?(pkg_name)
                    job_name = job_name_from_package_name(pkg_name)
                    result[job_name] = pkg_name
                end
            end
            result
        end

        def create_or_update_status_job(*job_names, quiet_period: 0, publisher: nil)
            job_name = job_name_from_package_name("status")
            pipeline = render_status_pipeline(*job_names, publisher: publisher)
            server.create_or_reset_job(
                job_name, 'status.xml',
                pipeline: pipeline, quiet_period: quiet_period)
        end

        # Create jobs and dependencies to handle the given set of packages
        #
        # @return [Array<String>] the list of names of the jobs that have been
        #   created/updated
        def update(*packages, seed: nil, quiet_period: 5, gemfile: 'buildconf-Gemfile', autoproj_install_path: nil, vcs_credentials: Credentials.new)
            reverse_dependencies = ws.manifest.compute_revdeps

            package_names = packages.map(&:name).to_set
            packages.map do |package|
                job_name = job_name_from_package_name(package.name)
                if !Autoproj::Jenkins.vcs_supported?(package.vcs.type)
                    raise UnhandledVCS, "the #{package.vcs.type} importer, used by #{package.name}, is not supported by autoproj-jenkins"
                end

                upstream_jobs   = compute_job_to_package_map(
                    compute_upstream_packages(package), package_names)
                downstream_jobs = compute_job_to_package_map(
                    compute_downstream_packages(package, reverse_dependencies), package_names)

                prefix_relative_path =
                    if package.autobuild.srcdir == package.autobuild.prefix
                        Pathname.new(package.autobuild.srcdir).
                            relative_path_from(Pathname.new(ws.root_dir)).to_s
                    else
                        "install/#{package.name}"
                    end

                pipeline = server.render_pipeline(job_name, 'package.pipeline',
                    buildconf_vcs: ws.manifest.vcs,
                    vcs: package.vcs,
                    seed: seed,
                    package_name: package.name,
                    package_dir: Pathname.new(package.autobuild.srcdir).relative_path_from(Pathname.new(ws.root_dir)).to_s,
                    artifact_glob: "**/*",
                    job_name: job_name,
                    status_job_name: job_name_from_package_name('status'),
                    upstream_jobs: upstream_jobs,
                    downstream_jobs: downstream_jobs,
                    gemfile: gemfile,
                    autoproj_install_path: autoproj_install_path,
                    vcs_credentials: vcs_credentials)

                server.create_or_reset_job(
                    job_name, 'package.xml',
                    pipeline: pipeline,
                    quiet_period: quiet_period)

                job_name
            end
        end
    end
end
