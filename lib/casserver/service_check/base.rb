module CASServer
  module ServiceCheck
    class Base
      def self.setup(config)
      end

      def validate(service)
        true
      end

      def modify_response(service, extra_attributes)
        extra_attributes
      end

    end
  end
end
