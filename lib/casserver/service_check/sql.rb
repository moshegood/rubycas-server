begin
  require 'active_record'
rescue LoadError
  require 'rubygems'
  require 'active_record'
end

module CASServer
  module ServiceCheck
    class SQL < CASServer::ServiceCheck::Base
      attr_accessor :model
      attr_accessor :config

      def initialize(cfg)
        self.config = cfg

        if config[:service_model]
          self.model = config[:service_model].constantize
        else
          self.model = Class.new(ActiveRecord::Base)
          table = self.config[:service_table] || 'services'
          if ActiveRecord::VERSION::STRING >= '3.2'
            self.model.table_name = table
          else
            self.model.set_table_name(table)
          end
        end
        self.model.establish_connection(config[:database])

        begin
          self.model.connection
        rescue => e
          $LOG.debug e
          raise "SQL ServiceCheck can not connect to database"
        end
      end

      def find_services(service)
        return [] if service.size == 0
        uri = URI(service)
        base_path = "#{uri.scheme}://#{uri.host}"
        if uri.host == 'localhost'
          base_path += ":#{uri.port}"
        end

        service_url_column = self.config[:service_url_column] || "service_url"
        services = self.model.find(
          :all,
          :conditions => [
            "#{service_url_column} = ? OR #{service_url_column} = ?",
            base_path, base_path + "/"
          ]
        )
      end

      def validate(service)
        return true if service.size == 0
        services = find_services(service)
        if services.size == 0
          $LOG.warn("Service #{service} not found")
        end
        services.size > 0
      end

      def modify_response(service_string, extra_attributes)
        $LOG.info("About to modify extra_attributes for #{service_string}")
        service = find_services(service_string).first

        $LOG.debug("Extra attributes were: #{extra_attributes.inspect}")

        # do stuff here
        # Maybe you want: return {} unless service
        # Maybe you want some other stuff as well

        $LOG.debug("Extra attributes are: #{extra_attributes.inspect}")
        extra_attributes
      end
    end
  end
end
