module CASServer
  module ServiceCheck
    class Base
      def self.setup(config)
      end

      def validate(service)
        true
      end
    end
  end
end
