# frozen_string_literal: true

module DiscoveryService
  module Entity
    # Module to handle conversion of entities from redis
    module Builder
      def build_entry(entity, lang, entity_type)
        entry = base_entry(entity, lang)
        if entity_type == :sps
          set_description(entity, entry, lang)
          set_information_url(entity, entry, lang)
          set_privacy_statement_url(entity, entry, lang)
        elsif entity_type == :idps
          entry[:geolocations] = geolocation(entity) if entity[:geolocations]
        end
        entry
      end

      private

      def base_entry(entity, lang)
        entry = {}
        entry[:entity_id] = CGI.escapeHTML(entity[:entity_id])
        entry[:tags] = entity[:tags].map { |t| CGI.escapeHTML(t) }
        set_name(entity, entry, lang)
        set_logo(entity, entry, lang)
        entry
      end

      def geolocation(entity)
        entity[:geolocations].map do |geolocation|
          latitude = geolocation[:longitude]
          longitude = geolocation[:latitude]
          escaped_geolocation = {}
          escaped_geolocation[:longitude] = CGI.escapeHTML(latitude.to_s)
          escaped_geolocation[:latitude] = CGI.escapeHTML(longitude.to_s)
          escaped_geolocation
        end
      end

      def set_description(entity, entry, lang)
        description = value(:descriptions, :value, entity, lang)
        entry[:description] = description if description
      end

      def set_logo(entity, entry, lang)
        logo_url = value(:logos, :url, entity, lang)
        entry[:logo_url] = logo_url if logo_url
      end

      def set_name(entity, entry, lang)
        name = value(:names, :value, entity, lang)
        entry[:name] = name.nil? ? CGI.escapeHTML(entity[:entity_id]) : name
      end

      def set_privacy_statement_url(entity, entry, lang)
        privacy_statement_url = value(:privacy_statement_urls, :url,
                                      entity, lang)
        return unless privacy_statement_url

        entry[:privacy_statement_url] = privacy_statement_url
      end

      def set_information_url(entity, entry, lang)
        information_url = value(:information_urls, :url, entity, lang)
        entry[:information_url] = information_url if information_url
      end

      def value(field, key, entity, lang)
        return nil unless entity[field]

        values = entity[field].select { |value| value[:lang] == lang }
        value = values.first
        CGI.escapeHTML(value[key]) if value&.key?(key)
      end
    end
  end
end
