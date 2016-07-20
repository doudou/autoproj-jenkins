require 'test_helper'
require 'tmpdir'

module Autoproj::Jenkins
    describe Updater do
        attr_reader :workspace_dir
        before do
            @workspace_dir = Dir.mktmpdir
        end
        after do
            FileUtils.rm_rf workspace_dir
            if server
                jenkins_delete_job 'buildconf'
            end
        end

        describe "#create_buildconf_job" do
            attr_reader :ws
            before do
                @ws = Autoproj::Workspace.new(workspace_dir)
                ws.manifest.vcs = Autoproj::VCSDefinition.
                    from_raw(type: :git, url: 'https://github.com/rock-core/buildconf', branch: 'master')
            end
            it "creates a job that checks out the buildconf" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.create_buildconf_job

                config = jenkins_job_config('buildconf')
                pipeline = config.elements['//definition[@plugin = "workflow-cps@2.9"]/script'].text
                assert_match Regexp.new("git url: 'https://github.com/rock-core/buildconf', branch: 'master'"), pipeline
            end
            it "checks out the buildconf, installs autoproj and installs all osdeps" do
                updater = Updater.new(ws, jenkins_connect, job_prefix: TestHelper::TEST_JOB_PREFIX)
                updater.create_buildconf_job
                jenkins_run_job 'buildconf'
            end
        end
    end
end
