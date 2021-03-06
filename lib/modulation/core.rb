# frozen_string_literal: true

# Implements main Modulation functionality
module Modulation
  require_relative './paths'
  require_relative './builder'
  require_relative './module_mixin'

  class << self
    # @return [Hash] hash of loaded modules, mapping absolute paths to modules
    attr_reader :loaded_modules

    # Resets the loaded modules hash
    def reset!
      @loaded_modules = {}
    end

    # Show full backtrace for errors occuring while loading a module. Normally
    # Modulation will remove stack frames occurring inside the modulation.rb
    # code in order to make backtraces more readable when debugging.
    def full_backtrace!
      @full_backtrace = true
    end

    GEM_REQUIRE_ERROR_MESSAGE = <<~MSG
      Can't import from a gem that doesn't depend on Modulation. Please use `require` instead of `import`.
    MSG

    # Imports a module from a file
    # If the module is already loaded, returns the loaded module.
    # @param path [String] unqualified file name
    # @param caller_location [String] caller location
    # @return [Module] loaded module object
    def import(path, caller_location = caller(1..1).first)
      abs_path = Paths.absolute_path(path, caller_location) ||
                 Paths.lookup_gem_path(path)

      case abs_path
      when String
        @loaded_modules[abs_path] || create_module_from_file(abs_path)
      when :require_gem
        raise_error(LoadError.new(GEM_REQUIRE_ERROR_MESSAGE), caller)
      else
        raise_error(LoadError.new("Module not found: #{path}"), caller)
      end
    end

    # Imports all source files in given directory
    # @ param path [String] relative directory path
    # @param caller_location [String] caller location
    # @return [Array] array of module objects
    def import_all(path, caller_location = caller(1..1).first)
      abs_path = Paths.absolute_dir_path(path, caller_location)
      Dir["#{abs_path}/**/*.rb"].map do |fn|
        @loaded_modules[fn] || create_module_from_file(fn)
      end
    end

    # Creates a new module from a source file
    # @param path [String] source file name
    # @return [Module] module
    def create_module_from_file(path)
      Builder.make(location: path)
    rescue StandardError => e
      raise_error(e)
    end

    # (Re-)raises an error, potentially filtering its backtrace to remove stack
    # frames occuring in Modulation code
    # @param error [Error] raised error
    # @param caller [Array] error backtrace
    # @return [void]
    def raise_error(error, caller = error.backtrace)
      if @full_backtrace
        error.set_backtrace(caller)
      else
        error.set_backtrace(caller.reject { |l| l =~ /^#{Modulation::DIR}/ })
      end
      raise error
    end

    # Reloads the given module from its source file
    # @param mod [Module, String] module to reload
    # @return [Module] module
    def reload(mod)
      if mod.is_a?(String)
        path = mod
        mod = @loaded_modules[File.expand_path(mod)]
        raise "No module loaded from #{path}" unless mod
      end

      Builder.cleanup_module(mod)
      Builder.reload_module_code(mod)

      mod.tap { Builder.set_exported_symbols(mod, mod.__exported_symbols) }
    end

    # Maps the given path to the given mock module, restoring the previously
    # loaded module (if any) after calling the given block
    # @param path [String] module path
    # @param mod [Module] module
    # @param caller_location [String] caller location
    # @return [void]
    def mock(path, mod, caller_location = caller(1..1).first)
      path = Paths.absolute_path(path, caller_location)
      old_module = @loaded_modules[path]
      @loaded_modules[path] = mod
      yield if block_given?
    ensure
      @loaded_modules[path] = old_module if block_given?
    end
  end
end

Modulation.reset!
