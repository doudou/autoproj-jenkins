module Autoproj::Jenkins
    class UnusedTemplateParameters < ArgumentError; end
    class UnknownTemplateParameter < ArgumentError; end

    # @api private
    #
    # A rendering context for ERB templates
    #
    # It ensures that the templates are restricted to use the parameters that
    # are provided to them
    class TemplateRenderingContext < BasicObject
        def initialize(**parameters)
            @parameters = parameters
            @used_parameters = ::Set.new
        end

        def __verify
            unused_parameters = @parameters.keys.to_set -
                @used_parameters
            if !unused_parameters.empty?
                ::Kernel.raise ::Autoproj::Jenkins::UnusedTemplateParameters, "#{unused_parameters.size} unused parameters: #{unused_parameters.map(&:to_s).sort.join(", ")}"
            end
        end


        def method_missing(m)
            if @parameters.has_key?(m)
                result = @parameters.fetch(m)
                @used_parameters << m
                result
            else
                ::Kernel.raise ::Autoproj::Jenkins::UnknownTemplateParameter, "#{m} is not a known template parameter"
            end
        end
    end

    # The path to autoproj-jenkins templates
    def self.template_path
        Pathname.new(__dir__) + "templates"
    end

    # Create a template rendering context for the given parameters
    #
    # @param [String] template_name the name of the template to be rendered,
    #   without the .erb extension
    # @param [Hash<Symbol,Object>] parameters the template parameters
    # @param [Pathname] template_path where the templates are located on disk
    # @return [String]
    def self.render_template(template_name, template_path: self.template_path, **parameters)
        context = TemplateRenderingContext.new(**parameters)
        template_path = template_path + "#{template_name}.erb"
        template = ERB.new(template_path.read)
        template.filename = template_path.to_s
        template.lineno = 0
        b = context.instance_eval { Kernel.binding }
        result = template.result(b)
        context.__verify
        result
    end
end
