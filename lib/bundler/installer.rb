require 'rubygems/dependency_installer'

module Bundler
  class Installer < Environment
    def self.install(root, definition, options)
      installer = new(root, definition)
      installer.run(options)
      installer
    end

    def run(options)
      if resolved_dependencies.empty?
        Bundler.ui.warn "The Gemfile specifies no dependencies"
        return
      end

      # Ensure that BUNDLE_PATH exists
      FileUtils.mkdir_p(Bundler.bundle_path)

      # Must install gems in the order that the resolver provides
      # as dependencies might actually affect the installation of
      # the gem.
      specs.each do |spec|
        spec.source.fetch(spec) if spec.source.respond_to?(:fetch)

        unless requested_specs.include?(spec)
          Bundler.ui.debug "  * Not in requested group; skipping."
          next
        end

        if [Source::Rubygems].include?(spec.source.class)
          Bundler.ui.info "Installing #{spec.name} (#{spec.version}) from #{spec.source}"
        else
          Bundler.ui.info "Using #{spec.name} (#{spec.version}) from #{spec.source}"
        end
        spec.source.install(spec)
      end

      lock
    end

  private

    def resolve_locally
      # Return unless all the dependencies have = version requirements
      return if resolved_dependencies.any? { |d| ambiguous?(d) }

      specs = super

      # Simple logic for now. Can improve later.
      specs.length == resolved_dependencies.length && specs
    rescue GemNotFound, PathError => e
      nil
    end

    def resolve_remotely
      resolve(:specs, remote_index)
    end

    def ambiguous?(dep)
      dep.requirement.requirements.any? { |op,_| op != '=' }
    end

    def remote_index
      @remote_index ||= Index.build do |idx|
        sources.each { |source| idx.use source.specs }
      end
    end
  end
end
