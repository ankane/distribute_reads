module Makara
  module Strategies
    class NameSelect < ::Makara::Strategies::RoundRobin
      attr_accessor :current_name

      def current
        return super unless current_name.present?

        con = @weighted_connections.detect do |weighted_connection|
          weighted_connection.config[:name] == current_name
        end
        return nil unless con
        return nil if con._makara_blacklisted?
        con
      end
    end
  end
end
