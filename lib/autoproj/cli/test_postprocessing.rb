require 'autoproj/cli/inspection_tool'

module Autoproj
    module CLI
        class TestPostprocessing < Autoproj::CLI::InspectionTool
            attr_reader :convertions

            def self.test_format_converter_dir
                File.expand_path(
                    File.join('..', 'jenkins', 'test_format_converters'),
                    __dir__)
            end

            TEST_RESULT_CONVERTERS = Hash[
                '*.boost.xml' => File.join(test_format_converter_dir, 'boost-test.xsl'),
                '*.junit.xml' => nil
            ]

            def initialize(ws, convertions: TEST_RESULT_CONVERTERS)
                super(ws)
                @convertions = convertions
            end


            def process(output_dir, *package_names)
                initialize_and_load
                source_packages, _ = finalize_setup(
                    package_names, 
                    ignore_non_imported_packages: true)
                source_packages = source_packages.map do |package_name|
                    ws.manifest.package_definition_by_name(package_name)
                end

                source_packages.each do |pkg|
                    utility = pkg.autobuild.test_utility
                    convertions.each do |glob, xsl|
                        Dir.glob(File.join(utility.target_dir, glob)) do |input_file|
                            FileUtils.mkdir_p output_dir
                            output_file = File.join(output_dir, File.basename(input_file))
                            if xsl
                                xsl_process(input_file, xsl, output_file)
                            else
                                FileUtils.copy_file input_file, output_file
                            end
                            puts "generated #{output_file} from #{input_file} for #{pkg.name}"
                        end
                    end
                end
            end

            def xsl_process(input_file, stylesheet, output_file)
                if File.read(input_file).strip.empty?
                    return
                end

                if !system('saxonb-xslt', "-o:#{output_file}", "-xsl:#{stylesheet}", "-s:#{input_file}")
                    raise ArgumentError, "failed to convert #{input_file} using #{stylesheet}"
                end
            end
        end
    end
end


