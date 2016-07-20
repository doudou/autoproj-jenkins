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

        def template_path
            Pathname.new(__dir__) + "fixtures" + "templates"
        end

        def setup
            @jenkins_jobs = nil
            @jenkins_run_progress = (ENV['JENKINS_RUN_PROGRESS'] == '1')
            super
        end

        def teardown
            super
        end

        def jenkins_connect(url: 'http://localhost:8080')
            logger = Logger.new(StringIO.new)
            @server = Server.new(server_url: url, logger: logger)
        end

        def jenkins_jobs
            @jenkins_jobs ||= JenkinsApi::Client::Job.new(server.client)
        end

        TEST_JOB_PREFIX = "autoproj-jenkins-test-"

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

        def jenkins_run_job(job_name, progress: jenkins_run_progress?)
            job_name = TEST_JOB_PREFIX + job_name
            build_id = jenkins_jobs.build(job_name)
            console_start = 0

            while true
                status = jenkins_jobs.status(job_name)

                if status == 'running' && jenkins_run_progress?
                    puts "START #{console_start}"
                    response = jenkins_read_console(job_name, 0, console_start)
                    console_start += response['size']
                    puts response['output']
                end

                if status != 'running' && status != 'not_run'
                    if status == 'success'
                        return
                    else
                        output = jenkins_console_output(job_name)
                        flunk("job #{job_name} exited with status #{status}: #{output}")
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
