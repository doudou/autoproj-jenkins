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
                attr_reader :base_cmake, :results_dir
                before do
                    @base_cmake = ws_define_package :cmake, 'base/cmake'
                    ws_define_package_vcs base_cmake, 'type' => 'none'
                    @results_dir = make_tmpdir
                    base_cmake.autobuild.test_utility.target_dir = results_dir
                end

                it "processes files using xsl" do
                    FileUtils.mkdir_p results_dir
                    FileUtils.touch File.join(results_dir, 'test.boost.xml')
                    output_dir = make_tmpdir
                    flexmock(ops).should_receive(:initialize_and_load)
                    flexmock(ops).should_receive(:xsl_process).
                        with(File.join(results_dir, 'test.boost.xml'),
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
                    FileUtils.mkdir_p results_dir
                    FileUtils.touch File.join(results_dir, 'test.junit.xml')
                    output_dir = make_tmpdir
                    flexmock(ops).should_receive(:xsl_process).never
                    flexmock(FileUtils).should_receive(:copy_file).
                        with(File.join(results_dir, 'test.junit.xml'),
                             File.join(output_dir, 'test.junit.xml')).
                        once
                    ops.process(output_dir, 'base/cmake')
                end

                describe "error handling" do
                    before do
                        flexmock(ops).should_receive(:initialize_and_load)
                        flexmock(ops).should_receive(:finalize_setup).and_return([['base/cmake']]).by_default
                        flexmock(Dir).should_receive(:glob).by_default
                    end

                    def setup_files(*files)
                        FileUtils.mkdir_p results_dir
                        files = files.map do |path|
                            path = File.expand_path(path, results_dir)
                            FileUtils.touch path
                            path
                        end
                        files
                    end

                    it "attempts to process all the files of a package, regardless of errors" do
                        files = setup_files '00.boost.xml', '11.boost.xml'
                        flexmock(Dir).should_receive(:glob).with("#{results_dir}/*.boost.xml", Proc).
                            and_iterates(*files)
                        flexmock(ops).should_receive(:xsl_process).
                            with(files[0], any, any).once.globally.ordered.and_raise("mock failure of xsl_process")
                        flexmock(ops).should_receive(:xsl_process).
                            with(files[1], any, any).once.globally.ordered
                        out, err = capture_subprocess_io do
                            assert_raises(TestPostprocessing::ConvertionFailed) do
                                ops.process(make_tmpdir, 'base/cmake')
                            end
                        end
                        assert_match /ERROR: mock failure of xsl_process/, err
                        refute_match /generated .*from #{files[0]}/, err
                        assert_match /generated .*from #{files[1]}/, out
                    end

                    it "attempts to process all patterns in a package, regardless of errors" do
                        file0, file1 = setup_files '00.boost.xml', '11.junit.xml'
                        flexmock(Dir).should_receive(:glob).with("#{results_dir}/*.boost.xml", Proc).
                            and_iterates(file0)
                        flexmock(Dir).should_receive(:glob).with("#{results_dir}/*.junit.xml", Proc).
                            and_iterates(file1)

                        flexmock(ops).should_receive(:xsl_process).
                            with(file0, any, any).once.globally.ordered.and_raise("mock failure of xsl_process")
                        flexmock(FileUtils).should_receive(:copy_file).
                            with(file1, any).once.globally.ordered
                        out, err = capture_subprocess_io do
                            assert_raises(TestPostprocessing::ConvertionFailed) do
                                ops.process(make_tmpdir, 'base/cmake')
                            end
                        end
                        assert_match /ERROR: mock failure of xsl_process/, err
                        refute_match /generated .*from #{file0}/, err
                        assert_match /generated .*from #{file1}/, out
                    end

                    it "attempts to process all packages, regardless of errors" do
                        base_types = ws_define_package :cmake, 'base/types'
                        base_types.autobuild.test_utility.target_dir = make_tmpdir
                        flexmock(ops).should_receive(:finalize_setup).and_return([['base/cmake', 'base/types']])
                        file0, file1 = setup_files '00.boost.xml', '11.junit.xml'
                        flexmock(Dir).should_receive(:glob).with("#{base_cmake.autobuild.test_utility.target_dir}/*.boost.xml", Proc).
                            and_iterates(file0)
                        flexmock(Dir).should_receive(:glob).with("#{base_cmake.autobuild.test_utility.target_dir}/*.junit.xml", Proc)
                        flexmock(Dir).should_receive(:glob).with("#{base_types.autobuild.test_utility.target_dir}/*.boost.xml", Proc)
                        flexmock(Dir).should_receive(:glob).with("#{base_types.autobuild.test_utility.target_dir}/*.junit.xml", Proc).
                            and_iterates(file1)

                        flexmock(ops).should_receive(:xsl_process).
                            with(file0, any, any).once.globally.ordered.and_raise("mock failure of xsl_process")
                        flexmock(FileUtils).should_receive(:copy_file).
                            with(file1, any).once.globally.ordered
                        out, err = capture_subprocess_io do
                            assert_raises(TestPostprocessing::ConvertionFailed) do
                                ops.process(make_tmpdir, 'base/cmake')
                            end
                        end
                        assert_match /ERROR: mock failure of xsl_process/, err
                        refute_match /generated .*from #{file0}/, err
                        assert_match /generated .*from #{file1}/, out
                    end
                end
            end
        end
    end
end

