require 'test_helper'

module Autoproj::Jenkins
    describe ".render_template" do
        it "renders the given template" do
            result = Autoproj::Jenkins.render_template(
                'no_parameters.xml', template_path: self.template_path)
            assert_equal "<result/>\n", result
        end
        it "passes the parameters" do
            result = Autoproj::Jenkins.render_template(
                'with_parameters.xml', template_path: self.template_path, parameter: 10)
            assert_equal "<result>10</result>\n", result
        end
        it "recursively resolves templates, passing them the parameters and template path" do
            result = Autoproj::Jenkins.render_template(
                'recursive.xml', template_path: self.template_path, parameter: 10)
            assert_equal "<result>10</result>\n\n", result
        end
        it "raises if the template accesses parameters that are not available" do
            assert_raises(UnknownTemplateParameter) do
                Autoproj::Jenkins.render_template(
                    'with_parameters.xml', template_path: self.template_path)
            end
        end
        it "raises if the template does not use some of the parameters that are given to it" do
            assert_raises(UnusedTemplateParameters) do
                Autoproj::Jenkins.render_template(
                    'no_parameters.xml', template_path: self.template_path, parameter: 10)
            end
        end
        it "allows to recursively handle indentation" do
            result = Autoproj::Jenkins.render_template(
                'indentation.xml', template_path: self.template_path, count: 2)
            assert_equal "first\nsecond\n  first\n  second\n    first\n    second\n      \n", result
        end
    end
end

