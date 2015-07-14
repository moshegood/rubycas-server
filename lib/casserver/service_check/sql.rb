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

        self.model = Class.new(ActiveRecord::Base)
        self.model.establish_connection(config[:database])
        table = self.config[:service_table] || 'services'
        if ActiveRecord::VERSION::STRING >= '3.2'
          self.model.table_name = table
        else
          self.model.set_table_name(table)
        end
        begin
          self.model.connection
        rescue => e
          $LOG.debug e
          raise "SQL ServiceCheck can not connect to database"
        end
      end

      def validate(service)
        return true if service.size == 0
        uri = URI(service)
        base_path = "#{uri.scheme}://#{uri.host}"
        if uri.host == 'localhost'
          base_path += ":#{uri.port}"
        end

        service_url_column = self.config[:service_url_column] || "service_url"
        services = self.model.find(
          :all,
          :conditions => ["#{service_url_column} = ?", base_path]
        )
        if services.size == 0
          $LOG.warn("Service #{service} not found")
        end
        services.size > 0
      end
    end
  end
end
