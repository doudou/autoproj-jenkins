module Autoproj::Jenkins
    # The interface to a Jenkins server
    class Server
        # The underlying client
        #
        # @return [JenkinsApi::Client]
        attr_reader :client

        # The job-related API
        #
        # @return [JenkinsApi::Client::Job]
        attr_reader :jobs

        def initialize(**options)
            @client = JenkinsApi::Client.new(**options)
            @jobs = JenkinsApi::Client::Job.new(client)
        end

        # Create a job using a rendered template
        # 
        # @param [String] job_name the name of the new job
        # @param [String] template the name of the template
        # @param [Hash] parameters parameters for the template rendering
        # @raise (see Autoproj::Jenkins.render_template)
        def create_job(job_name, template, **parameters)
            xml = Autoproj::Jenkins.render_template(template, **parameters)
            jobs.create(job_name, xml)
        end

        # Test whether the server already has a job
        #
        # @param [String] job_name
        def has_job?(job_name)
            jobs.exists?(job_name)
        end

        # Read a job configuration
        #
        # @return [REXML::Document]
        def read_job_config(job_name)
            xml_config = jobs.get_config(job_name)
            REXML::Document.new(xml_config)
        end

        # Update a job configuration
        #
        # @param [String] job_name
        # @param [REXML::Document] xml the configuration XML document
        def update_job_config(job_name, xml)
            jobs.update(job_name, xml.to_s)
        end

        # Delete a job
        #
        # @param [String] job_name
        def delete_job(job_name)
            jobs.delete(job_name)
        end

        # Trigger a job
        def trigger_job(job_name)
            jobs.build(job_name)
        end

        # Update the pipeline of the given job
        def update_job_pipeline(job_name, template, **parameters)
            config = read_job_config(job_name)
            pipeline = Autoproj::Jenkins.render_template(template, **parameters)
            config.elements['//definition/script'].text = pipeline
            update_job_config(job_name, config)
        end

        # Add a job as a downstream job of another
        def add_downstream_project(upstream_job_name, downstream_job_name)
            jobs.add_downstream_projects(upstream_job_name, downstream_job_name, 'success', false)
        end
    end
end

