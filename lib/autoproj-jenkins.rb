require 'autoproj/cli/main_jenkins'

class Autoproj::CLI::Main
    desc 'jenkins', 'jenkins-specific functionality'
    subcommand 'jenkins', Autoproj::CLI::MainJenkins
end


