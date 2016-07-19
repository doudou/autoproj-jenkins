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
            super
        end

        def teardown
            super
        end

        def jenkins_connect(url: 'http://localhost:8080')
            @server = Server.new(server_url: url)
        end

        def jenkins_jobs
            @jenkins_jobs ||= JenkinsApi::Client::Job.new(server.client)
        end

        # Delete a job 
        def jenkins_delete_job(job_name)
            jenkins_jobs.delete(job_name)
        end

        # Whether the Jenkins server has this job
        def jenkins_has_job?(job_name)
            jenkins_jobs.exists?(job_name)
        end

        # Returns the configuration of a job
        def jenkins_job_config(job_name)
            REXML::Document.new(jenkins_jobs.get_config(job_name))
        end
    end
end

class Minitest::Test
    include Autoproj::Jenkins::TestHelper
end
