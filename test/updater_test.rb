require 'test_helper'
require 'tmpdir'

module Autoproj::Jenkins
    describe Updater do
        attr_reader :workspace_dir, :ws, :base_cmake, :base_logging
        before do
            @workspace_dir = Dir.mktmpdir

            @ws = Autoproj::Workspace.new(workspace_dir)
            ws.autodetect_operating_system
            ws.manifest.vcs = Autoproj::VCSDefinition.
                from_raw(type: :git, url: 'https://github.com/rock-core/buildconf', branch: 'master')
            package = Autobuild.cmake('base/cmake')
            package.srcdir = File.join(workspace_dir, 'base', 'cmake')
            @base_cmake = ws.register_package(package, nil)
            base_cmake.vcs = Autoproj::VCSDefinition.from_raw(type: :git, url: 'https://github.com/rock-core/base-cmake')
            package = Autobuild.cmake('base/logging')
            package.srcdir = File.join(workspace_dir, 'base', 'logging')
            @base_logging = ws.register_package(package, nil)
            base_logging.vcs = Autoproj::VCSDefinition.from_raw(type: :git, url: 'https://github.com/rock-core/base-logging')
            base_logging.autobuild.depends_on 'base/cmake'
        end

        def update_options
            Hash[quiet_period: 0,
                 gemfile: 'buildconf-vagrant-Gemfile',
                 autoproj_install_path: '/opt/autoproj/bin/autoproj_install']
        end

        after do
            FileUtils.rm_rf workspace_dir
        end

        describe "#create_or_update_buildconf_job" do
            attr_reader :updater
            before do
                @updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
            end
            it "creates the buildconf job if it does not exist" do
                updater.create_or_update_buildconf_job(**update_options)
                assert jenkins_has_job?('buildconf')
            end
            it "restricts itself to the packages given on the command line and its dependencies" do
                updater.create_or_update_buildconf_job(base_logging, **update_options)
                jenkins_run_job 'buildconf'
                assert jenkins_has_job?('base-cmake')
                assert jenkins_has_job?('base-logging')
                assert !jenkins_has_job?('base-types')
                jenkins_join_job 'base-logging'
            end
            it "raises if the autoproj buildconf has no vcs" do
                ws.manifest.vcs = Autoproj::VCSDefinition.none
                assert_raises(ArgumentError) do
                    updater.create_or_update_buildconf_job(base_logging, **update_options)
                end
                refute jenkins_has_job?('base-logging')
            end
            it "raises if the autoproj buildconf has a local vcs" do
                ws.manifest.vcs = Autoproj::VCSDefinition.from_raw('type' => 'local', 'url' => '/test')
                assert_raises(ArgumentError) do
                    updater.create_or_update_buildconf_job(base_logging, **update_options)
                end
                refute jenkins_has_job?('base-logging')
            end
        end

        describe "#update" do
            attr_reader :updater
            before do
                @updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
            end

            it "handles git importers" do
                updater.update(base_cmake, **update_options)
                jenkins_run_job 'base-cmake'
            end

            it "handles archive importers" do
                package = Autobuild.cmake('external/sisl')
                package.srcdir = File.join(workspace_dir, 'external', 'sisl')
                package = ws.register_package(package, nil)
                package.vcs = Autoproj::VCSDefinition.from_raw(
                    type: :archive, url: 'https://github.com/SINTEF-Geometry/SISL/archive/SISL-4.6.0.tar.gz')
                updater.update(package, **update_options)
                jenkins_run_job 'external-sisl'
            end

            it "handles having source directories not matching the package name" do
                base_cmake.autobuild.srcdir = File.join(workspace_dir, 'test')
                updater.update(base_cmake, **update_options)
                jenkins_run_job 'base-cmake'
            end

            it "creates a job that runs successfully" do
                updater.update(base_cmake, **update_options)
                jenkins_run_job 'base-cmake'
            end

            it "raises if the package VCS is not supported" do
                base_cmake.vcs = Autoproj::VCSDefinition.from_raw(type: :unknown, url: '/test/')
                e = assert_raises(UnhandledVCS) do
                    updater.update(base_cmake)
                end
                assert_equal 'the unknown importer, used by base/cmake, is not supported by autoproj-jenkins',
                    e.message
                refute jenkins_has_job?('base/cmake')
            end

            it "triggers downstream jobs if triggered manually" do
                updater.update(base_cmake, base_logging, **update_options)
                jenkins_start_job 'base-cmake'
                jenkins_join_job 'base-cmake'
                jenkins_join_job 'base-logging'
            end

            it "waits for upstream jobs to finish" do
                updater.update(base_cmake, base_logging, **update_options)
                jenkins_start_job 'base-cmake'
                # The 'base-logging' job would fail without synchronization
                # because it relies on the existence of artifacts that are not
                # there yet
                jenkins_start_job 'base-logging'
                jenkins_join_job 'base-logging'
            end
        end
    end
end
