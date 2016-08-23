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

            class ConvertionFailed < RuntimeError; end

            def process(output_dir, *package_names, after: nil)
                initialize_and_load
                source_packages, _ = finalize_setup(
                    package_names, 
                    recursive: false,
                    ignore_non_imported_packages: true)
                source_packages = source_packages.map do |package_name|
                    ws.manifest.package_definition_by_name(package_name)
                end

                has_failures = false
                source_packages.each do |pkg|
                    utility = pkg.autobuild.test_utility
                    found_something = false
                    convertions.each do |glob, xsl|
                        Dir.glob(File.join(utility.target_dir, glob)) do |input_file|
                            input_mtime = File.stat(input_file).mtime
                            if after && input_mtime < after
                                Autoproj.message "  ignoring #{input_file}, its modification time is #{input_mtime} which is after #{after}"
                                next
                            end

                            found_something = true
                            FileUtils.mkdir_p output_dir
                            output_file = File.join(output_dir, File.basename(input_file))
                            begin
                                if xsl
                                    xsl_process(input_file, xsl, output_file)
                                else
                                    FileUtils.copy_file input_file, output_file
                                end
                                Autoproj.message "  generated #{output_file} from #{input_file} for #{pkg.name}"
                            rescue Exception => e
                                Autoproj.error e.message
                                has_failures = true
                            end
                        end
                    end

                    if !found_something
                        Autoproj.message "found no test results for #{pkg.name}"
                    end
                end
            ensure
                if has_failures
                    raise ConvertionFailed, "some files failed to convert, see output for more details"
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


