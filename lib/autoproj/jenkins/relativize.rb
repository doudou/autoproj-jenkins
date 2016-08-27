module Autoproj
    module Jenkins
        # Process files that might contain full paths and transform them by
        # replacing the original path with a new one
        class Relativize
            FILE_PATTERN = Regexp.union(
                /\/pkgconfig\/.*.pc$/,
                /\.cmake$/,
                /\.txt$/
            )

            # The path of the root to be filtered
            #
            # @return [Pathname]
            attr_reader :root_path

            # The text to be replaced
            #
            # @return [String]
            attr_reader :original_text

            # The text replacing {#original_text}
            #
            # @return [String]
            attr_reader :replacement_text

            # A pattern used to filter which files should be filtered
            #
            # @return [#===]
            attr_reader :file_pattern

            def initialize(root_path, original_text, replacement_text, file_pattern: FILE_PATTERN)
                @root_path        = root_path
                @original_text    = original_text
                @replacement_text = replacement_text
                @file_pattern = file_pattern
            end

            # Process all files matching {#file_pattern} within {#root_path}
            #
            # @return [Array<Pathname>] the files that have been processed
            def process
                processed_files = Array.new
                root_path.find do |candidate|
                    if candidate.file? && (file_pattern === candidate.to_s)
                        if process_file(candidate)
                            processed_files << candidate
                        end
                    end
                end
                processed_files
            end

            # @api private
            #
            # Replaces text in a given file
            #
            # @return [Boolean] true if the pattern was found
            def process_file(path)
                replaced = false
                filtered = path.each_line.map do |line|
                    line.gsub(original_text) { replaced = true; replacement_text }
                end
                if replaced
                    path.open('w') do |io|
                        io.puts filtered.join
                    end
                    true
                end
            end
        end
    end
end

