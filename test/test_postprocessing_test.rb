require 'test_helper'
require 'autoproj/cli/test_postprocessing'

module Autoproj
    module CLI
        describe TestPostprocessing do
            attr_reader :ops
            before do
                ws_create
                @ops = TestPostprocessing.new(ws)
                # Override #initialize_and_load, it would override the fixture
                # setup
                flexmock(ops).should_receive(:initialize_and_load)
            end

            describe "#process" do
                attr_reader :package, :test_results_dir
                before do
                    @package = ws_define_package :cmake, 'base/cmake'
                    ws_define_package_vcs package, 'type' => 'none'
                    @test_results_dir = make_tmpdir
                    package.autobuild.test_utility.target_dir = test_results_dir
                end

                it "processes files using xsl" do
                    FileUtils.mkdir_p test_results_dir
                    FileUtils.touch File.join(test_results_dir, 'test.boost.xml')
                    output_dir = make_tmpdir
                    flexmock(ops).should_receive(:initialize_and_load)
                    flexmock(ops).should_receive(:xsl_process).
                        with(File.join(test_results_dir, 'test.boost.xml'),
                             File.join(TestPostprocessing.test_format_converter_dir, 'boost-test.xsl'),
                             File.join(output_dir, 'test.boost.xml')).
                        once
                    ops.process(output_dir, 'base/cmake')
                end
                it "ignores packages that do not have a test/ directory" do
                    output_dir = make_tmpdir
                    ops.process(output_dir, 'base/cmake')
                end
                it "copies files if the converter is nil" do
                    FileUtils.mkdir_p test_results_dir
                    FileUtils.touch File.join(test_results_dir, 'test.junit.xml')
                    output_dir = make_tmpdir
                    flexmock(ops).should_receive(:xsl_process).never
                    flexmock(FileUtils).should_receive(:copy_file).
                        with(File.join(test_results_dir, 'test.junit.xml'),
                             File.join(output_dir, 'test.junit.xml')).
                        once
                    ops.process(output_dir, 'base/cmake')
                end
            end
        end
    end
end

