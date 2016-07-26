module Autoproj::Jenkins
    # Exception raised when trying to handle a package whose VCS we don't
    # integrate
    class UnhandledVCS < RuntimeError
    end
end

