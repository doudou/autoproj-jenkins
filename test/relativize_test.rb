require 'test_helper'

module Autoproj::Jenkins
    describe Relativize do
        it "ignores files that do not match its patterns" do
            dir = Pathname.new(make_tmpdir)
            (dir + "pkgconfig").mkpath
            file = (dir + "pkgconfig" + "test.not_matching")
            file.open('w') { |io| io.puts "@SOURCE_TEST@" }
            result = Relativize.new(dir, "@SOURCE_TEST@", "foobar").process
            assert_equal [], result
            assert_equal "@SOURCE_TEST@\n", file.read
        end
        it "does not return matching files that do not have the expected pattern" do
            dir = Pathname.new(make_tmpdir)
            (dir + "pkgconfig").mkpath
            pc_file = (dir + "pkgconfig" + "test.pc")
            pc_file.open('w') do |io|
                io.puts "text"
                io.puts "also text"
            end
            result = Relativize.new(dir, "@SOURCE_TEST@", "foobar").process
            assert_equal [], result
            assert_equal "text\nalso text\n", pc_file.read
        end
        it "replaces the source text by the target text in paths matching its patterns" do
            dir = Pathname.new(make_tmpdir)
            (dir + "pkgconfig").mkpath
            pc_file = (dir + "pkgconfig" + "test.pc")
            pc_file.open('w') do |io|
                io.puts "text"
                io.puts "@SOURCE_TEST@"
                io.puts "also text"
            end
            result = Relativize.new(dir, "@SOURCE_TEST@", "foobar").process
            assert_equal [pc_file], result
            assert_equal "text\nfoobar\nalso text\n", pc_file.read
        end
    end
end

