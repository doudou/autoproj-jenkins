require 'test_helper'
require 'tmpdir'

module Autoproj::Jenkins
    describe Updater do
        attr_reader :workspace_dir
        before do
            @workspace_dir = Dir.mktmpdir
        end

        describe "#create_buildconf_job" do
            attr_reader :ws
            before do
                @ws = Autoproj::Workspace.new(workspace_dir)
                ws.manifest.vcs = Autoproj::VCSDefinition.
                    from_raw(type: :git, url: 'https://github.com/rock-core/buildconf', branch: 'master')
            end
            after do
                FileUtils.rm_rf workspace_dir
                if server
                    jenkins_delete_job 'buildconf'
                end
            end
            it "creates a job that checks out the buildconf" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.create_buildconf_job

                config = jenkins_job_config('buildconf')
                pipeline = config.elements['//definition[@plugin = "workflow-cps@2.9"]/script'].text
                assert_match Regexp.new("git url: 'https://github.com/rock-core/buildconf', branch: 'master'"), pipeline
            end
            it "raises if the job already exists" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.create_buildconf_job
                assert_raises(JenkinsApi::Exceptions::JobAlreadyExists) do
                    updater.create_buildconf_job
                end
            end
            it "overwrites an existing job if force is set" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.create_buildconf_job
                updater.create_buildconf_job(force: true)
            end
            it "checks out the buildconf, installs autoproj and installs all osdeps" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.create_buildconf_job
                jenkins_run_job 'buildconf'
            end
        end

        describe "#update" do
            attr_reader :ws, :base_cmake, :base_logging
            before do
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

            it "creates a job that runs successfully" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.update(base_cmake, quiet_period: 0)
                jenkins_run_job 'base-cmake'
            end

            it "handles dependencies between packages" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.update(base_cmake, base_logging, quiet_period: 0)
                jenkins_start_job 'base-cmake'
                jenkins_join_job 'base-cmake'
                jenkins_join_job 'base-logging'
            end

            it "waits for upstream jobs to finish" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.update(base_cmake, base_logging, quiet_period: 0)
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
