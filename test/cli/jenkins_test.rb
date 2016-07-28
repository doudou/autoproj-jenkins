require 'test_helper'
require 'autoproj/cli/jenkins'

module Autoproj
    module CLI
        describe Jenkins do
            attr_reader :base_cmake, :base_logging, :base_types, :gui_vizkit3d
            before do
                autoproj_create_workspace
                @base_cmake   = autoproj_create_package(:cmake, 'base/cmake')
                @gui_vizkit3d = autoproj_create_package(:cmake, 'gui/vizkit3d')
                @base_logging = autoproj_create_package(:cmake, 'base/logging')
                @base_types   = autoproj_create_package(:cmake, 'base/types')

                base_logging.autobuild.depends_on 'base/cmake'
                base_types.autobuild.depends_on 'base/logging'
                base_types.autobuild.depends_on 'gui/vizkit3d'
                base_types.autobuild.depends_on 'base/cmake'
            end

            describe "#trigger_root_packages" do
                attr_reader :ops

                before do
                    @ops = Jenkins.new(ws, **jenkins_connect_options)
                end

                it "returns the roots of the trigger graph" do
                    assert_equal %w{base/cmake gui/vizkit3d},
                        ops.trigger_root_packages(*%w{base/cmake base/logging gui/vizkit3d base/types})
                end
                it "raises if a package does not exist" do
                    assert_raises(ArgumentError) do
                        ops.trigger_root_packages(*%w{does_not_exist})
                    end
                end
            end
        end
    end
end

