$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
# simplecov must be loaded FIRST. Only the files required after it gets loaded
# will be profiled !!!
if ENV['TEST_ENABLE_COVERAGE'] == '1'
    begin
        require 'simplecov'
        SimpleCov.start do
            add_filter "/test/"
        end
    rescue LoadError
        warn "coverage is disabled because the 'simplecov' gem cannot be loaded"
    rescue Exception => e
        warn "coverage is disabled: #{e.message}"
    end
end

require 'autoproj/jenkins'
require 'minitest/autorun'
require 'rexml/document'

if ENV['TEST_ENABLE_PRY'] != '0'
    begin
        require 'pry'
    rescue Exception
        warn "debugging is disabled because the 'pry' gem cannot be loaded"
    end
end

module Autoproj::Jenkins
    module TestHelper
        attr_reader :server

        attr_reader :workspace_dir, :ws

        def template_path
            Pathname.new(__dir__) + "fixtures" + "templates"
        end

        def setup
            @jenkins_jobs = nil
            @jenkins_run_progress = (ENV['JENKINS_RUN_PROGRESS'] == '1')
            super
        end

        def teardown
            if server
                jenkins_test_jobs.each do |job_name|
                    jenkins_delete_job job_name
                end
            end
            if workspace_dir
                autoproj_delete_workspace
            end
            Autobuild::Package.clear
            super
        end

        def autoproj_create_workspace
            if @workspace_dir
                raise ArgumentError, "there is already a workspace created, call #autoproj_delete_workspace first"
            end
            @workspace_dir = Dir.mktmpdir
            @ws = Autoproj::Workspace.new(workspace_dir)
            ws.autodetect_operating_system
            ws
        end

        def autoproj_delete_workspace
            FileUtils.rm_rf @workspace_dir
        end
        
        def autoproj_create_package(package_type, package_name)
            package = Autobuild.send(package_type, package_name)
            ws.register_package(package, nil)
        end

        def jenkins_connect_options(url: 'http://localhost:8080')
            logger = Logger.new(StringIO.new)
            Hash[server_url: url, logger: logger]
        end

        def jenkins_connect(url: 'http://localhost:8080')
            @server = Server.new(**jenkins_connect_options(url: url))
        end

        def jenkins_jobs
            @jenkins_jobs ||= JenkinsApi::Client::Job.new(server.client)
        end

        TEST_JOB_PREFIX = "autoproj-jenkins-test-"

        def jenkins_test_jobs
            jenkins_jobs.list(/^#{TEST_JOB_PREFIX}/).
                map { |job_name| job_name[TEST_JOB_PREFIX.size..-1] }
        end

        # Delete a job 
        def jenkins_delete_job(job_name)
            jenkins_jobs.delete(TEST_JOB_PREFIX + job_name)
        end

        # Whether the Jenkins server has this job
        def jenkins_has_job?(job_name)
            jenkins_jobs.exists?(TEST_JOB_PREFIX + job_name)
        end

        # Returns the configuration of a job
        def jenkins_job_config(job_name)
            xml_config = jenkins_jobs.get_config(TEST_JOB_PREFIX + job_name)
            REXML::Document.new(xml_config)
        end

        def jenkins_read_console(job_name, build_id = 0, data_start = 0)
            job_name = TEST_JOB_PREFIX + job_name

            output = String.new
            more_data = true
            while more_data
                response = jenkins_jobs.get_console_output(job_name, build_id, data_start)
                output += response['output']
                data_start += Integer(response['size'])
                more_data = (response['more'] == true)
            end
            Hash['output' => output, 'size' => data_start]
        end

        def jenkins_console_output(job_name, build_id = 0, data_start = 0)
            jenkins_read_console(job_name, build_id, data_start)['output']
        end

        def jenkins_run_progress?
            @jenkins_run_progress
        end

        attr_writer :jenkins_run_progress

        def jenkins_run_job(job_name, progress: jenkins_run_progress?, start_timeout: 30, timeout: Float::INFINITY)
            jenkins_start_job(job_name)
            jenkins_join_job(job_name, progress: progress, start_timeout: start_timeout, timeout: timeout)
        end

        def jenkins_start_job(job_name)
            prefixed_job_name = TEST_JOB_PREFIX + job_name
            jenkins_jobs.build(prefixed_job_name)
        end

        def jenkins_join_job(job_name, progress: jenkins_run_progress?, start_timeout: 30, timeout: Float::INFINITY)
            prefixed_job_name = TEST_JOB_PREFIX + job_name
            console_start = 0

            start = Time.now
            while true
                if Time.now - start > timeout
                    flunk("#{job_name} timed out: did not finish within #{timeout} seconds")
                end
                status = jenkins_jobs.status(prefixed_job_name)

                if status == 'running'
                    if jenkins_run_progress?
                        response = jenkins_read_console(job_name, 0, console_start)
                        console_start += response['size']
                        puts response['output']
                    end
                elsif status == 'not_run'
                    if (Time.now - start > start_timeout)
                        flunk("#{job_name} timed out: did not start within #{start_timeout} seconds")
                    end
                else
                    if status == 'success'
                        return
                    else
                        output = jenkins_console_output(job_name)
                        flunk("job #{prefixed_job_name} exited with status #{status}: #{output}")
                    end
                end
                sleep 0.1
            end
        end
    end
end

class Minitest::Test
    include Autoproj::Jenkins::TestHelper
end
