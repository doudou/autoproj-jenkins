require 'test_helper'

module Autoproj::Jenkins
    describe Server do
        describe "#create_job" do
            before do
                jenkins_connect
            end
            after do
                jenkins_delete_job name
            end

            it "creates a job with the given name and template" do
                server.create_job(name, 'empty_job.xml',
                                  description: 'job creation test',
                                  template_path: template_path)
                assert jenkins_has_job?(name)
                config = jenkins_job_config(name)
                assert_equal "job creation test", config.elements['//description'].text
            end
        end
    end
end
