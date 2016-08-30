require 'test_helper'

module Autoproj::Jenkins
    describe Credentials do
        describe ".parse" do
            it "raises ArgumentError if the string does not match VCS_TYPE:URL" do
                assert_raises(ArgumentError) { Credentials.parse('test') }
                assert_raises(ArgumentError) { Credentials.parse(':test') }
                assert_raises(ArgumentError) { Credentials.parse('test:') }
            end
            it "raises UnhandledVCS if the string refers to an unknown vcs" do
                assert_raises(UnhandledVCS) do
                    Credentials.parse('unknown:test')
                end
            end
            it "returns the parsed credentials ID" do
                c = Credentials.parse('git:https://github.com')
                assert_equal :git, c.vcs
                assert_equal 'https', c.protocol
                assert_equal 'github.com', c.host
            end
        end
    end
end
