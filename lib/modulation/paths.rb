# frozen_string_literal: true

module Modulation
  # Implements methods for expanding relative or incomplete module file names
  module Paths
    class << self
      # Regexp for extracting filename from caller reference
      CALLER_FILE_REGEXP = /^([^\:]+)\:/

      # Resolves the absolute path to the provided reference. If the file is not
      # found, will try to resolve to a gem
      # @param path [String] unqualified file name
      # @param caller_location [String] caller location
      # @return [String] absolute file name
      def absolute_path(path, caller_location)
        caller_file = caller_location[CALLER_FILE_REGEXP, 1]
        return nil unless caller_file

        path = File.expand_path(path, File.dirname(caller_file))
        check_path(path)
      end

      # Computes and verifies the absolute directory path
      # @param path String] unqualified path
      # @param caller_location [String] caller location
      # @return [String] absolute directory path
      def absolute_dir_path(path, caller_location)
        caller_file = caller_location[CALLER_FILE_REGEXP, 1]
        return nil unless caller_file

        path = File.expand_path(path, File.dirname(caller_file))
        File.directory?(path) ? path : (raise "Invalid directory #{path}")
      end

      # Checks that the given path references an existing file, adding the .rb
      # extension if needed
      # @param path [String] absolute file path (with/without .rb extension)
      # @return [String, nil] path of file or nil if not found
      def check_path(path)
        if File.file?("#{path}.rb")
          path + '.rb'
        elsif File.file?(path)
          path
        end
      end

      GEM_NAME_RE = /^([^\/]+)/

      # Resolves the provided path by looking for a corresponding gem. If no gem
      # is found, returns nil. If the corresponding gem does not use modulation,
      # returns :require_gem, which signals that the gem must be required.
      # @param name [String] gem name
      # @return [String, Symbol] absolute path or :require_gem
      def lookup_gem_path(name)
        gem = name[GEM_NAME_RE, 1] || name
        spec = Gem::Specification.find_by_name(gem)

        if gem_uses_modulation?(spec)
          find_gem_based_path(spec, name)
        else
          :require_gem
        end
      rescue Gem::MissingSpecError
        nil
      end

      # Returns true if given gemspec depends on modulation, which means it can
      # be loaded using `import`
      # @param gemspec [Gem::Specification] gem spec
      # @return [Boolean] does gem depend on modulation?
      def gem_uses_modulation?(gemspec)
        gemspec.dependencies.map(&:name).include?('modulation')
      end

      # Finds full path for gem file based on gem's require paths
      # @param gemspec [Gem::Specification] gem spec
      # @param path [String] given import path
      # @return [String] full path
      def find_gem_based_path(gemspec, path)
        gemspec.full_require_paths.each do |p|
          full_path = check_path(File.join(p, path))
          return full_path if full_path
        end
        nil
      end
    end
  end
end
