module Autoproj::Jenkins
    # The interface to a Jenkins server
    class Server
        # The underlying client
        #
        # @return [JenkinsApi::Client::Job]
        attr_reader :client

        def initialize(**options)
            @client = JenkinsApi::Client.new(**options)
        end

        # Create a job using a rendered template
        # 
        # @param [String] job_name the name of the new job
        # @param [String] template the name of the template
        # @param [Hash] parameters parameters for the template rendering
        # @raise (see Autoproj::Jenkins.render_template)
        def create_job(job_name, template, **parameters)
            xml = Autoproj::Jenkins.render_template(template, **parameters)
            JenkinsApi::Client::Job.new(client).create(job_name, xml)
        end
    end
end

