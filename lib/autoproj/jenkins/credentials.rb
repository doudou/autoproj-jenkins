module Autoproj::Jenkins
    # Management of the mapping from a VCS description to the corresponding
    # Jenkins credential
    class Credentials
        Credential = Struct.new :vcs, :protocol, :host do
            # Whether this credential object matches the given VCS
            #
            # @param [Autoproj::VCSDefinition] vcs
            def matches?(vcs)
                return if vcs.type.to_sym != self.vcs
                vcs_url = URI.parse(vcs.url)
                vcs_url.scheme == protocol &&
                    vcs_url.host == host
            end

            # The ID of the jenkins credential
            def jenkins_id
                "autoproj-#{vcs}-#{protocol}-#{host}"
            end
        end

        # Parse a string that represents a single credential and return it
        #
        # @param [String] string a string of the form "vcs_type:URI", e.g.
        #   "git:https://github.com"
        # @return [Credential]
        def self.parse(string)
            vcs, *uri = string.split(':')
            uri = URI.parse(uri.join(':'))
            Credential.new(vcs.to_sym, uri.scheme, uri.host)
        end

        attr_reader :credentials

        def initialize
            @credentials = Hash.new
        end

        def [](vcs)
            credentials[vcs.to_sym] || Array.new
        end

        def add(credential)
            (credentials[credential.vcs] ||= Array.new) << credential
        end

        # Return the credential description for the given VCS
        #
        # @param [Autoproj::VCSDefinition] vcs
        # @return [nil,Credential]
        def for(vcs)
            self[vcs.type].find do |c|
                c.matches?(vcs)
            end
        end
    end
end

