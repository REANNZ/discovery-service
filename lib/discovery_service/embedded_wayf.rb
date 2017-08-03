module DiscoveryService
  # Implements a solution compatible with the AAF Embedded WAYF provided by the
  # old Discovery Service. This is a stopgap solution to prevent service
  # disruption and allow us to gracefully deprecate the embedded WAYF.
  module EmbeddedWAYF
    def embedded_wayf_javascript
      "#{embedded_wayf_disclaimer}\n" \
        '(function() {' \
        "#{embedded_wayf_preamble}" \
        "#{EMBEDDED_WAYF_LOGIC}" \
        '})();'
    end

    private

    def idp_entities
      @entity_cache.entities_as_hash('aaf')
                   .select { |_, v| v[:tags].include?('idp') }
    end

    def embedded_wayf_preamble
      entities = idp_entities.map do |(k, v)|
        names = v[:names].select { |n| n[:lang] == 'en' }
        name = names.first[:value] if names.any?
        { entity_id: k, name: name || k }
      end

      "var idp_entities = #{JSON.generate(entities)};"
    end

    # rubocop:disable Layout/IndentHeredoc
    def embedded_wayf_disclaimer
      <<-EOF
/* The AAF Embedded WAYF is deprecated and will be removed during 2016. New
 * services should refer to the AAF website for information about connecting to
 * the federation.
 *
 * https://aaf.edu.au
 */
      EOF
    end
    # rubocop:enable Layout/IndentHeredoc

    EMBEDDED_WAYF_LOGIC =
      File.read(File.expand_path('../embedded-wayf.js', __FILE__))
    private_constant :EMBEDDED_WAYF_LOGIC
  end
end
